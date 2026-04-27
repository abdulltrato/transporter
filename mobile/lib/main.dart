import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/map/presentation/map_page.dart';
import 'features/ride/presentation/ride_page.dart';
import 'models/geo_point.dart';
import 'models/driver_subscription.dart';
import 'services/agent_subscriptions_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/device_location_service.dart';
import 'services/drivers_service.dart';
import 'services/location_service.dart';
import 'services/native_runtime_service.dart';
import 'services/ratings_service.dart';
import 'services/realtime_map_service.dart';
import 'services/rides_service.dart';
import 'services/session_storage_service.dart';
import 'services/social_auth_service.dart';
import 'services/subscription_service.dart';

void main() {
  runApp(const TransporterApp());
}

class TransporterApp extends StatelessWidget {
  const TransporterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transporter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> with WidgetsBindingObserver {
  static const _defaultOrigin = GeoPoint(lat: -25.9653, lng: 32.5892);
  static const _defaultRadiusKm = 5.0;
  static const _guestRole = 'client';
  static const _authBypassRaw = String.fromEnvironment(
    'TRANSPORTER_AUTH_BYPASS',
    defaultValue: 'true',
  );
  static final _isAuthBypassEnabled = !_isBypassDisabled(_authBypassRaw);

  int _selectedIndex = 1;
  String? _accessToken;
  String? _currentRole;
  GeoPoint? _currentLocation;
  GeoPoint? _dropoffLocation;
  String? _locationWarning;
  StreamSubscription<GeoPoint>? _locationSubscription;
  StreamSubscription<NativeRuntimeSnapshot>? _nativeSnapshotSubscription;
  NativeRuntimeSnapshot _nativeSnapshot = NativeRuntimeSnapshot.initial();

  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final AgentSubscriptionsService _agentSubscriptionsService;
  late final SessionStorageService _sessionStorageService;
  late final SocialAuthService _socialAuthService;
  late final DriversService _driversService;
  late final SubscriptionService _subscriptionService;
  late final RatingsService _ratingsService;
  late final DeviceLocationService _deviceLocationService;
  late final LocationService _locationService;
  late final NativeRuntimeService _nativeRuntimeService;
  late final RealtimeMapService _realtimeMapService;
  late final RidesService _ridesService;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(baseUrl: _resolveApiBaseUrl());
    _authService = AuthService(_apiClient);
    _agentSubscriptionsService = AgentSubscriptionsService(_apiClient);
    _sessionStorageService = SessionStorageService();
    _socialAuthService = SocialAuthService();
    _driversService = DriversService(_apiClient);
    _subscriptionService = SubscriptionService(_apiClient);
    _ratingsService = RatingsService(_apiClient);
    _deviceLocationService = const DeviceLocationService();
    _locationService = LocationService(_apiClient);
    _nativeRuntimeService = NativeRuntimeService(
      mode: NativeRuntimeMode.robust,
    );
    _nativeSnapshotSubscription = _nativeRuntimeService.snapshotStream.listen(
      _handleNativeSnapshot,
    );
    _realtimeMapService = RealtimeMapService(baseUrl: _apiClient.baseUrl);
    _ridesService = RidesService(_apiClient);

    WidgetsBinding.instance.addObserver(this);
    _nativeRuntimeService.updateForegroundState(true);
    unawaited(_enterGuestMode());
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _nativeSnapshotSubscription?.cancel();
    _nativeRuntimeService.dispose();
    _realtimeMapService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _nativeRuntimeService.updateForegroundState(_isForegroundState(state));
  }

  Future<void> _enterGuestMode() async {
    if (_isAuthBypassEnabled) {
      await _activateSession(
        accessToken: _buildBypassToken(_guestRole),
        role: _guestRole,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _accessToken = null;
      _currentRole = _guestRole;
      _selectedIndex = 1;
    });
  }

