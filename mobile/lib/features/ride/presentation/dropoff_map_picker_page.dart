import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/geo_point.dart';

class DropoffMapPickerPage extends StatefulWidget {
  const DropoffMapPickerPage({
    super.key,
    required this.pickup,
    this.initialDropoff
  });

  final GeoPoint pickup;
  final GeoPoint? initialDropoff;

  @override
  State<DropoffMapPickerPage> createState() => _DropoffMapPickerPageState();
}

class _DropoffMapPickerPageState extends State<DropoffMapPickerPage> {
  GeoPoint? _selectedDropoff;

  @override
  void initState() {
    super.initState();
    _selectedDropoff = widget.initialDropoff;
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup;
    final selectedDropoff = _selectedDropoff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar dropoff no mapa')
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(pickup.lat, pickup.lng),
                initialZoom: 15,
                onTap: (_, point) {
                  setState(() {
                    _selectedDropoff = GeoPoint(lat: point.latitude, lng: point.longitude);
                  });
                }
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'transporter.mobile'
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(pickup.lat, pickup.lng),
                    width: 56,
                    height: 56,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 34
                    )
                  ),
                  if (selectedDropoff != null)
                    Marker(
                      point: LatLng(selectedDropoff.lat, selectedDropoff.lng),
                      width: 56,
                      height: 56,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 38
                      )
                    )
                ])
              ]
            )
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pickup: ${_formatPoint(pickup)}'),
                const SizedBox(height: 6),
                Text(
                  selectedDropoff == null
                      ? 'Toque no mapa para marcar o dropoff.'
                      : 'Dropoff selecionado: ${_formatPoint(selectedDropoff)}'
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: selectedDropoff == null
                      ? null
                      : () {
                          Navigator.of(context).pop(selectedDropoff);
                        },
                  child: const Text('Confirmar dropoff')
                )
              ]
            )
          )
        ]
      )
    );
  }

  String _formatPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}';
  }
}
