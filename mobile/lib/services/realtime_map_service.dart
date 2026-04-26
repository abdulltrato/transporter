import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/driver.dart';
import '../models/geo_point.dart';
import '../models/ride.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected
}

class DriverStatusUpdate {
  const DriverStatusUpdate({
    required this.driverId,
    required this.isOnline,
    required this.updatedAt
  });

  final String driverId;
  final bool isOnline;
  final DateTime updatedAt;

  factory DriverStatusUpdate.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String? ?? '').toLowerCase();

    return DriverStatusUpdate(
      driverId: (json['driverId'] ?? '').toString(),
      isOnline: status == 'online',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now()
    );
  }
}

class DriverLocationUpdate {
  const DriverLocationUpdate({
    required this.driverId,
    required this.coordinates,
    required this.updatedAt
  });

  final String driverId;
  final GeoPoint coordinates;
  final DateTime updatedAt;

  factory DriverLocationUpdate.fromJson(Map<String, dynamic> json) {
    final coordinates = _toJsonMap(json['coordinates']) ?? const <String, dynamic>{};

    return DriverLocationUpdate(
      driverId: (json['driverId'] ?? '').toString(),
      coordinates: GeoPoint.fromJson(coordinates),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now()
    );
  }
}

class MapSnapshot {
  const MapSnapshot({
    required this.origin,
    required this.radiusKm,
    required this.generatedAt,
    required this.drivers
  });

  final GeoPoint origin;
  final double radiusKm;
  final DateTime generatedAt;
  final List<Driver> drivers;

  factory MapSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDrivers = json['drivers'] as List<dynamic>? ?? const [];
    final origin = _toJsonMap(json['origin']) ?? const <String, dynamic>{};

    return MapSnapshot(
      origin: GeoPoint.fromJson(origin),
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 2,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
      drivers: rawDrivers
          .map(_toJsonMap)
          .whereType<Map<String, dynamic>>()
          .map(Driver.fromJson)
          .toList()
    );
  }
}

class RealtimeMapService {
  RealtimeMapService({required this.baseUrl});

  final String baseUrl;

  io.Socket? _socket;
  String? _token;

  final _connectionStateController = StreamController<RealtimeConnectionState>.broadcast();
  final _snapshotController = StreamController<MapSnapshot>.broadcast();
  final _driverStatusController = StreamController<DriverStatusUpdate>.broadcast();
  final _driverLocationController = StreamController<DriverLocationUpdate>.broadcast();
  final _rideUpdatedController = StreamController<Ride>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<MapSnapshot> get snapshotStream => _snapshotController.stream;
  Stream<DriverStatusUpdate> get driverStatusStream => _driverStatusController.stream;
  Stream<DriverLocationUpdate> get driverLocationStream =>
      _driverLocationController.stream;
  Stream<Ride> get rideUpdatedStream => _rideUpdatedController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect({required String token}) {
    final sanitizedToken = token.trim();
    if (sanitizedToken.isEmpty) {
      disconnect();
      return;
    }

    if (_token == sanitizedToken && _socket != null) {
      if (_socket!.connected) {
        _connectionStateController.add(RealtimeConnectionState.connected);
      } else {
        _connectionStateController.add(RealtimeConnectionState.connecting);
        _socket!.connect();
      }
      return;
    }

    _token = sanitizedToken;
    disconnect();

    _connectionStateController.add(RealtimeConnectionState.connecting);

    final socket = io.io(
      _buildRealtimeUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': sanitizedToken})
          .setExtraHeaders({'Authorization': 'Bearer $sanitizedToken'})
          .disableAutoConnect()
          .build()
    );

    socket.onConnect((_) {
      _connectionStateController.add(RealtimeConnectionState.connected);
    });

    socket.onDisconnect((_) {
      _connectionStateController.add(RealtimeConnectionState.disconnected);
    });

    socket.onConnectError((error) {
      _errorController.add('Falha ao conectar no realtime: $error');
      _connectionStateController.add(RealtimeConnectionState.disconnected);
    });

    socket.onError((error) {
      _errorController.add('Erro realtime: $error');
    });

    socket.on('auth:error', (payload) {
      final event = _toJsonMap(payload);
      if (event != null) {
        _errorController.add(event['message'] as String? ?? 'Falha de autenticacao.');
        return;
      }

      _errorController.add('Falha de autenticacao no realtime.');
    });

    socket.on('map:snapshot', (payload) {
      final event = _toJsonMap(payload);
      if (event != null) {
        _snapshotController.add(MapSnapshot.fromJson(event));
      }
    });

    socket.on('driver:status', (payload) {
      final event = _toJsonMap(payload);
      if (event != null) {
        _driverStatusController.add(DriverStatusUpdate.fromJson(event));
      }
    });

    socket.on('driver:location', (payload) {
      final event = _toJsonMap(payload);
      if (event != null) {
        _driverLocationController.add(DriverLocationUpdate.fromJson(event));
      }
    });

    socket.on('ride:updated', (payload) {
      final event = _toJsonMap(payload);
      if (event != null) {
        _rideUpdatedController.add(Ride.fromJson(event));
      }
    });

    _socket = socket;
    socket.connect();
  }

  void reconnect() {
    final token = _token;
    if (token == null || token.trim().isEmpty) {
      return;
    }

    connect(token: token);
  }

  void subscribeToMap({
    required GeoPoint origin,
    double radiusKm = 2
  }) {
    final payload = {
      'lat': origin.lat,
      'lng': origin.lng,
      'radiusKm': radiusKm
    };

    _socket?.emit('map:subscribe', payload);
  }

  void unsubscribeFromMap() {
    _socket?.emit('map:unsubscribe');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionStateController.add(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _snapshotController.close();
    _driverStatusController.close();
    _driverLocationController.close();
    _rideUpdatedController.close();
    _errorController.close();
  }

  String _buildRealtimeUrl() {
    final uri = Uri.parse(baseUrl);
    final segments = <String>[
      ...uri.pathSegments.where((segment) => segment.isNotEmpty)
    ];

    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      segments.removeLast();
    }

    final pathPrefix = segments.isEmpty ? '' : '/${segments.join('/')}';
    final port = uri.hasPort ? ':${uri.port}' : '';

    return '${uri.scheme}://${uri.host}$port$pathPrefix/realtime';
  }
}

Map<String, dynamic>? _toJsonMap(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }

  if (payload is Map) {
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  return null;
}
