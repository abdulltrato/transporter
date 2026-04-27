import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/driver_profile.dart';
import '../../../models/driver_rating.dart';
import '../../../models/driver_subscription.dart';
import '../../../models/geo_point.dart';
import '../../../models/ride.dart';
import '../../../services/drivers_service.dart';
import '../../../services/ratings_service.dart';
import '../../../services/realtime_map_service.dart';
import '../../../services/rides_service.dart';
import '../../../services/subscription_service.dart';
import 'dropoff_map_picker_page.dart';

/// Ecrã de gestão de corridas para cliente e taxista.
class RidePage extends StatefulWidget {
  const RidePage({
    super.key,
    required this.ridesService,
    required this.realtimeMapService,
    required this.driversService,
    required this.subscriptionService,
    required this.ratingsService,
    required this.pickup,
    required this.hasLivePickup,
    this.dropoff,
    required this.onCaptureDropoffFromGps,
    required this.onSelectDropoffFromMap,
    required this.onClearDropoff,
    this.locationWarning,
    required this.token,
    required this.role,
  });

  final RidesService ridesService;
  final RealtimeMapService realtimeMapService;
  final DriversService driversService;
  final SubscriptionService subscriptionService;
  final RatingsService ratingsService;
  final GeoPoint pickup;
  final bool hasLivePickup;
  final GeoPoint? dropoff;
  final Future<GeoPoint?> Function() onCaptureDropoffFromGps;
  final ValueChanged<GeoPoint> onSelectDropoffFromMap;
  final VoidCallback onClearDropoff;
  final String? locationWarning;
  final String? token;
  final String? role;

  @override
  State<RidePage> createState() => _RidePageState();
}

class _RidePageState extends State<RidePage> {
  final List<Ride> _rides = [];
  final _paymentReferenceController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _documentExpiryController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _operatingRegionController = TextEditingController();

  Ride? _activeRide;
  DriverProfile? _driverProfile;
  DriverSubscription? _currentSubscription;
  List<DriverSubscription> _subscriptionHistory = [];
  Map<String, DriverRating> _ratingsByRideId = {};
  DriverRatingSummary? _driverRatingSummary;
  String _selectedPlan = 'monthly';
  String _selectedPaymentMethod = 'mpesa';
  bool _isLoading = false;
  bool _isSavingDriverProfile = false;
  bool _isUpdatingDriverStatus = false;
  bool _isSubmittingPayment = false;
  bool _isSubmittingRating = false;
  String? _errorMessage;

  late final StreamSubscription<Ride> _rideUpdatesSubscription;
  late final StreamSubscription<String> _realtimeErrorsSubscription;

  bool get _isAuthenticated => (widget.token ?? '').trim().isNotEmpty;
  bool get _isClient => (widget.role ?? '').toLowerCase() == 'client';
  bool get _isDriver => (widget.role ?? '').toLowerCase() == 'driver';
  bool get _isDriverOnline =>
      (_driverProfile?.status.toLowerCase() ?? 'offline') == 'online';

