class DriverSubscription {
  const DriverSubscription({
    required this.id,
    required this.driverId,
    required this.plan,
    required this.paymentMethod,
    required this.paymentReference,
    required this.status,
    required this.usageLabel,
    required this.validationAvailableAt,
    this.validatedAt,
    this.startsAt,
    this.endsAt,
    this.agentName,
    this.agentNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String driverId;
  final String plan;
  final String paymentMethod;
  final String paymentReference;
  final String status;
  final String usageLabel;
  final DateTime? validationAvailableAt;
  final DateTime? validatedAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? agentName;
  final String? agentNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isPending => status.toLowerCase() == 'pending_validation';

  factory DriverSubscription.fromJson(Map<String, dynamic> json) {
    return DriverSubscription(
      id: json['id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      plan: json['plan']?.toString() ?? 'monthly',
      paymentMethod: json['paymentMethod']?.toString() ?? 'mpesa',
      paymentReference: json['paymentReference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_validation',
      usageLabel: json['usageLabel']?.toString() ?? '',
      validationAvailableAt: DateTime.tryParse(
        json['validationAvailableAt']?.toString() ?? '',
      ),
      validatedAt: DateTime.tryParse(json['validatedAt']?.toString() ?? ''),
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
      agentName: json['agentName']?.toString(),
      agentNotes: json['agentNotes']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
