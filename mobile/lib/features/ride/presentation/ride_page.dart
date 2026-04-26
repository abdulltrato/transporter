import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/geo_point.dart';
import '../../../models/ride.dart';
import '../../../services/realtime_map_service.dart';
import '../../../services/rides_service.dart';

class RidePage extends StatefulWidget {
  const RidePage({
    super.key,
    required this.ridesService,
    required this.realtimeMapService,
    required this.pickup,
    required this.hasLivePickup,
    this.dropoff,
    required this.onCaptureDropoffFromGps,
    required this.onClearDropoff,
    this.locationWarning,
    required this.token,
    required this.role
  });

  final RidesService ridesService;
  final RealtimeMapService realtimeMapService;
  final GeoPoint pickup;
  final bool hasLivePickup;
  final GeoPoint? dropoff;
  final Future<GeoPoint?> Function() onCaptureDropoffFromGps;
  final VoidCallback onClearDropoff;
  final String? locationWarning;
  final String? token;
  final String? role;

  @override
  State<RidePage> createState() => _RidePageState();
}

class _RidePageState extends State<RidePage> {
  final List<Ride> _rides = [];

  Ride? _activeRide;
  bool _isLoading = false;
  String? _errorMessage;

  late final StreamSubscription<Ride> _rideUpdatesSubscription;
  late final StreamSubscription<String> _realtimeErrorsSubscription;

  bool get _isAuthenticated => (widget.token ?? '').trim().isNotEmpty;
  bool get _isClient => (widget.role ?? '').toLowerCase() == 'client';
  bool get _isDriver => (widget.role ?? '').toLowerCase() == 'driver';

