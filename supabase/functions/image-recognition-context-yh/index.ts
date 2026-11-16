import { createHandler } from '../image-recognition/handler.mjs';
import { searchScanPlaces } from './scan_places.mjs';
import { suggestVisualLandmark } from './visual_suggestion.mjs';

Deno.serve(createHandler({
  env: (name: string) => Deno.env.get(name),
  contextOnly: true,
  searchScanPlaces,
  suggestVisualLandmark,
}));
