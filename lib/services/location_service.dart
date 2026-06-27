import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng _currentLocation = const LatLng(3.1390, 101.6869); // Default KL City Centre
  bool _isUsingRealGps = false;
  String _currentAreaName = 'Kuala Lumpur City Centre';

  LatLng get currentLocation => _currentLocation;
  bool get isUsingRealGps => _isUsingRealGps;
  String get currentAreaName => _currentAreaName;

  void updateLocation(LatLng location, String areaName, {bool isRealGps = false}) {
    _currentLocation = location;
    _currentAreaName = areaName;
    _isUsingRealGps = isRealGps;
    notifyListeners();
  }

  // Simulated GPS track options around Kuala Lumpur for demonstration
  static const mockGpsOptions = [
    (name: 'Petronas Twin Towers Area', lat: 3.1579, lon: 101.7120),
    (name: 'Batu Caves Temple Grounds', lat: 3.2379, lon: 101.6840),
    (name: 'Bukit Bintang Street Walk', lat: 3.1468, lon: 101.7087),
    (name: 'KL Sentral Transport Hub', lat: 3.1344, lon: 101.6861),
  ];
}
