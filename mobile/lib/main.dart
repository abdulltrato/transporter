import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/map/presentation/map_page.dart';
import 'features/ride/presentation/ride_page.dart';
import 'models/driver.dart';
import 'models/geo_point.dart';

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
  int _selectedIndex = 0;

  static final List<Driver> _demoDrivers = [
    Driver(
      userId: '1',
      name: 'Carlos J.',
      distanceKm: 1.1,
      location: const GeoPoint(lat: -25.9653, lng: 32.5892),
      isOnline: true
    ),
    Driver(
      userId: '2',
      name: 'Amina C.',
      distanceKm: 1.8,
      location: const GeoPoint(lat: -25.9698, lng: 32.5732),
      isOnline: true
    )
  ];

  Future<void> _handleLogin({
    required String fullName,
    required String phone,
    required String code,
    required String role
  }) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login MVP para $fullName ($role) em progresso.'))
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LoginPage(onSubmit: _handleLogin),
      const MapPage(nearbyDrivers: _demoDrivers),
      const RidePage(activeRideStatus: null)
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
}
