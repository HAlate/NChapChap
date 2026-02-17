import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    print('LocationService: getCurrentLocation called');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        print('LocationService: permission requested, result: $permission');
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied by user');
        }
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      print('LocationService: got position $pos');
      return pos;
    } catch (e, st) {
      print('LocationService: ERROR $e\n$st');
      rethrow;
    }
  }
}
