# Malaysian recognition reference photos

Run the dataset tools from the repository on Windows with PowerShell and curl.
The local `.recognition-dataset` directory holds the images, publisher metadata
and CSV manifests. Keep the files outside Flutter's assets and Git.

```powershell
powershell -NoProfile -File tool/download_recognition_dataset.ps1 -Source landmark
powershell -NoProfile -File tool/download_recognition_dataset.ps1 -Source food
powershell -NoProfile -File tool/download_recognition_dataset.ps1 -Source cuisine
powershell -NoProfile -File tool/download_recognition_dataset.ps1 -Source google-landmarks -PhotosPerSubject 3
powershell -NoProfile -File tool/import_recognition_food_zip.ps1 -ZipPath '<downloaded ZIP>'
```

- **Wikimedia Commons.** `landmark` and `food` read subject categories from
  `recognition_dataset_subjects.csv`. Manifests retain the source page, creator,
  license, dimensions and SHA-256, with up to two photos per creator per subject.
  A low count means a category, file license or download needs a follow-up.
- **Google Landmarks v2.** The importer reads the class-to-category mapping and
  the first 24 MB of the published training index. It looks up matching Malaysian
  photos in Commons to record current attribution and avoids source pages already
  listed in `landmark.csv`. This is a targeted subset of the global dataset.
  [Publisher metadata](https://github.com/cvdfoundation/google-landmark#download-train-set)
- **Malaysian Cuisine Image Dataset.** `cuisine` downloads the publisher's image
  files and label CSV and checks each image against its published SHA-256. The
  dataset card declares Apache-2.0. Verify individual photo provenance before
  including these images in a distributable reference index.
  [Dataset card](https://huggingface.co/datasets/ychwodhrey/malaysian-cuisine)
- **Roboflow Malaysian Food Image Recognition.** Download version 7 as a COCO
  segmentation ZIP. The importer checks photo dimensions against the annotations,
  produces labelled bounding-box crops, skips the Reference Card class, and
  retains the publisher split and original image hash. The publisher lists CC BY 4.0.
  [Dataset export](https://universe.roboflow.com/parkingbot-dataset/malaysian-food-image-recognition/dataset/7)

Use the manifest paths when loading images. A download may leave files outside
the manifest after deduplication or if a transfer is interrupted.

The first local pass includes `roboflow-v7-coco.zip`, a `roboflow.csv` index of
3,109 crops across 19 food categories, and `commons-reviewed.csv` with 49
landmark photos and 43 food photos. The reviewed set includes two photos
located through the Google Landmarks index. The separate `cuisine.csv`
manifest contains the 10 Hugging Face photos awaiting file-level provenance
review.

The Roboflow file count includes augmented variants. The crop export uses a
minimum bounding-box side of 96 pixels. Use `publisher_source_group` to keep
versions of the same source photo together. The current export has no filename
group shared between its train, validation and test splits.

Review subject labels and photos before building the reference index. Keep
near-duplicates and augmented versions of the same original together when
creating an evaluation set. Measure both the change in **No confident match**
and the change in incorrect matches on held-out photos.

## Bundled scanner fallback

Google Vision runs first. If it returns an unknown subject, Flutter embeds the
same photo locally and searches 744 reference vectors covering 19 food classes
and 13 landmarks. A result needs both a high similarity and a lead over the next
subject to be accepted automatically. The result page offers up to three
candidates when the user can reasonably compare the options. History remembers
the choice. For weak evidence the scanner keeps its original no-match result.

The YH app also calls the authenticated `image-recognition-context-yh` function
on an inconclusive scan. It checks matching web images and reads text already
visible in the photo. A single matching page or a readable known landmark name
can produce a suggestion. Automatic web matches need full matching images on
two distinct domains, or a full matching image and agreeing text. Results that
remain uncertain offer a place search using a user-entered Google Maps query.

The app bundles the model, reference vectors and source attributions. The
Roboflow archive, reference photos and benchmark photos stay in the local
dataset folder. The local comparison runs on the device.

```powershell
python -m pip install ai-edge-litert numpy pillow
python tool/build_recognition_index.py --model assets/recognition/reference/mobilenet_v3_large.tflite
python tool/build_recognition_index.py --model assets/recognition/reference/mobilenet_v3_large.tflite --output assets/recognition/reference
```

The benchmark compares the fallback against the case where Vision has already
returned an unknown result. It does not call Vision or estimate end-to-end
recognition accuracy. On the held-out test images it produced these results.

| Test images | Correct automatic | Wrong automatic | Correct subject among choices | Choices missing subject | No match |
| --- | ---: | ---: | ---: | ---: | ---: |
| 178 food photos | 14 | 0 | 56 | 1 | 107 |
| 10 landmark photos | 1 | 0 | 1 | 0 | 8 |

Roboflow validation and test captures stay out of the reference index. The
landmark check withholds photos from a different creator wherever the reviewed
set has adequate coverage. With the true class removed from the index, none of
the 188 test photos returned a confident match and 29 offered alternatives.
Use independent gallery and camera photos to measure app-level accuracy.
