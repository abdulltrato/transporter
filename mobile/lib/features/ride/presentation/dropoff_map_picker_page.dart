import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/geo_point.dart';

class DropoffMapPickerPage extends StatefulWidget {
  const DropoffMapPickerPage(
      {super.key, required this.pickup, this.initialDropoff});

  final GeoPoint pickup;
  final GeoPoint? initialDropoff;

  @override
  State<DropoffMapPickerPage> createState() => _DropoffMapPickerPageState();
}

class _DropoffMapPickerPageState extends State<DropoffMapPickerPage> {
  late final MapController _mapController;
  GeoPoint? _selectedDropoff;
  late GeoPoint _mapCenter;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedDropoff = widget.initialDropoff;
    _mapCenter = widget.initialDropoff ?? widget.pickup;
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup;
    final selectedDropoff = _selectedDropoff;
    final mapCenter = _mapCenter;
    final initialCenter = selectedDropoff ?? pickup;

    return Scaffold(
        appBar: AppBar(title: const Text('Selecionar dropoff no mapa')),
        body: Column(children: [
          Expanded(
              child: Stack(children: [
            FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                    initialCenter: LatLng(initialCenter.lat, initialCenter.lng),
                    initialZoom: 16,
                    onTap: (_, point) {
                      setState(() {
                        _selectedDropoff =
                            GeoPoint(lat: point.latitude, lng: point.longitude);
                      });
                    },
                    onPositionChanged: (camera, hasGesture) {
                      if (!hasGesture) {
                        return;
                      }

                      setState(() {
                        _mapCenter = GeoPoint(
                            lat: camera.center.latitude,
                            lng: camera.center.longitude);
                      });
                    }),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'transporter.mobile'),
                  MarkerLayer(markers: [
                    Marker(
                        point: LatLng(pickup.lat, pickup.lng),
                        width: 56,
                        height: 56,
                        child: const Icon(Icons.my_location,
                            color: Colors.blue, size: 34)),
                    if (selectedDropoff != null)
                      Marker(
                          point:
                              LatLng(selectedDropoff.lat, selectedDropoff.lng),
                          width: 56,
                          height: 56,
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 38))
                  ])
                ]),
            const IgnorePointer(
                child: Center(
                    child: Icon(Icons.add_location_alt,
                        color: Colors.deepOrange, size: 42))),
            Positioned(
                top: 12,
                right: 12,
                child: FilledButton.tonalIcon(
                    onPressed: () {
                      _mapController.move(LatLng(pickup.lat, pickup.lng), 17);
                      setState(() {
                        _mapCenter = pickup;
                      });
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ir ao pickup')))
          ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Pickup: ${_formatPoint(pickup)}'),
                    const SizedBox(height: 6),
                    Text(selectedDropoff == null
                        ? 'Toque no mapa ou use o centro para marcar o dropoff.'
                        : 'Dropoff selecionado: ${_formatPoint(selectedDropoff)}'),
                    const SizedBox(height: 6),
                    Text('Centro atual do mapa: ${_formatPoint(mapCenter)}'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedDropoff = mapCenter;
                          });
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Usar centro do mapa')),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: selectedDropoff == null
                            ? null
                            : () {
                                Navigator.of(context).pop(selectedDropoff);
                              },
                        child: const Text('Confirmar dropoff'))
                  ]))
        ]));
  }

  String _formatPoint(GeoPoint point) {
    return '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}';
  }
}