  String? get _driverOperationalBlockReason {
    if (!_isDriver) {
      return null;
    }

    if (_driverProfile != null && _driverProfile!.isProfileComplete == false) {
      return 'Complete o cadastro do taxista para operar.';
    }

    if (_currentSubscription == null) {
      return 'Subscrição obrigatória. Registe pagamento via M-Pesa/eMola.';
    }

    if (_currentSubscription!.isPending) {
      return 'Pagamento pendente de validação manual (até 30 minutos).';
    }

    if (!_currentSubscription!.isActive) {
      return 'Subscrição não ativa. Faça novo pagamento para ativar o serviço.';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _rideUpdatesSubscription = widget.realtimeMapService.rideUpdatedStream
        .listen(_onRideUpdated);
    _realtimeErrorsSubscription = widget.realtimeMapService.errorStream.listen((
      error,
    ) {
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
    _paymentReferenceController.dispose();
    _paymentNotesController.dispose();
    _documentIdController.dispose();
    _documentExpiryController.dispose();
    _neighborhoodController.dispose();
    _operatingRegionController.dispose();
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

    if (_isDriver) {
      await _loadDriverSubscriptionState();
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

  Future<void> _loadDriverSubscriptionState() async {
    if (!_isDriver || !_isAuthenticated) {
      return;
    }

    try {
      final profile = await widget.driversService.loadMyProfile();
      final current = await widget.subscriptionService.loadMyCurrentSubscription();
      final history = await widget.subscriptionService.listMySubscriptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _driverProfile = profile;
        _currentSubscription = current;
        _subscriptionHistory = history;
        _driverRatingSummary = null;
      });

      _syncDriverProfileForm(profile);
      final summary = await widget.ratingsService.getDriverSummary(profile.userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _driverRatingSummary = summary;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao carregar estado da subscrição: $error';
      });
    }
  }

  Future<void> _loadClientRatings() async {
    if (!_isClient || !_isAuthenticated) {
      return;
    }

    try {
      final ratings = await widget.ratingsService.listMyGivenRatings();
      if (!mounted) {
        return;
      }

      setState(() {
        _ratingsByRideId = {
          for (final rating in ratings) rating.rideId: rating,
        };
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

  Future<void> _openRatingDialog(Ride ride) async {
    if (!_isClient) {
      return;
    }

    final existing = _ratingsByRideId[ride.id];
    var selectedStars = existing?.stars ?? 5;

    final stars = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Avaliar taxista'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1 = insatisfeito | 5 = super satisfeito'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (index) {
                      final starsValue = index + 1;
                      return ChoiceChip(
                        label: Text('$starsValue ★'),
                        selected: selectedStars == starsValue,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedStars = starsValue;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(_getSatisfactionLabel(selectedStars)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedStars),
                  child: const Text('Enviar'),
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

    await _submitRideRating(rideId: ride.id, stars: stars);
  }

  Future<void> _submitRideRating({
    required String rideId,
    required int stars,
  }) async {
    setState(() {
      _isSubmittingRating = true;
      _errorMessage = null;
    });

    try {
      final rating = await widget.ratingsService.submitDriverRating(
        rideId: rideId,
        stars: stars,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _ratingsByRideId = {
          ..._ratingsByRideId,
          rating.rideId: rating,
        };
      });
      _showMessage('Avaliação enviada: ${rating.stars}★ (${rating.satisfactionLabel}).');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao enviar avaliação: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Future<void> _saveDriverRegistrationData() async {
    if (!_isDriver) {
      return;
    }

    final documentId = _documentIdController.text.trim();
    final documentExpiry = _documentExpiryController.text.trim();
    final neighborhood = _neighborhoodController.text.trim();
    final operatingRegion = _operatingRegionController.text.trim();

    if (documentId.isEmpty ||
        documentExpiry.isEmpty ||
        neighborhood.isEmpty ||
        operatingRegion.isEmpty) {
      _showMessage('Preencha todos os dados obrigatórios do taxista.');
      return;
    }

    setState(() {
      _isSavingDriverProfile = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.driversService.updateMyProfile(
        documentId: documentId,
        documentExpiry: documentExpiry,
        neighborhood: neighborhood,
        operatingRegion: operatingRegion,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _driverProfile = updated;
      });
      _showMessage('Dados do taxista atualizados.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao salvar cadastro do taxista: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDriverProfile = false;
        });
      }
    }
  }

  Future<void> _setDriverOnlineStatus({required bool goOnline}) async {
    if (!_isDriver) {
      return;
    }

    if (goOnline) {
      final blockReason = _driverOperationalBlockReason;
      if (blockReason != null) {
        _showMessage(blockReason);
        return;
      }
    }

    setState(() {
      _isUpdatingDriverStatus = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.driversService.updateMyStatus(
        status: goOnline ? 'online' : 'offline',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _driverProfile = updated;
      });

      _showMessage(goOnline ? 'Taxista ficou online.' : 'Taxista ficou offline.');
      await _loadDriverSubscriptionState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao atualizar estado online/offline: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDriverStatus = false;
        });
      }
    }
  }

  Future<void> _requestSubscriptionPayment() async {
    if (!_isDriver) {
      return;
    }

    final paymentReference = _paymentReferenceController.text.trim();
    if (paymentReference.isEmpty) {
      _showMessage('Informe a referência da transação M-Pesa/eMola.');
      return;
    }

    setState(() {
      _isSubmittingPayment = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.subscriptionService.requestPayment(
        plan: _selectedPlan,
        paymentMethod: _selectedPaymentMethod,
        paymentReference: paymentReference,
        paymentNotes: _paymentNotesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentSubscription = created;
        _subscriptionHistory = [created, ..._subscriptionHistory];
        _paymentReferenceController.clear();
        _paymentNotesController.clear();
      });

      _showMessage(
        'Pagamento registado. Aguarde até 30 minutos para validação manual dos agentes.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Falha ao registar pagamento: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingPayment = false;
        });
      }
    }
  }

  Future<void> _requestRide() async {
    if (!_isClient) {
      _showMessage('Apenas clientes podem solicitar corrida.');
      return;
    }

    if (!widget.hasLivePickup) {
      _showMessage('Ative o GPS para definir o pickup dinâmico.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ride = await widget.ridesService.requestRide(
        pickup: widget.pickup,
        dropoff: widget.dropoff,
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
      _showMessage('Não foi possível capturar o destino pelo GPS.');
      return;
    }

    _showMessage('Destino atualizado para ${_formatGeoPoint(point)}');
  }

  Future<void> _pickDropoffFromMap() async {
    final selected = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) => DropoffMapPickerPage(
          pickup: widget.pickup,
          initialDropoff: widget.dropoff,
        ),
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    widget.onSelectDropoffFromMap(selected);
    _showMessage('Destino definido no mapa: ${_formatGeoPoint(selected)}');
  }

  void _clearDropoff() {
    widget.onClearDropoff();
    _showMessage('Destino removido. A corrida fica sem dropoff definido.');
  }

  Future<void> _cancelActiveRide() async {
    if (!_isClient) {
      _showMessage('Apenas clientes podem cancelar corrida.');
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
      successMessage: 'Corrida aceite com sucesso.',
    );
  }

  Future<void> _rejectActiveRide() async {
    await _respondActiveRide(
      action: RideResponseAction.reject,
      successMessage: 'Corrida rejeitada.',
    );
  }

  Future<void> _startActiveRide() async {
    if (!_isDriver) {
      _showMessage('Apenas taxistas podem iniciar corridas.');
      return;
    }

    final blockReason = _driverOperationalBlockReason;
    if (blockReason != null) {
      _showMessage(blockReason);
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
      _showMessage('Apenas taxistas podem finalizar corridas.');
      return;
    }

    final blockReason = _driverOperationalBlockReason;
    if (blockReason != null) {
      _showMessage(blockReason);
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
    required String successMessage,
  }) async {
    if (!_isDriver) {
      _showMessage('Apenas taxistas podem responder corridas.');
      return;
    }

    final blockReason = _driverOperationalBlockReason;
    if (blockReason != null) {
      _showMessage(blockReason);
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
        action: action,
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncDriverProfileForm(DriverProfile profile) {
    _documentIdController.text = profile.documentId ?? '';
    _documentExpiryController.text = profile.documentExpiry ?? '';
    _neighborhoodController.text = profile.neighborhood ?? '';
    _operatingRegionController.text = profile.operatingRegion ?? '';
  }

  String _formatGeoPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final date = value.toLocal();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _getSatisfactionLabel(int stars) {
    return {
          1: 'Insatisfeito',
          2: 'Pouco satisfeito',
          3: 'Satisfeito',
          4: 'Muito satisfeito',
          5: 'Super satisfeito',
        }[stars] ??
        'Sem classificação';
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
              'Entre no separador Acesso para solicitar corridas e receber atualizações em tempo real.',
            ),
          ),
        ),
      );
    }

