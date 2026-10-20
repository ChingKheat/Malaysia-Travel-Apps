import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'map_bootstrap_stub.dart'
    if (dart.library.js_interop) 'map_bootstrap_web.dart'
    as web;

Future<bool> ensureGoogleMapReady() async {
  if (kIsWeb) return web.ensureWebMap();
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  try {
    return await const MethodChannel(
          'smart_travel/maps',
        ).invokeMethod<bool>('configured') ??
        false;
  } catch (_) {
    return false;
  }
}