  Future<void> _handleLogin({
    required String fullName,
    required String phone,
    required String code,
    required String role,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) async {
    final resolvedRole = _normalizeRole(role);
    if (_isAuthBypassEnabled) {
      await _activateSession(
        accessToken: _buildBypassToken(resolvedRole),
        role: resolvedRole,
      );
      _showMessage('Modo de teste ativo: sessão local como $resolvedRole.');
      return;
    }

    final sanitizedName = fullName.trim();
    final sanitizedPhone = phone.trim();
    final sanitizedCode = code.trim();

    if (sanitizedPhone.isEmpty) {
      _showMessage('Indique um telefone válido.');
      return;
    }

    if (sanitizedName.isEmpty) {
      _showMessage('Indique o seu nome completo.');
      return;
    }

    try {
      if (sanitizedCode.isEmpty) {
        final devCode = await _authService.requestOtp(sanitizedPhone);
        final codeHint =
            devCode.isNotEmpty ? ' Código de desenvolvimento: $devCode' : '';
        _showMessage(
          'Pedido de login/cadastro enviado. Introduza o OTP para concluir.$codeHint',
        );
        return;
      }

      final accessToken = await _authService.verifyOtp(
        phone: sanitizedPhone,
        code: sanitizedCode,
        role: resolvedRole,
        fullName: sanitizedName,
        documentId: documentId,
        documentExpiry: documentExpiry,
        neighborhood: neighborhood,
        operatingRegion: operatingRegion,
      );

      if (accessToken.isEmpty) {
        _showMessage('Falha no login: token de sessão inválido.');
        return;
      }

      await _activateSession(accessToken: accessToken, role: resolvedRole);
      _showMessage('Sessão iniciada como $resolvedRole.');
    } catch (error) {
      _showMessage('Falha no login: $error');
    }
  }

  Future<void> _handleSocialAuth({
    required String provider,
    required String role,
    required String fullName,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) async {
    final resolvedRole = _normalizeRole(role);
    if (_isAuthBypassEnabled) {
      await _activateSession(
        accessToken: _buildBypassToken(resolvedRole),
        role: resolvedRole,
      );
      _showMessage('Modo de teste ativo: sessão local como $resolvedRole.');
      return;
    }

    try {
      final profile = switch (provider) {
        'google' => await _socialAuthService.signInWithGoogle(),
        'facebook' => await _socialAuthService.signInWithFacebook(),
        _ => throw Exception('Provedor social não suportado.'),
      };

      if (profile == null) {
        _showMessage('Login social cancelado.');
        return;
      }

      final resolvedName = profile.fullName.trim().isNotEmpty
          ? profile.fullName.trim()
          : fullName.trim();

      if (resolvedName.isEmpty) {
        _showMessage(
          'Não foi possível identificar seu nome. Preencha o nome completo e tente novamente.',
        );
        return;
      }

      final accessToken = await _authService.socialLogin(
        provider: provider,
        providerUserId: profile.providerUserId,
        role: resolvedRole,
        fullName: resolvedName,
        documentId: documentId,
        documentExpiry: documentExpiry,
        neighborhood: neighborhood,
        operatingRegion: operatingRegion,
      );

      if (accessToken.isEmpty) {
        _showMessage('Falha no login social: token de sessão inválido.');
        return;
      }

      await _activateSession(accessToken: accessToken, role: resolvedRole);
      final providerLabel = provider == 'google' ? 'Google' : 'Facebook';
      _showMessage('Sessão iniciada com $providerLabel como $resolvedRole.');
    } catch (error) {
      _showMessage('Falha no login social: $error');
    }
  }

  Future<void> _activateSession({
    required String accessToken,
    required String role,
  }) async {
    _apiClient.token = accessToken;
    _nativeRuntimeService.setSessionToken(accessToken);
    _realtimeMapService.connect(token: accessToken);

    if (!mounted) {
      return;
    }

    setState(() {
      _accessToken = accessToken;
      _currentRole = role;
      _selectedIndex = 1;
    });

    final currentLocation = _currentLocation;
    if (currentLocation != null) {
      _scheduleLocationSync(currentLocation);
    }

    await _sessionStorageService.saveSession(
      accessToken: accessToken,
      role: role,
    );
  }

  Future<void> _logout() async {
    _realtimeMapService.disconnect();
    _apiClient.token = null;
    _nativeRuntimeService.setSessionToken(null);
    await _sessionStorageService.clearSession();

    await _enterGuestMode();
    _showMessage('Modo de teste sem autenticação ativo.');
  }

  Future<List<DriverSubscription>> _loadPendingSubscriptionsForAgent({
    required String agentKey,
  }) {
    return _agentSubscriptionsService.listPending(agentKey: agentKey);
  }

  Future<DriverSubscription> _validateSubscriptionForAgent({
    required String agentKey,
    required String subscriptionId,
    required String action,
    required String agentName,
    String? notes,
  }) {
    return _agentSubscriptionsService.validate(
      agentKey: agentKey,
      subscriptionId: subscriptionId,
      action: action,
      agentName: agentName,
      notes: notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = _currentLocation ?? _defaultOrigin;
    final role = _currentRole ?? _guestRole;
    final token = _accessToken;

    final pages = [
      LoginPage(
        onSubmit: _handleLogin,
        onSocialAuth: _handleSocialAuth,
        onLoadPendingSubscriptionsForAgent: _loadPendingSubscriptionsForAgent,
        onValidateSubscriptionForAgent: _validateSubscriptionForAgent,
        isAuthBypassEnabled: _isAuthBypassEnabled,
        isAuthenticated: (_accessToken ?? '').trim().isNotEmpty,
        currentRole: _currentRole,
        onLogout: _logout,
        isRobustModeEnabled: _nativeRuntimeService.isRobustMode,
        nativeModeSummary: 'Modo de teste sem autenticação · ${_buildNativeModeSummary()}',
        onRobustModeChanged: _setNativeMode,
      ),
      MapPage(
        locationService: _locationService,
        realtimeMapService: _realtimeMapService,
        origin: origin,
        radiusKm: _defaultRadiusKm,
        token: token,
      ),
      RidePage(
        ridesService: _ridesService,
        realtimeMapService: _realtimeMapService,
        driversService: _driversService,
        subscriptionService: _subscriptionService,
        ratingsService: _ratingsService,
        pickup: origin,
        hasLivePickup: _currentLocation != null,
        dropoff: _dropoffLocation,
        onCaptureDropoffFromGps: _captureDropoffFromGps,
        onSelectDropoffFromMap: _setDropoffFromMap,
        onClearDropoff: _clearDropoff,
        locationWarning: _locationWarning,
        token: token,
        role: role,
        isAuthBypassEnabled: _isAuthBypassEnabled,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NativeModeStatusBar(snapshot: _nativeSnapshot),
          NavigationBar(
            selectedIndex: _selectedIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.lock_open),
                label: 'Acesso',
              ),
              NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
              NavigationDestination(
                icon: Icon(Icons.directions_bike),
                label: 'Corrida',
              ),
            ],
            onDestinationSelected: (value) {
              setState(() {
                _selectedIndex = value;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startLocationTracking() async {
    final access = await _deviceLocationService.ensureAccess();
    if (!mounted) {
      return;
    }

    if (!access.isGranted) {
      setState(() {
        _locationWarning = access.message;
      });
      return;
    }

    setState(() {
      _locationWarning = null;
    });

    final initialPosition = await _deviceLocationService.getCurrentPosition();
    if (!mounted) {
      return;
    }

    if (initialPosition != null) {
      setState(() {
        _currentLocation = initialPosition;
      });
      _scheduleLocationSync(initialPosition);
    }

    final previousSubscription = _locationSubscription;
    if (previousSubscription != null) {
      await previousSubscription.cancel();
    }
    _locationSubscription = _deviceLocationService.positionStream().listen(
      (point) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentLocation = point;
        });

        _scheduleLocationSync(point);
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationWarning = 'Falha ao ler o GPS: $error';
        });
      },
    );
  }

  void _scheduleLocationSync(GeoPoint point) {
    _nativeRuntimeService.scheduleLocationSync(
      point,
      sender: (nextPoint) async {
        await _locationService.updateMyLocation(nextPoint);
      },
    );
  }

  Future<GeoPoint?> _captureDropoffFromGps() async {
    final access = await _deviceLocationService.ensureAccess();
    if (!mounted) {
      return null;
    }

    if (!access.isGranted) {
      setState(() {
        _locationWarning = access.message;
      });
      return null;
    }

    final position = await _deviceLocationService.getCurrentPosition();
    if (!mounted || position == null) {
      return position;
    }

    setState(() {
      _dropoffLocation = position;
      _currentLocation = position;
      _locationWarning = null;
    });

    _scheduleLocationSync(position);
    return position;
  }

  void _setDropoffFromMap(GeoPoint point) {
    if (!mounted) {
      return;
    }

    setState(() {
      _dropoffLocation = point;
    });
  }

  void _clearDropoff() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dropoffLocation = null;
    });
  }

  void _setNativeMode(bool enabled) {
    _nativeRuntimeService.setMode(
      enabled ? NativeRuntimeMode.robust : NativeRuntimeMode.standard,
    );
  }

  void _handleNativeSnapshot(NativeRuntimeSnapshot snapshot) {
    if (!mounted) {
      return;
    }

    setState(() {
      _nativeSnapshot = snapshot;
    });
  }

  String _buildNativeModeSummary() {
    final snapshot = _nativeSnapshot;
    final retryInfo = snapshot.retryAttempt > 0
        ? ' · Tentativa ${snapshot.retryAttempt}'
        : '';
    return '${snapshot.modeLabel} · ${snapshot.stateLabel}$retryInfo';
  }

  bool _isForegroundState(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => true,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
  }

  String _resolveApiBaseUrl() {
    const envBaseUrl = String.fromEnvironment('TRANSPORTER_API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  String _buildBypassToken(String role) {
    return 'bypass-${_normalizeRole(role)}-token';
  }

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    return normalized == 'driver' ? 'driver' : 'client';
  }

  static bool _isBypassDisabled(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'off';
  }
}

class _NativeModeStatusBar extends StatelessWidget {
  const _NativeModeStatusBar({required this.snapshot});

  final NativeRuntimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (snapshot.state) {
      NativeSyncState.syncing => theme.colorScheme.primaryContainer,
      NativeSyncState.retrying => theme.colorScheme.secondaryContainer,
      NativeSyncState.paused => theme.colorScheme.surfaceContainerHighest,
      NativeSyncState.idle => theme.colorScheme.surface,
    };

    final retryInfo = snapshot.retryAttempt > 0
        ? ' · Tentativa ${snapshot.retryAttempt}'
        : '';
    final authInfo = snapshot.hasSessionToken ? '' : ' · Sem sessão';

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Modo ${snapshot.modeLabel} · ${snapshot.stateLabel}$retryInfo$authInfo',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
