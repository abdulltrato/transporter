import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onSubmit,
    required this.isRobustModeEnabled,
    required this.nativeModeSummary,
    required this.onRobustModeChanged,
  });

  final Future<void> Function({
    required String fullName,
    required String phone,
    required String code,
    required String role,
  })
  onSubmit;
  final bool isRobustModeEnabled;
  final String nativeModeSummary;
  final ValueChanged<bool> onRobustModeChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _role = 'client';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        role: _role,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrar no Transporter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acesso rápido',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preencha os dados abaixo para entrar como cliente ou taxista.',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estado atual: ${widget.nativeModeSummary}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Telefone (+258...)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código OTP (opcional em dev)',
              helperText:
                  'Pode deixar vazio para usar o código de desenvolvimento.',
              prefixIcon: Icon(Icons.lock_clock_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tipo de conta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'client', label: Text('Cliente')),
                      ButtonSegment(value: 'driver', label: Text('Taxista')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _role = selection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              value: widget.isRobustModeEnabled,
              onChanged: _isLoading ? null : widget.onRobustModeChanged,
              title: const Text('Modo nativo robusto'),
              subtitle: const Text(
                'Ativa retentativas automáticas e fila de sincronização de localização.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: const Icon(Icons.login),
            label: Text(_isLoading ? 'Aguarde...' : 'Entrar'),
          ),
        ],
      ),
    );
  }
}
