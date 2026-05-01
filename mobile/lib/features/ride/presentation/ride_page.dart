import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/driver_profile.dart';
import '../../../models/driver_rating.dart';
import '../../../models/geo_point.dart';
import '../../../models/ride.dart';
import '../../../services/drivers_service.dart';
import '../../../services/ratings_service.dart';
import '../../../services/realtime_map_service.dart';
import '../../../services/rides_service.dart';
import 'dropoff_map_picker_page.dart';

class RidePage extends StatefulWidget {
  const RidePage({
    super.key,
    required this.ridesService,
    required this.realtimeMapService,
    required this.driversService,
    required this.ratingsService,
    required this.pickup,
    required this.hasLivePickup,
    this.dropoff,
    required this.onCaptureDropoffFromGps,
    required this.onSelectDropoffFromMap,
    required this.onClearDropoff,
    this.locationWarning,
    required this.userId,
    required this.role,
  });

  final RidesService ridesService;
  final RealtimeMapService realtimeMapService;
  final DriversService driversService;
  final RatingsService ratingsService;
  final GeoPoint pickup;
  final bool hasLivePickup;
  final GeoPoint? dropoff;
  final Future<GeoPoint?> Function() onCaptureDropoffFromGps;
  final ValueChanged<GeoPoint> onSelectDropoffFromMap;
  final VoidCallback onClearDropoff;
  final String? locationWarning;
  final String? userId;
  final String? role;

  @override
  State<RidePage> createState() => _RidePageState();
}

class _RidePageState extends State<RidePage> {
  final List<Ride> _rides = [];
  final Map<String, DriverRating> _ratingsByRideId = {};

  Ride? _activeRide;
  DriverProfile? _driverProfile;
  DriverRatingSummary? _driverRatingSummary;
  bool _isLoading = false;
  bool _isUpdatingDriverStatus = false;
  bool _isSubmittingRating = false;
  String? _errorMessage;

  late final StreamSubscription<Ride> _rideUpdatesSubscription;
  late final StreamSubscription<String> _realtimeErrorsSubscription;

  bool get _isAuthenticated => (widget.userId ?? '').trim().isNotEmpty;
  bool get _isClient => (widget.role ?? '').toLowerCase() == 'client';
  bool get _isDriver => (widget.role ?? '').toLowerCase() == 'driver';
  bool get _isDriverOnline =>
      (_driverProfile?.status.toLowerCase() ?? 'offline') == 'online';

  @override
  void initState() {
    super.initState();
    _rideUpdatesSubscription = widget.realtimeMapService.rideUpdatedStream.listen(
      _onRideUpdated,
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

    if (oldWidget.userId != widget.userId || oldWidget.role != widget.role) {
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
        _driverProfile = null;
        _driverRatingSummary = null;
        _ratingsByRideId.clear();
        _errorMessage = null;
      });
      return;
    }

