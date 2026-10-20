import 'dart:js_interop';

@JS('smartTravelMapsReady')
external JSPromise<JSBoolean> _mapsReady();
Future<bool> ensureWebMap() async {
  try {
    return (await _mapsReady().toDart).toDart;
  } catch (_) {
    return false;
  }
}
