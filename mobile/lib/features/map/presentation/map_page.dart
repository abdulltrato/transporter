import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/driver.dart';
import '../../../models/geo_point.dart';
import '../../../services/location_service.dart';
import '../../../services/realtime_map_service.dart';

/// Ecrã de mapa com lista de taxistas próximos e estado de ligação em tempo real.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.locationService,
    required this.realtimeMapService,
    required this.origin,
    required this.radiusKm,
    required this.userId,
  });

  final LocationService locationService;
  final RealtimeMapService realtimeMapService;
  final GeoPoint origin;
  final double radiusKm;
  final String? userId;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final List<Driver> _drivers = [];

  bool _isLoading = false;
  String? _errorMessage;
  RealtimeConnectionState _connectionState =
      RealtimeConnectionState.disconnected;

  late final StreamSubscription<RealtimeConnectionState>
  _connectionSubscription;
  late final StreamSubscription<MapSnapshot> _snapshotSubscription;
  late final StreamSubscription<DriverStatusUpdate> _statusSubscription;
  late final StreamSubscription<DriverLocationUpdate> _locationSubscription;
  late final StreamSubscription<String> _errorSubscription;

  bool get _isAuthenticated => (widget.userId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _connectionSubscription = widget.realtimeMapService.connectionStateStream
        .listen(_onConnectionStateChanged);
    _snapshotSubscription = widget.realtimeMapService.snapshotStream.listen(
      _onMapSnapshot,
    );
    _statusSubscription = widget.realtimeMapService.driverStatusStream.listen(
      _onDriverStatusUpdated,
    );
    _locationSubscription = widget.realtimeMapService.driverLocationStream
        .listen(_onDriverLocationUpdated);
    _errorSubscription = widget.realtimeMapService.errorStream.listen((error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error;
      });
    });

    _startRealtimeFlow();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.origin.lat != widget.origin.lat ||
        oldWidget.origin.lng != widget.origin.lng ||
        oldWidget.radiusKm != widget.radiusKm) {
      _startRealtimeFlow();
    }
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    _snapshotSubscription.cancel();
    _statusSubscription.cancel();
    _locationSubscription.cancel();
    _errorSubscription.cancel();
    widget.realtimeMapService.unsubscribeFromMap();
    super.dispose();
  }

  Future<void> _startRealtimeFlow() async {
    final userId = widget.userId?.trim();
    if (userId == null || userId.isEmpty) {
      widget.realtimeMapService.disconnect();
      if (!mounted) {
        return;
      }

      setState(() {
        _drivers.clear();
        _connectionState = RealtimeConnectionState.disconnected;
      });
      return;
    }

    await _loadNearbyDrivers();
    widget.realtimeMapService.connect(userId: userId);
    if (widget.realtimeMapService.isConnected) {
      widget.realtimeMapService.subscribeToMap(
        origin: widget.origin,
        radiusKm: widget.radiusKm,
      );
    }
  }

  Future<void> _loadNearbyDrivers() async {
    if (!_isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loadedDrivers = await widget.locationService.loadNearbyDrivers(
        widget.origin,
        radiusKm: widget.radiusKm,
      );

      if (!mounted) {
        return;
      }

      loadedDrivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      setState(() {
        _drivers
          ..clear()
          ..addAll(loadedDrivers);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao carregar taxistas próximos: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onConnectionStateChanged(RealtimeConnectionState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _connectionState = state;
    });

    if (state == RealtimeConnectionState.connected && _isAuthenticated) {
      widget.realtimeMapService.subscribeToMap(
        origin: widget.origin,
        radiusKm: widget.radiusKm,
      );
    }
  }

  void _onMapSnapshot(MapSnapshot snapshot) {
    if (!mounted) {
      return;
    }

    final updated = [...snapshot.drivers]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    setState(() {
      _drivers
        ..clear()
        ..addAll(updated);
    });
  }

  void _onDriverStatusUpdated(DriverStatusUpdate update) {
    if (!mounted) {
      return;
    }
    if (update.driverId.isEmpty) {
      return;
    }

    final index = _drivers.indexWhere(
      (driver) => driver.userId == update.driverId,
    );

    if (!update.isOnline) {
      if (index == -1) {
        return;
      }

      setState(() {
        _drivers.removeAt(index);
      });
      return;
    }

    if (index == -1) {
      return;
    }

    setState(() {
      _drivers[index] = _drivers[index].copyWith(isOnline: true);
    });
  }

  void _onDriverLocationUpdated(DriverLocationUpdate update) {
    if (!mounted) {
      return;
    }
    if (update.driverId.isEmpty) {
      return;
    }

    final index = _drivers.indexWhere(
      (driver) => driver.userId == update.driverId,
    );
    final distanceKm = _distanceInKm(widget.origin, update.coordinates);

    if (index == -1) {
      setState(() {
        _drivers.add(
          Driver(
            userId: update.driverId,
            name:
                'Taxista ${update.driverId.length > 6 ? update.driverId.substring(0, 6) : update.driverId}',
            distanceKm: distanceKm,
            location: update.coordinates,
            isOnline: true,
          ),
        );
        _drivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      });
      return;
    }

    setState(() {
      _drivers[index] = _drivers[index].copyWith(
        location: update.coordinates,
        distanceKm: distanceKm,
        isOnline: true,
      );
      _drivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Taxistas próximos')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Entre no separador Acesso para autenticar e ativar o mapa em tempo real.',
            ),
          ),
        ),
      );
    }

    final connectionLabel = switch (_connectionState) {
      RealtimeConnectionState.connected => 'Tempo real ligado',
      RealtimeConnectionState.connecting => 'A ligar ao tempo real...',
      RealtimeConnectionState.disconnected => 'Tempo real desligado',
    };

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxistas próximos'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _startRealtimeFlow,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: switch (_connectionState) {
              RealtimeConnectionState.connected =>
                theme.colorScheme.primaryContainer,
              RealtimeConnectionState.connecting =>
                theme.colorScheme.secondaryContainer,
              RealtimeConnectionState.disconnected =>
                theme.colorScheme.errorContainer,
            },
            child: Text(connectionLabel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Origem: ${_formatPoint(widget.origin)}\nRaio: ${widget.radiusKm.toStringAsFixed(1)} km',
                      ),
                    ),
                    Text(
                      '${_drivers.length} online',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: _drivers.isEmpty
                ? const Center(
                    child: Text('Nenhum taxista online no raio atual.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final driver = _drivers[index];
                      return Card(
                        child: ListTile(
                          title: Text(driver.name),
                          subtitle: Text(
                            '${driver.distanceKm.toStringAsFixed(1)} km de distância',
                          ),
                          trailing: driver.isOnline
                              ? const Chip(label: Text('Online'))
                              : const Chip(label: Text('Offline')),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _distanceInKm(GeoPoint origin, GeoPoint destination) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(destination.lat - origin.lat);
    final dLng = _degreesToRadians(destination.lng - origin.lng);
    final lat1 = _degreesToRadians(origin.lat);
    final lat2 = _degreesToRadians(destination.lat);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1) * cos(lat2) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * 0.017453292519943295;

  String _formatPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';
  }
}
