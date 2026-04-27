import 'package:flutter/material.dart';
import '../../../models/driver_subscription.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onSubmit,
    required this.onSocialAuth,
    required this.onLoadPendingSubscriptionsForAgent,
    required this.onValidateSubscriptionForAgent,
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
    required String code,
    required String role,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  })
  onSubmit;
  final Future<void> Function({
    required String provider,
    required String role,
    required String fullName,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  })
  onSocialAuth;
  final Future<List<DriverSubscription>> Function({
    required String agentKey,
  })
  onLoadPendingSubscriptionsForAgent;
  final Future<DriverSubscription> Function({
    required String agentKey,
    required String subscriptionId,
    required String action,
    required String agentName,
    String? notes,
  })
  onValidateSubscriptionForAgent;
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
  final _codeController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _documentExpiryController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _operatingRegionController = TextEditingController();
  final _agentKeyController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _agentNotesController = TextEditingController();
  String _role = 'client';
  bool _isLoading = false;
  bool _isAgentLoading = false;
  bool _isValidatingSubscription = false;
  List<DriverSubscription> _pendingSubscriptions = [];
  String? _agentError;

  bool get _isDriver => _role == 'driver';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _documentIdController.dispose();
    _documentExpiryController.dispose();
    _neighborhoodController.dispose();
    _operatingRegionController.dispose();
    _agentKeyController.dispose();
    _agentNameController.dispose();
    _agentNotesController.dispose();
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

  Future<void> _submitSocial(String provider) async {
    setState(() => _isLoading = true);
    try {
      await widget.onSocialAuth(
        provider: provider,
        role: _role,
        fullName: _nameController.text.trim(),
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

  Future<void> _refreshPendingSubscriptions() async {
    final agentKey = _agentKeyController.text.trim();
    if (agentKey.isEmpty) {
      _showMessage('Informe a chave do agente.');
      return;
    }

    setState(() {
      _isAgentLoading = true;
      _agentError = null;
    });

    try {
      final items = await widget.onLoadPendingSubscriptionsForAgent(
        agentKey: agentKey,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingSubscriptions = items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _agentError = 'Falha ao carregar pendências: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAgentLoading = false;
        });
      }
    }
  }

  Future<void> _validatePendingSubscription({
    required DriverSubscription subscription,
    required String action,
  }) async {
    final agentKey = _agentKeyController.text.trim();
    final agentName = _agentNameController.text.trim();

    if (agentKey.isEmpty) {
      _showMessage('Informe a chave do agente.');
      return;
    }

    if (agentName.isEmpty) {
      _showMessage('Informe o nome do agente.');
      return;
    }

    setState(() {
      _isValidatingSubscription = true;
      _agentError = null;
    });

    try {
      await widget.onValidateSubscriptionForAgent(
        agentKey: agentKey,
        subscriptionId: subscription.id,
        action: action,
        agentName: agentName,
        notes: _agentNotesController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingSubscriptions = _pendingSubscriptions
            .where((item) => item.id != subscription.id)
            .toList();
      });

      final actionLabel = action == 'approve' ? 'aprovado' : 'rejeitado';
      _showMessage('Pagamento $actionLabel com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _agentError = 'Falha ao validar pagamento: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingSubscription = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          if (widget.isAuthenticated) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sessão ativa',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Perfil atual: ${(widget.currentRole ?? 'desconhecido').toLowerCase()}',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _logoutSession,
                      icon: const Icon(Icons.logout),
                      label: const Text('Terminar sessão'),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          if (_isDriver) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _documentIdController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Documento do taxista',
                helperText: 'Obrigatório no cadastro do mototaxista.',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _documentExpiryController,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Validade do documento (AAAA-MM-DD)',
                prefixIcon: Icon(Icons.event_available),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _neighborhoodController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Bairro / residência',
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _operatingRegionController,
              decoration: const InputDecoration(
                labelText: 'Região de atuação',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
          ],
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
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login / Sign up social',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use sua conta Google ou Facebook para entrar ou criar conta.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : () => _submitSocial('google'),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continuar com Google'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : () => _submitSocial('facebook'),
                    icon: const Icon(Icons.facebook),
                    label: const Text('Continuar com Facebook'),
                  ),
                ],
              ),
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
                    'Painel de Agente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Validação manual dos pagamentos de subscrição (M-Pesa/eMola).',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _agentKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Chave do agente (x-agent-key)',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _agentNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do agente',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _agentNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas da validação (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: (_isAgentLoading || _isValidatingSubscription)
                        ? null
                        : _refreshPendingSubscriptions,
                    icon: const Icon(Icons.sync),
                    label: Text(
                      _isAgentLoading
                          ? 'Carregando pendências...'
                          : 'Carregar pagamentos pendentes',
                    ),
                  ),
                  if (_agentError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _agentError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_pendingSubscriptions.isEmpty)
                    const Text('Sem pagamentos pendentes no momento.')
                  else
                    ..._pendingSubscriptions.map((item) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver: ${item.driverId}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text('Plano: ${item.usageLabel}'),
                              Text(
                                'Pagamento: ${item.paymentMethod.toUpperCase()} · Ref: ${item.paymentReference}',
                              ),
                              Text(
                                'Disponível para validar: ${_formatDateTime(item.validationAvailableAt)}',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: _isValidatingSubscription
                                        ? null
                                        : () => _validatePendingSubscription(
                                              subscription: item,
                                              action: 'approve',
                                            ),
                                    child: const Text('Aprovar'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isValidatingSubscription
                                        ? null
                                        : () => _validatePendingSubscription(
                                              subscription: item,
                                              action: 'reject',
                                            ),
                                    child: const Text('Rejeitar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
