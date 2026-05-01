import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onRegister,
    required this.isAuthenticated,
    required this.currentRole,
    required this.onLogout,
    required this.isRobustModeEnabled,
    required this.nativeModeSummary,
    required this.onRobustModeChanged,
  });

  final Future<void> Function({
    required String fullName,
    required String phone,
    required String role,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) onRegister;
  final bool isAuthenticated;
  final String? currentRole;
  final Future<void> Function() onLogout;
  final bool isRobustModeEnabled;
  final String nativeModeSummary;
  final ValueChanged<bool> onRobustModeChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _documentExpiryController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _operatingRegionController = TextEditingController();

  String _role = 'client';
  bool _isLoading = false;

  bool get _isDriver => _role == 'driver';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _documentIdController.dispose();
    _documentExpiryController.dispose();
    _neighborhoodController.dispose();
    _operatingRegionController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      await widget.onRegister(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _role,
        documentId: _documentIdController.text.trim(),
        documentExpiry: _documentExpiryController.text.trim(),
        neighborhood: _neighborhoodController.text.trim(),
        operatingRegion: _operatingRegionController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logoutSession() async {
    setState(() => _isLoading = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRoleLabel = (widget.currentRole ?? '').toLowerCase() == 'driver'
        ? 'Taxista'
        : 'Cliente';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 84,
              height: 84,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cadastro simples',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sem OTP e sem pagamento. Registe cliente ou taxista e comece a operar.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (widget.isAuthenticated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sessão ativa como $currentRoleLabel.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _logoutSession,
                      icon: const Icon(Icons.logout),
                      label: Text(_isLoading ? 'A terminar sessão...' : 'Terminar sessão'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'client', label: Text('Cliente')),
              ButtonSegment(value: 'driver', label: Text('Taxista')),
            ],
            selected: {_role},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() {
                  _role = selection.first;
                });
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nome completo'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              hintText: '+25884xxxxxxx',
            ),
          ),
          if (_isDriver) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _documentIdController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Documento (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _documentExpiryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Validade do documento (AAAA-MM-DD)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _neighborhoodController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Bairro (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _operatingRegionController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Zona de operação (opcional)',
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isLoading ? null : _register,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              _isLoading
                  ? 'A registar...'
                  : (_role == 'driver'
                        ? 'Registar taxista'
                        : 'Registar cliente'),
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo nativo robusto'),
            subtitle: Text(widget.nativeModeSummary),
            value: widget.isRobustModeEnabled,
            onChanged: widget.onRobustModeChanged,
          ),
        ],
      ),
    );
  }
}
