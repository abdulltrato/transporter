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
      home: const _HomeShell()
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  static const _defaultOrigin = GeoPoint(lat: -25.9653, lng: 32.5892);
  static const _defaultRadiusKm = 5.0;

  int _selectedIndex = 0;
  String? _accessToken;
  String? _currentRole;
  GeoPoint? _currentLocation;
  GeoPoint? _dropoffLocation;
  String? _locationWarning;
  StreamSubscription<GeoPoint>? _locationSubscription;
  bool _isSyncingLocation = false;
  GeoPoint? _pendingLocationSync;

  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final DeviceLocationService _deviceLocationService;
  late final LocationService _locationService;
  late final RealtimeMapService _realtimeMapService;
  late final RidesService _ridesService;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(baseUrl: _resolveApiBaseUrl());
    _authService = AuthService(_apiClient);
    _deviceLocationService = const DeviceLocationService();
    _locationService = LocationService(_apiClient);
    _realtimeMapService = RealtimeMapService(baseUrl: _apiClient.baseUrl);
    _ridesService = RidesService(_apiClient);
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _realtimeMapService.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({
    required String fullName,
    required String phone,
    required String code,
    required String role
  }) async {
    final sanitizedName = fullName.trim();
    final sanitizedPhone = phone.trim();
    final sanitizedCode = code.trim();

    if (sanitizedPhone.isEmpty) {
      _showMessage('Informe um telefone valido.');
      return;
    }

    if (sanitizedName.isEmpty) {
      _showMessage('Informe seu nome completo.');
      return;
    }

    try {
      final devCode = await _authService.requestOtp(sanitizedPhone);
      final verificationCode = sanitizedCode.isEmpty ? devCode : sanitizedCode;
      final accessToken = await _authService.verifyOtp(
        phone: sanitizedPhone,
        code: verificationCode,
        role: role,
        fullName: sanitizedName
      );

      _apiClient.token = accessToken;
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
        unawaited(_syncMyLocation(currentLocation));
      }

      final otpHint = sanitizedCode.isEmpty
          ? 'Dev OTP usado automaticamente.'
          : 'OTP informado manualmente.';

      _showMessage('Sessao iniciada como $role. $otpHint');
    } catch (error) {
      _showMessage('Falha no login: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = _currentLocation ?? _defaultOrigin;

    final pages = [
      LoginPage(onSubmit: _handleLogin),
      MapPage(
        locationService: _locationService,
        realtimeMapService: _realtimeMapService,
        origin: origin,
        radiusKm: _defaultRadiusKm,
        token: _accessToken
      ),
      RidePage(
        ridesService: _ridesService,
        realtimeMapService: _realtimeMapService,
        pickup: origin,
        hasLivePickup: _currentLocation != null,
        dropoff: _dropoffLocation,
        onCaptureDropoffFromGps: _captureDropoffFromGps,
        onClearDropoff: _clearDropoff,
        locationWarning: _locationWarning,
        token: _accessToken,
        role: _currentRole
      )
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lock_open), label: 'Acesso'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.directions_bike), label: 'Corrida')
        ],
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
          });
        }
      )
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
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
      unawaited(_syncMyLocation(initialPosition));
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

        unawaited(_syncMyLocation(point));
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationWarning = 'Falha ao ler GPS: $error';
        });
      }
    );
  }

  Future<void> _syncMyLocation(GeoPoint point) async {
    final token = (_accessToken ?? '').trim();
    if (token.isEmpty) {
      return;
    }

    if (_isSyncingLocation) {
      _pendingLocationSync = point;
      return;
    }

    _isSyncingLocation = true;
    try {
      await _locationService.updateMyLocation(point);
    } catch (_) {
      // Mantem o app resiliente caso o backend esteja indisponivel.
    } finally {
      _isSyncingLocation = false;
      final pending = _pendingLocationSync;
      _pendingLocationSync = null;
      if (pending != null) {
        unawaited(_syncMyLocation(pending));
      }
    }
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

    unawaited(_syncMyLocation(position));
    return position;
  }

  void _clearDropoff() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dropoffLocation = null;
    });
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
