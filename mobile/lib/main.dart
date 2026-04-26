import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/map/presentation/map_page.dart';
import 'features/ride/presentation/ride_page.dart';
import 'models/geo_point.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/device_location_service.dart';
import 'services/location_service.dart';
import 'services/native_runtime_service.dart';
import 'services/realtime_map_service.dart';
import 'services/rides_service.dart';

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

  int _selectedIndex = 0;
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

  Future<void> _handleLogin({
    required String fullName,
    required String phone,
    required String code,
    required String role,
  }) async {
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
      final devCode = await _authService.requestOtp(sanitizedPhone);
      final verificationCode = sanitizedCode.isEmpty ? devCode : sanitizedCode;
      final accessToken = await _authService.verifyOtp(
        phone: sanitizedPhone,
        code: verificationCode,
        role: role,
        fullName: sanitizedName,
      );

      if (accessToken.isEmpty) {
        _showMessage('Falha no login: token de sessão inválido.');
        return;
      }

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

      final otpHint = sanitizedCode.isEmpty
          ? 'OTP de desenvolvimento usado automaticamente.'
          : 'OTP introduzido manualmente.';

      _showMessage('Sessão iniciada como $role. $otpHint');
    } catch (error) {
      _showMessage('Falha no login: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = _currentLocation ?? _defaultOrigin;

    final pages = [
      LoginPage(
        onSubmit: _handleLogin,
        isRobustModeEnabled: _nativeRuntimeService.isRobustMode,
        nativeModeSummary: _buildNativeModeSummary(),
        onRobustModeChanged: _setNativeMode,
      ),
      MapPage(
        locationService: _locationService,
        realtimeMapService: _realtimeMapService,
        origin: origin,
        radiusKm: _defaultRadiusKm,
        token: _accessToken,
      ),
      RidePage(
        ridesService: _ridesService,
        realtimeMapService: _realtimeMapService,
        pickup: origin,
        hasLivePickup: _currentLocation != null,
        dropoff: _dropoffLocation,
        onCaptureDropoffFromGps: _captureDropoffFromGps,
        onSelectDropoffFromMap: _setDropoffFromMap,
        onClearDropoff: _clearDropoff,
        locationWarning: _locationWarning,
        token: _accessToken,
        role: _currentRole,
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
