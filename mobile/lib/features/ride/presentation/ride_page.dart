import 'package:flutter/material.dart';

class RidePage extends StatelessWidget {
  const RidePage({super.key, this.activeRideStatus});

  final String? activeRideStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corrida')),
      body: Center(
        child: activeRideStatus == null
            ? FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fluxo de solicitacao conectado ao backend'))
                  );
                },
                child: const Text('Solicitar corrida')
              )
            : Text('Status atual: $activeRideStatus')
      )
    );
  }
}