    final activeRide = _activeRide;
    final driverBlockReason = _driverOperationalBlockReason;
    final driverCanOperate = driverBlockReason == null;
    final canCancel =
        _isClient && activeRide != null && _canCancelRide(activeRide);
    final canRespond =
        _isDriver &&
        driverCanOperate &&
        activeRide != null &&
        _canDriverRespondRide(activeRide);
    final canStart =
        _isDriver &&
        driverCanOperate &&
        activeRide != null &&
        _canDriverStartRide(activeRide);
    final canComplete =
        _isDriver &&
        driverCanOperate &&
        activeRide != null &&
        _canDriverCompleteRide(activeRide);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Corrida'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMyRides,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar corridas',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (widget.locationWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.locationWarning!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guia rápido',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isClient
                        ? '1) Defina destino (opcional). 2) Solicite a corrida. 3) Acompanhe o estado em tempo real.'
                        : '1) Aguarde pedido atribuído. 2) Aceite ou rejeite. 3) Inicie e finalize quando estiver em curso.',
                  ),
                ],
              ),
            ),
          ),
          if (_isDriver) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cadastro do mototaxista',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _driverProfile == null
                          ? 'Carregando cadastro...'
                          : (_driverProfile!.isProfileComplete
                              ? 'Cadastro completo.'
                              : 'Cadastro incompleto. Preencha os dados abaixo.'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estado operacional: ${_isDriverOnline ? 'online' : 'offline'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed:
                              (_isUpdatingDriverStatus || _isDriverOnline)
                              ? null
                              : () => _setDriverOnlineStatus(goOnline: true),
                          icon: const Icon(Icons.wifi_tethering),
                          label: Text(
                            _isUpdatingDriverStatus
                                ? 'Atualizando...'
                                : 'Ficar online',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              (_isUpdatingDriverStatus || !_isDriverOnline)
                              ? null
                              : () => _setDriverOnlineStatus(goOnline: false),
                          icon: const Icon(Icons.wifi_off),
                          label: const Text('Ficar offline'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _documentIdController,
                      decoration: const InputDecoration(
                        labelText: 'Documento',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _documentExpiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Validade do documento (AAAA-MM-DD)',
                        prefixIcon: Icon(Icons.event_available),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro / residência',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _operatingRegionController,
                      decoration: const InputDecoration(
                        labelText: 'Região de atuação',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonal(
                          onPressed:
                              _isSavingDriverProfile ? null : _saveDriverRegistrationData,
                          child: Text(
                            _isSavingDriverProfile
                                ? 'Salvando...'
                                : 'Salvar cadastro',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _isLoading ? null : _loadDriverSubscriptionState,
                          child: const Text('Atualizar estado'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscrição do mototaxista',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentSubscription == null
                          ? 'Sem subscrição ativa no momento.'
                          : 'Estado: ${_currentSubscription!.status} · ${_currentSubscription!.usageLabel}',
                    ),
                    if (_driverRatingSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Avaliação média: ${_driverRatingSummary!.averageStars.toStringAsFixed(1)}★ (${_driverRatingSummary!.totalRatings} avaliações)',
                      ),
                    ],
                    if (_currentSubscription != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Pagamento: ${_currentSubscription!.paymentMethod.toUpperCase()} · Ref: ${_currentSubscription!.paymentReference}',
                      ),
                      Text(
                        'Disponível para validação: ${_formatDateTime(_currentSubscription!.validationAvailableAt)}',
                      ),
                      Text(
                        'Início: ${_formatDateTime(_currentSubscription!.startsAt)} · Fim: ${_formatDateTime(_currentSubscription!.endsAt)}',
                      ),
                    ],
                    if (driverBlockReason != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        driverBlockReason,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Escolha o plano',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'monthly',
                          label: Text('Mensal'),
                        ),
                        ButtonSegment(
                          value: 'quarterly',
                          label: Text('Trimestral'),
                        ),
                        ButtonSegment(
                          value: 'semiannual',
                          label: Text('Semestral'),
                        ),
                        ButtonSegment(value: 'annual', label: Text('Anual')),
                      ],
                      selected: {_selectedPlan},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedPlan = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Método de pagamento',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'mpesa', label: Text('M-Pesa')),
                        ButtonSegment(value: 'emola', label: Text('eMola')),
                      ],
                      selected: {_selectedPaymentMethod},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedPaymentMethod = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paymentReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'Referência da transação',
                        helperText:
                            'Após pagar via M-Pesa/eMola, informe a referência.',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _paymentNotesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observações do pagamento (opcional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          _isSubmittingPayment ? null : _requestSubscriptionPayment,
                      child: Text(
                        _isSubmittingPayment
                            ? 'Registrando pagamento...'
                            : 'Registrar pagamento e aguardar validação',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Após o pagamento, a validação manual dos agentes ocorre em até 30 minutos.',
                    ),
                    if (_subscriptionHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Últimas subscrições',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ..._subscriptionHistory.take(3).map(
                        (item) => Text(
                          '- ${item.usageLabel}: ${item.status} (fim: ${_formatDateTime(item.endsAt)})',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Localização da corrida',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hasLivePickup
                        ? 'Pickup atual: ${_formatGeoPoint(widget.pickup)}'
                        : 'Pickup atual: aguardando GPS real',
                  ),
                  Text(
                    widget.dropoff == null
                        ? 'Dropoff: não definido'
                        : 'Dropoff: ${_formatGeoPoint(widget.dropoff!)}',
                  ),
                  if (_isClient) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _pickDropoffFromMap,
                          icon: const Icon(Icons.pin_drop),
                          label: const Text('Selecionar no mapa'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _captureDropoffFromGps,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Capturar dropoff por GPS'),
                        ),
                        if (widget.dropoff != null)
                          OutlinedButton(
                            onPressed: _isLoading ? null : _clearDropoff,
                            child: const Text('Limpar dropoff'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (activeRide == null)
                    const Text('Nenhuma corrida ativa no momento.'),
                  if (activeRide != null) ...[
                    Text('ID: ${activeRide.id}'),
                    Text('Status: ${activeRide.status}'),
                    Text(
                      'Motorista: ${activeRide.driverId ?? 'aguardando atribuição'}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_isClient)
                        FilledButton(
                          onPressed: _isLoading ? null : _requestRide,
                          child: const Text('Solicitar corrida'),
                        ),
                      if (!_isClient)
                        Text(
                          driverBlockReason == null
                              ? 'Conta de taxista: acompanhe atualizações de corrida em tempo real.'
                              : 'Conta de taxista bloqueada: $driverBlockReason',
                        ),
                      if (canRespond)
                        FilledButton.tonal(
                          onPressed: _isLoading ? null : _acceptActiveRide,
                          child: const Text('Aceitar corrida'),
                        ),
                      if (canRespond)
                        OutlinedButton(
                          onPressed: _isLoading ? null : _rejectActiveRide,
                          child: const Text('Rejeitar corrida'),
                        ),
                      if (canStart)
                        FilledButton.tonal(
                          onPressed: _isLoading ? null : _startActiveRide,
                          child: const Text('Iniciar corrida'),
                        ),
                      if (canComplete)
                        FilledButton(
                          onPressed: _isLoading ? null : _completeActiveRide,
                          child: const Text('Finalizar corrida'),
                        ),
                      if (canCancel)
                        OutlinedButton(
                          onPressed: _isLoading ? null : _cancelActiveRide,
                          child: const Text('Cancelar corrida'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Histórico recente',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_rides.isEmpty)
            const Text('Sem corridas registadas para esta sessão.')
          else
            ..._rides.take(10).map((ride) {
              final isCompleted = ride.status.toLowerCase() == 'completed';
              final currentRating = _ratingsByRideId[ride.id];
              final canRate = _isClient && isCompleted && ride.driverId != null;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Corrida ${ride.id}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('Status: ${ride.status}'),
                      Text(
                        ride.driverId == null
                            ? 'Sem motorista atribuído'
                            : 'Motorista: ${ride.driverId}',
                      ),
                      if (canRate) ...[
                        const SizedBox(height: 8),
                        if (currentRating == null)
                          FilledButton.tonal(
                            onPressed: _isSubmittingRating
                                ? null
                                : () => _openRatingDialog(ride),
                            child: const Text('Avaliar taxista (1 a 5 estrelas)'),
                          ),
                        if (currentRating != null)
                          Text(
                            'Avaliação enviada: ${currentRating.stars}★ (${currentRating.satisfactionLabel})',
                          ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