    final userId = widget.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      widget.realtimeMapService.connect(userId: userId);
    }

    if (_isDriver) {
      await _loadDriverState();
    }
    if (_isClient) {
      await _loadClientRatings();
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

      rides.sort(_sortByUpdateDesc);
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

  Future<void> _loadDriverState() async {
    try {
      final profile = await widget.driversService.loadMyProfile();
      final summary = await widget.ratingsService.getDriverSummary(profile.userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _driverProfile = profile;
        _driverRatingSummary = summary;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao carregar estado do taxista: $error';
      });
    }
  }

  Future<void> _loadClientRatings() async {
    try {
      final ratings = await widget.ratingsService.listMyGivenRatings();
      if (!mounted) {
        return;
      }

      setState(() {
        _ratingsByRideId
          ..clear()
          ..addEntries(ratings.map((rating) => MapEntry(rating.rideId, rating)));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao carregar avaliações: $error';
      });
    }
  }

  Future<void> _toggleDriverStatus() async {
    if (!_isDriver || _isUpdatingDriverStatus) {
      return;
    }

    setState(() {
      _isUpdatingDriverStatus = true;
      _errorMessage = null;
    });

    try {
      final nextStatus = _isDriverOnline ? 'offline' : 'online';
      final profile = await widget.driversService.updateMyStatus(status: nextStatus);
      if (!mounted) {
        return;
      }

      setState(() {
        _driverProfile = profile;
      });
      _showMessage(
        nextStatus == 'online'
            ? 'Taxista disponível para receber corridas.'
            : 'Taxista marcado como indisponível.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao atualizar estado do taxista: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDriverStatus = false;
        });
      }
    }
  }

  Future<void> _requestRide() async {
    if (!_isClient || !_isAuthenticated) {
      return;
    }

    if (_activeRide != null && !_isClosed(_activeRide!.status)) {
      _showMessage('Já existe uma corrida ativa. Termine/cancele antes de pedir outra.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.ridesService.requestRide(
        pickup: widget.pickup,
        dropoff: widget.dropoff,
      );
      if (!mounted) {
        return;
      }

      _upsertRide(created);
      setState(() {
        _activeRide = created;
      });
      _showMessage('Corrida solicitada.');
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

  Future<void> _cancelActiveRide() async {
    final ride = _activeRide;
    if (ride == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.ridesService.cancelRide(ride.id);
      if (!mounted) {
        return;
      }

      _upsertRide(updated);
      setState(() {
        _activeRide = _findActiveRide(_rides);
      });
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

  Future<void> _respondToRide(RideResponseAction action) async {
    final ride = _activeRide;
    if (ride == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.ridesService.respondToRide(
        rideId: ride.id,
        action: action,
      );
      if (!mounted) {
        return;
      }

      _upsertRide(updated);
      setState(() {
        _activeRide = _findActiveRide(_rides);
      });
      _showMessage(
        action == RideResponseAction.accept
            ? 'Corrida aceite.'
            : 'Corrida rejeitada.',
      );
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

  Future<void> _startRide() async {
    final ride = _activeRide;
    if (ride == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.ridesService.startRide(ride.id);
      if (!mounted) {
        return;
      }
      _upsertRide(updated);
      setState(() {
        _activeRide = _findActiveRide(_rides);
      });
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

  Future<void> _completeRide() async {
    final ride = _activeRide;
    if (ride == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.ridesService.completeRide(ride.id);
      if (!mounted) {
        return;
      }
      _upsertRide(updated);
      setState(() {
        _activeRide = _findActiveRide(_rides);
      });
      _showMessage('Corrida concluída.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao concluir corrida: $error';
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
      _showMessage('Não foi possível capturar dropoff pelo GPS.');
      return;
    }
    _showMessage('Dropoff atualizado com GPS.');
  }

  Future<void> _pickDropoffOnMap() async {
    final selected = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) => DropoffMapPickerPage(
          pickup: widget.pickup,
          initialDropoff: widget.dropoff,
        ),
      ),
    );
    if (selected == null) {
      return;
    }

    widget.onSelectDropoffFromMap(selected);
  }

  Future<void> _openRatingDialog(Ride ride) async {
    if (!_isClient || _isSubmittingRating) {
      return;
    }

    var selectedStars = 5;
    final stars = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Avaliar taxista'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('1 = Insatisfeito | 5 = Super satisfeito'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final selected = value == selectedStars;
                      return ChoiceChip(
                        label: Text(value.toString()),
                        selected: selected,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedStars = value;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedStars),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (stars == null) {
      return;
    }

    setState(() {
      _isSubmittingRating = true;
      _errorMessage = null;
    });

    try {
      final rating = await widget.ratingsService.submitDriverRating(
        rideId: ride.id,
        stars: stars,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ratingsByRideId[ride.id] = rating;
      });
      _showMessage('Avaliação registada: ${rating.satisfactionLabel}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao avaliar taxista: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  void _onRideUpdated(Ride ride) {
    if (!mounted) {
      return;
    }

    _upsertRide(ride);
    setState(() {
      _activeRide = _findActiveRide(_rides);
    });
  }

  void _upsertRide(Ride ride) {
    final index = _rides.indexWhere((item) => item.id == ride.id);
    if (index >= 0) {
      _rides[index] = ride;
    } else {
      _rides.add(ride);
    }
    _rides.sort(_sortByUpdateDesc);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Registe um utilizador no separador "Acesso" para usar corridas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.locationWarning != null && widget.locationWarning!.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.locationWarning!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_isDriver) _buildDriverStatusCard(context),
          if (_isDriver) const SizedBox(height: 12),
          if (_isClient) _buildClientRequestCard(context),
          if (_isClient) const SizedBox(height: 12),
          _buildActiveRideCard(context),
          const SizedBox(height: 12),
          _buildRideHistoryCard(context),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final ratingSummary = _driverRatingSummary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Disponibilidade do taxista', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _isDriverOnline ? 'Estado atual: Online' : 'Estado atual: Offline',
            ),
            if (_driverProfile != null) ...[
              const SizedBox(height: 6),
              Text(
                _driverProfile!.isProfileComplete
                    ? 'Perfil do taxista completo.'
                    : 'Perfil parcial (opcional nesta fase).',
              ),
            ],
            if (ratingSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                'Avaliação média: ${ratingSummary.averageStars.toStringAsFixed(2)} '
                '(${ratingSummary.totalRatings} avaliação(ões))',
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _isUpdatingDriverStatus ? null : _toggleDriverStatus,
              icon: Icon(_isDriverOnline ? Icons.toggle_off : Icons.toggle_on),
              label: Text(
                _isUpdatingDriverStatus
                    ? 'A atualizar...'
                    : (_isDriverOnline ? 'Ficar offline' : 'Ficar online'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientRequestCard(BuildContext context) {
    final theme = Theme.of(context);
    final dropoff = widget.dropoff;
    final hasActiveOpenRide = _activeRide != null && !_isClosed(_activeRide!.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pedir corrida', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Pickup: ${_formatPoint(widget.pickup)}'),
            Text(
              dropoff == null
                  ? 'Dropoff: não definido'
                  : 'Dropoff: ${_formatPoint(dropoff)}',
            ),
            if (!widget.hasLivePickup) ...[
              const SizedBox(height: 4),
              const Text('Sem GPS ao vivo: o pickup usa o último ponto conhecido.'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _captureDropoffFromGps,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Dropoff por GPS'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDropoffOnMap,
                  icon: const Icon(Icons.map),
                  label: const Text('Dropoff no mapa'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onClearDropoff,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpar dropoff'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasActiveOpenRide ? null : _requestRide,
              icon: const Icon(Icons.local_taxi),
              label: const Text('Solicitar corrida'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRideCard(BuildContext context) {
    final theme = Theme.of(context);
    final ride = _activeRide;

    if (ride == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _isDriver
                ? 'Sem corrida ativa neste momento.'
                : 'Peça uma corrida para iniciar o fluxo.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final canCancel = _isClient && !_isClosed(ride.status);
    final canAcceptOrReject =
        _isDriver && ride.status.toLowerCase() == 'assigned' && _isDriverRide(ride);
    final canStart =
        _isDriver && ride.status.toLowerCase() == 'accepted' && _isDriverRide(ride);
    final canComplete =
        _isDriver && ride.status.toLowerCase() == 'in_progress' && _isDriverRide(ride);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Corrida ativa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('ID: ${ride.id}'),
            Text('Estado: ${_toStatusLabel(ride.status)}'),
            Text('Pickup: ${_formatPoint(ride.pickup)}'),
            if (ride.dropoff != null) Text('Dropoff: ${_formatPoint(ride.dropoff!)}'),
            if (ride.searchRadiusKm != null)
              Text('Raio de busca: ${ride.searchRadiusKm!.toStringAsFixed(1)} km'),
            const SizedBox(height: 12),
            if (canCancel)
              FilledButton.tonalIcon(
                onPressed: _cancelActiveRide,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancelar corrida'),
              ),
            if (canAcceptOrReject) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _respondToRide(RideResponseAction.accept),
                      icon: const Icon(Icons.check),
                      label: const Text('Aceitar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondToRide(RideResponseAction.reject),
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeitar'),
                    ),
                  ),
                ],
              ),
            ],
            if (canStart)
              FilledButton.icon(
                onPressed: _startRide,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar corrida'),
              ),
            if (canComplete)
              FilledButton.icon(
                onPressed: _completeRide,
                icon: const Icon(Icons.flag),
                label: const Text('Concluir corrida'),
              ),
            if (_isClient && ride.status.toLowerCase() == 'completed') ...[
              const SizedBox(height: 10),
              _buildRatingSection(ride),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistoryCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Minhas corridas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_rides.isEmpty)
              const Text('Sem corridas registadas.')
            else
              ..._rides.take(8).map((ride) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Corrida ${ride.id}'),
                          Text('Estado: ${_toStatusLabel(ride.status)}'),
                          Text('Pickup: ${_formatPoint(ride.pickup)}'),
                          if (ride.dropoff != null)
                            Text('Dropoff: ${_formatPoint(ride.dropoff!)}'),
                          if (_isClient && ride.status.toLowerCase() == 'completed')
                            _buildRatingSection(ride),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(Ride ride) {
    final existingRating = _ratingsByRideId[ride.id];
    if (existingRating != null) {
      return Text(
        'Avaliação: ${existingRating.stars}/5 (${existingRating.satisfactionLabel})',
      );
    }

    return OutlinedButton.icon(
      onPressed: _isSubmittingRating ? null : () => _openRatingDialog(ride),
      icon: const Icon(Icons.star_rate),
      label: Text(_isSubmittingRating ? 'A enviar...' : 'Avaliar taxista'),
    );
  }

  bool _isDriverRide(Ride ride) {
    final profile = _driverProfile;
    if (profile == null) {
      return false;
    }
    return ride.driverId == profile.userId;
  }

  bool _isClosed(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'cancelled' || normalized == 'completed';
  }

  Ride? _findActiveRide(List<Ride> rides) {
    for (final ride in rides) {
      if (!_isClosed(ride.status)) {
        return ride;
      }
    }
    return rides.isEmpty ? null : rides.first;
  }

  int _sortByUpdateDesc(Ride a, Ride b) {
    final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  }

  String _formatPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}';
  }

  String _toStatusLabel(String status) {
    return switch (status.toLowerCase()) {
      'searching' => 'À procura',
      'assigned' => 'Atribuída',
      'accepted' => 'Aceite',
      'in_progress' => 'Em curso',
      'cancelled' => 'Cancelada',
      'completed' => 'Concluída',
      'rejected' => 'Rejeitada',
      _ => status,
    };
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