  @override
  void initState() {
    super.initState();
    _rideUpdatesSubscription = widget.realtimeMapService.rideUpdatedStream.listen(
      _onRideUpdated
    );
    _realtimeErrorsSubscription = widget.realtimeMapService.errorStream.listen((error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error;
      });
    });

    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant RidePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.token != widget.token || oldWidget.role != widget.role) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _rideUpdatesSubscription.cancel();
    _realtimeErrorsSubscription.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!_isAuthenticated) {
      if (!mounted) {
        return;
      }

      setState(() {
        _rides.clear();
        _activeRide = null;
        _errorMessage = null;
      });
      return;
    }

    final token = widget.token?.trim();
    if (token != null && token.isNotEmpty) {
      widget.realtimeMapService.connect(token: token);
    }

    await _loadMyRides();
  }

  Future<void> _loadMyRides() async {
    if (!_isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rides = await widget.ridesService.listMyRides();
      if (!mounted) {
        return;
      }

      setState(() {
        _rides
          ..clear()
          ..addAll(rides);
        _activeRide = _findActiveRide(_rides);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao carregar corridas: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestRide() async {
    if (!_isClient) {
      _showMessage('Somente clientes podem solicitar corrida.');
      return;
    }

    if (!widget.hasLivePickup) {
      _showMessage('Ative o GPS para definir o pickup dinamico.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ride = await widget.ridesService.requestRide(
        pickup: widget.pickup,
        dropoff: widget.dropoff
      );

      if (!mounted) {
        return;
      }

      _mergeRide(ride);
      _showMessage('Corrida solicitada com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao solicitar corrida: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _captureDropoffFromGps() async {
    final point = await widget.onCaptureDropoffFromGps();
    if (!mounted) {
      return;
    }

    if (point == null) {
      _showMessage('Nao foi possivel capturar o destino pelo GPS.');
      return;
    }

    _showMessage('Destino atualizado para ${_formatGeoPoint(point)}');
  }

  void _clearDropoff() {
    widget.onClearDropoff();
    _showMessage('Destino removido. Corrida sera sem dropoff definido.');
  }

  Future<void> _cancelActiveRide() async {
    if (!_isClient) {
      _showMessage('Somente clientes podem cancelar corrida.');
      return;
    }

    final ride = _activeRide;
    if (ride == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cancelledRide = await widget.ridesService.cancelRide(ride.id);
      if (!mounted) {
        return;
      }

      _mergeRide(cancelledRide);
      _showMessage('Corrida cancelada.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao cancelar corrida: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptActiveRide() async {
    await _respondActiveRide(
      action: RideResponseAction.accept,
      successMessage: 'Corrida aceite com sucesso.'
    );
  }

  Future<void> _rejectActiveRide() async {
    await _respondActiveRide(
      action: RideResponseAction.reject,
      successMessage: 'Corrida rejeitada.'
    );
  }

  Future<void> _startActiveRide() async {
    if (!_isDriver) {
      _showMessage('Somente taxistas podem iniciar corridas.');
      return;
    }

    final ride = _activeRide;
    if (ride == null || !_canDriverStartRide(ride)) {
      _showMessage('Nenhuma corrida pronta para iniciar.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startedRide = await widget.ridesService.startRide(ride.id);
      if (!mounted) {
        return;
      }

      _mergeRide(startedRide);
      _showMessage('Corrida iniciada.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao iniciar corrida: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeActiveRide() async {
    if (!_isDriver) {
      _showMessage('Somente taxistas podem finalizar corridas.');
      return;
    }

    final ride = _activeRide;
    if (ride == null || !_canDriverCompleteRide(ride)) {
      _showMessage('Nenhuma corrida em andamento para finalizar.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final completedRide = await widget.ridesService.completeRide(ride.id);
      if (!mounted) {
        return;
      }

      _mergeRide(completedRide);
      _showMessage('Corrida finalizada.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao finalizar corrida: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondActiveRide({
    required RideResponseAction action,
    required String successMessage
  }) async {
    if (!_isDriver) {
      _showMessage('Somente taxistas podem responder corridas.');
      return;
    }

    final ride = _activeRide;
    if (ride == null || !_canDriverRespondRide(ride)) {
      _showMessage('Nenhuma corrida pendente para resposta.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updatedRide = await widget.ridesService.respondToRide(
        rideId: ride.id,
        action: action
      );
      if (!mounted) {
        return;
      }

      _mergeRide(updatedRide);
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao responder corrida: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onRideUpdated(Ride ride) {
    if (!mounted || ride.id.isEmpty) {
      return;
    }

    _mergeRide(ride);
  }

  void _mergeRide(Ride ride) {
    final index = _rides.indexWhere((item) => item.id == ride.id);

    setState(() {
      if (index == -1) {
        _rides.insert(0, ride);
      } else {
        _rides[index] = ride;
      }

      _rides.sort((a, b) {
        final left = a.updatedAt?.millisecondsSinceEpoch ?? 0;
        final right = b.updatedAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

      _activeRide = _findActiveRide(_rides);
    });
  }

  Ride? _findActiveRide(List<Ride> rides) {
    if (_isDriver) {
      for (final ride in rides) {
        if (_canDriverRespondRide(ride)) {
          return ride;
        }
      }

      for (final ride in rides) {
        if (_canDriverStartRide(ride)) {
          return ride;
        }
      }

      for (final ride in rides) {
        if (_canDriverCompleteRide(ride)) {
          return ride;
        }
      }
    }

    for (final ride in rides) {
      if (!_isClosedStatus(ride.status)) {
        return ride;
      }
    }

    return null;
  }

  bool _isClosedStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'cancelled' || normalized == 'completed';
  }

  bool _canCancelRide(Ride ride) {
    final normalized = ride.status.toLowerCase();
    return normalized == 'searching' ||
        normalized == 'assigned' ||
        normalized == 'accepted' ||
        normalized == 'in_progress';
  }

  bool _canDriverRespondRide(Ride ride) {
    return ride.status.toLowerCase() == 'assigned';
  }

  bool _canDriverStartRide(Ride ride) {
    return ride.status.toLowerCase() == 'accepted';
  }

  bool _canDriverCompleteRide(Ride ride) {
    return ride.status.toLowerCase() == 'in_progress';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  String _formatGeoPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Corrida')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Entre na aba Acesso para solicitar corrida e receber atualizacoes em tempo real.'
            )
          )
        )
      );
    }

    final activeRide = _activeRide;
    final canCancel = _isClient && activeRide != null && _canCancelRide(activeRide);
    final canRespond = _isDriver && activeRide != null && _canDriverRespondRide(activeRide);
    final canStart = _isDriver && activeRide != null && _canDriverStartRide(activeRide);
    final canComplete = _isDriver && activeRide != null && _canDriverCompleteRide(activeRide);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Corrida'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMyRides,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar corridas'
          )
        ]
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)
            )
          ],
          if (widget.locationWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.locationWarning!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)
            )
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Localizacao da corrida',
                    style: TextStyle(fontWeight: FontWeight.w700)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hasLivePickup
                        ? 'Pickup atual: ${_formatGeoPoint(widget.pickup)}'
                        : 'Pickup atual: aguardando GPS real'
                  ),
                  Text(
                    widget.dropoff == null
                        ? 'Dropoff: nao definido'
                        : 'Dropoff: ${_formatGeoPoint(widget.dropoff!)}'
                  ),
                  if (_isClient) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _captureDropoffFromGps,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Capturar dropoff por GPS')
                        ),
                        if (widget.dropoff != null)
                          OutlinedButton(
                            onPressed: _isLoading ? null : _clearDropoff,
                            child: const Text('Limpar dropoff')
                          )
                      ]
                    )
                  ]
                ]
              )
            )
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Corrida ativa',
                    style: TextStyle(fontWeight: FontWeight.w700)
                  ),
                  const SizedBox(height: 8),
                  if (activeRide == null) const Text('Nenhuma corrida ativa no momento.'),
                  if (activeRide != null) ...[
                    Text('ID: ${activeRide.id}'),
                    Text('Status: ${activeRide.status}'),
                    Text('Motorista: ${activeRide.driverId ?? 'aguardando atribuicao'}')
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_isClient)
                        FilledButton(
                          onPressed: _isLoading ? null : _requestRide,
                          child: const Text('Solicitar corrida')
                        ),
                      if (!_isClient)
                        const Text(
                          'Conta de taxista: acompanhe atualizacoes de corrida em tempo real.'
                        ),
                      if (canRespond)
                        FilledButton.tonal(
                          onPressed: _isLoading ? null : _acceptActiveRide,
                          child: const Text('Aceitar corrida')
                        ),
                      if (canRespond)
                        OutlinedButton(
                          onPressed: _isLoading ? null : _rejectActiveRide,
                          child: const Text('Rejeitar corrida')
                        ),
                      if (canStart)
                        FilledButton.tonal(
                          onPressed: _isLoading ? null : _startActiveRide,
                          child: const Text('Iniciar corrida')
                        ),
                      if (canComplete)
                        FilledButton(
                          onPressed: _isLoading ? null : _completeActiveRide,
                          child: const Text('Finalizar corrida')
                        ),
                      if (canCancel)
                        OutlinedButton(
                          onPressed: _isLoading ? null : _cancelActiveRide,
                          child: const Text('Cancelar corrida')
                        )
                    ]
                  )
                ]
              )
            )
          ),
          const SizedBox(height: 12),
          const Text(
            'Historico recente',
            style: TextStyle(fontWeight: FontWeight.w700)
          ),
          const SizedBox(height: 8),
          if (_rides.isEmpty)
            const Text('Sem corridas registradas para esta sessao.')
          else
            ..._rides.take(10).map((ride) {
              return Card(
                child: ListTile(
                  title: Text('Corrida ${ride.id}'),
                  subtitle: Text('Status: ${ride.status}'),
                  trailing: Text(
                    ride.driverId == null ? 'Sem motorista' : 'Com motorista'
                  )
                )
              );
            })
        ]
      )
    );
  }
}
