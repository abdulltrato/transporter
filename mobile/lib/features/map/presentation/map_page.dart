import 'package:flutter/material.dart';
import '../../../models/driver.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.nearbyDrivers});

  final List<Driver> nearbyDrivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taxistas proximos')),
      body: nearbyDrivers.isEmpty
          ? const Center(child: Text('Nenhum taxista online no raio atual.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: nearbyDrivers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final driver = nearbyDrivers[index];
                return Card(
                  child: ListTile(
                    title: Text(driver.name),
                    subtitle: Text('${driver.distanceKm.toStringAsFixed(1)} km de distancia'),
                    trailing: driver.isOnline
                        ? const Chip(label: Text('Online'))
                        : const Chip(label: Text('Offline'))
                  )
                );
              }
            )
    );
  }
}
