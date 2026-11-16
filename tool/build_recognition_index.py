"""Build and evaluate the bundled image similarity index.

Requires ai-edge-litert, NumPy and Pillow on the build computer.
"""

import argparse
import csv
import hashlib
import io
import json
import re
from collections import defaultdict
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from PIL import Image, ImageOps


class Embedder:
    def __init__(self, model):
        self.model = Interpreter(model_path=str(model), num_threads=2)
        self.model.allocate_tensors()
        self.input = self.model.get_input_details()[0]["index"]
        self.output = self.model.get_output_details()[0]["index"]

    def __call__(self, source, zoom=False):
        with Image.open(source) as original:
            image = ImageOps.exif_transpose(original).convert("RGB")
            if zoom:
                x, y = image.width // 10, image.height // 10
                image = image.crop((x, y, image.width - x, image.height - y))
            pixels = np.asarray(image.resize((224, 224), Image.Resampling.BILINEAR),
                                dtype=np.float32) / 255
        self.model.set_tensor(self.input, pixels[None])
        self.model.invoke()
        embedding = self.model.get_tensor(self.output)[0]
        return embedding / np.linalg.norm(embedding)


def read_manifest(path):
    with path.open(encoding="utf-8-sig", newline="") as source:
        return list(csv.DictReader(source))


def capture_group(row):
    return re.sub(r"\.rf\.[a-f0-9]+\.(jpe?g|png)$", "",
                  Path(row["publisher_image"]).name, flags=re.IGNORECASE)


def references_and_probes(dataset, archive):
    by_subject = defaultdict(list)
    held_out = {"valid": [], "test": []}
    captures = defaultdict(list)
    for row in read_manifest(dataset / "roboflow.csv"):
        captures[capture_group(row)].append(row)
    for capture, rows in sorted(captures.items()):
        splits = {row["publisher_split"] for row in rows}
        if len(splits) != 1:
            raise ValueError(f"Roboflow source occurs in multiple splits: {capture}")
        split = splits.pop()
        largest = max(rows, key=lambda row: int(row["width"]) * int(row["height"]))
        if split == "train":
            by_subject[largest["subject_id"]].append(largest)
        elif split in held_out:
            held_out[split].append((
                largest["subject_id"], "food", archive.read(largest["publisher_image"])
            ))
    # Balance the number of references while choosing distinct source captures.
    refs = []
    for rows in by_subject.values():
        rows.sort(key=lambda row: hashlib.sha256(capture_group(row).encode()).digest())
        refs.extend(rows[:48])

    commons = defaultdict(list)
    for row in read_manifest(dataset / "commons-reviewed.csv"):
        commons[row["subject_id"]].append(row)
    for rows in commons.values():
        if rows[0]["kind"] == "landmark" and len(rows) >= 3:
            counts = {row["creator"]: sum(r["creator"] == row["creator"] for r in rows)
                      for row in rows}
            row = next((row for row in rows if counts[row["creator"]] == 1), None)
            if row:
                held_out["test"].append((row["subject_id"], "landmark",
                                         (dataset / row["file"]).read_bytes()))
                rows = [item for item in rows if item["file"] != row["file"]]
        # Food duplicates may occur across publishers. Keep Commons food
        # outside this benchmark and index until a perceptual audit is done.
        refs.extend(row for row in rows if row["kind"] == "landmark")
    return sorted(refs, key=lambda row: (row["subject_id"], row["file"])), held_out


def rank_probes(probes, embedder, matrix, groups):
    results = []
    for subject, kind, image in probes:
        variants = np.stack([embedder(io.BytesIO(image)),
                             embedder(io.BytesIO(image), zoom=True)])
        scores = matrix @ variants.T
        ranked = {}
        for name, indexes in groups.items():
            best = np.sort(scores[indexes], axis=0)[-3:]
            ranked[name] = float(np.max(0.7 * best[-1] + 0.3 * np.mean(best, axis=0)))
        results.append((subject, kind, sorted(ranked, key=ranked.get, reverse=True), ranked))
    return results


def summarize(results, excluded=False):
    outcomes = defaultdict(lambda: {
        "correct": 0, "wrong": 0, "choices_with_subject": 0,
        "choices_without_subject": 0, "no_match": 0,
    })
    for correct, kind, order, scores in results:
        rank = [name for name in order if not excluded or name != correct]
        first, second = rank[:2]
        if scores[first] >= 0.70 and scores[first] - scores[second] >= 0.04:
            result = "correct" if first == correct else "wrong"
        elif scores[first] >= 0.58:
            choices = [item for item in rank[:3]
                       if scores[item] >= 0.50 and scores[first] - scores[item] <= 0.10]
            result = "choices_with_subject" if correct in choices else "choices_without_subject"
        else:
            result = "no_match"
        outcomes[kind][result] += 1
    return dict(outcomes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path(".recognition-dataset"))
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    embedder = Embedder(args.model)
    with ZipFile(args.dataset / "roboflow-v7-coco.zip") as archive:
        refs, held_out = references_and_probes(args.dataset, archive)
    matrix = np.stack([embedder(args.dataset / row["file"]) for row in refs])
    quantized = np.rint(matrix / np.max(np.abs(matrix), axis=1, keepdims=True) * 127)
    quantized = quantized.astype(np.int8)
    decoded = quantized.astype(np.float32)
    decoded /= np.linalg.norm(decoded, axis=1, keepdims=True)
    groups = defaultdict(list)
    for index, reference in enumerate(refs):
        groups[reference["subject_id"]].append(index)
    print(f"{len(refs)} vectors / {len(groups)} subjects / {matrix.shape[1]} dimensions")

    for split, probes in held_out.items():
        ranked = rank_probes(probes, embedder, decoded, groups)
        print(f"{split}: {len(ranked)} images")
        print("Known subjects:", summarize(ranked))
        print("True subject omitted from index:", summarize(ranked, excluded=True))

    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "reference_vectors.bin").write_bytes(quantized.tobytes())
        subjects = []
        for name, indexes in groups.items():
            row = refs[indexes[0]]
            subjects.append({
                "id": name, "label": "Satay" if name == "satay" else row["label"],
                "kind": row["kind"], "count": len(indexes),
            })
        manifest = {"dimensions": matrix.shape[1], "subjects": subjects}
        (args.output / "reference_index.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        attributions = ["# Reference index attribution", "",
                        "Generated image feature vectors. The app uses the vectors for similarity scoring.",
                        "", "The feature extractor is [MediaPipe MobileNet V3 Large]"
                        "(https://storage.googleapis.com/mediapipe-models/image_embedder/"
                        "mobilenet_v3_large/float32/1/mobilenet_v3_large.tflite).",
                        "The model metadata declares Apache License 2.0. See [MODEL_LICENSE.txt](MODEL_LICENSE.txt).",
                        "", "Food features from ParkingBot Dataset’s",
                        "[Malaysian Food Image Recognition, version 7]"
                        "(https://universe.roboflow.com/parkingbot-dataset/malaysian-food-image-recognition/dataset/7),",
                        "[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).",
                        "Images were cropped and encoded as feature vectors.", "",
                        "Landmark photos were resized and encoded as feature vectors.", ""]
        attributions.extend(f"- [{row['label']}]({row['source']}) by {row['creator']}"
                            f" · [{row['license']}]({row['license_url']})"
                            for row in refs if row["kind"] == "landmark")
        (args.output / "REFERENCE_SOURCES.md").write_text(
            "\n".join(attributions) + "\n", encoding="utf-8"
        )


if __name__ == "__main__":
    main()
