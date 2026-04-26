import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

enum DeviceLocationAccessState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class DeviceLocationAccessResult {
  const DeviceLocationAccessResult({required this.state, this.message});

  final DeviceLocationAccessState state;
  final String? message;

  bool get isGranted => state == DeviceLocationAccessState.granted;
}

/// Encapsula acesso ao GPS para manter o restante código desacoplado do plugin.
class DeviceLocationService {
  const DeviceLocationService();

  Future<DeviceLocationAccessResult> ensureAccess() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const DeviceLocationAccessResult(
        state: DeviceLocationAccessState.serviceDisabled,
        message: 'Ative o GPS do dispositivo para usar localização dinâmica.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const DeviceLocationAccessResult(
        state: DeviceLocationAccessState.denied,
        message: 'Permissão de localização negada.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const DeviceLocationAccessResult(
        state: DeviceLocationAccessState.deniedForever,
        message: 'Permissão de localização negada permanentemente.',
      );
    }

    return const DeviceLocationAccessResult(
      state: DeviceLocationAccessState.granted,
    );
  }

  Future<GeoPoint?> getCurrentPosition() async {
    final access = await ensureAccess();
    if (!access.isGranted) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: _singleShotLocationSettings,
    );

    return GeoPoint(lat: position.latitude, lng: position.longitude);
  }

  Stream<GeoPoint> positionStream({
    int distanceFilterMeters = 15,
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).map(
      (position) => GeoPoint(lat: position.latitude, lng: position.longitude),
    );
  }

  LocationSettings get _singleShotLocationSettings => const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 20),
  );
}
