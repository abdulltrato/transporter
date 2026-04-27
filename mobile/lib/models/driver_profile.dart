class DriverProfile {
  const DriverProfile({
    required this.userId,
    required this.status,
    required this.isProfileComplete,
    this.documentId,
    this.documentExpiry,
    this.neighborhood,
    this.operatingRegion,
    this.updatedAt,
  });

  final String userId;
  final String status;
  final String? documentId;
  final String? documentExpiry;
  final String? neighborhood;
  final String? operatingRegion;
  final bool isProfileComplete;
  final DateTime? updatedAt;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      userId: json['userId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'offline',
      documentId: json['documentId']?.toString(),
      documentExpiry: json['documentExpiry']?.toString(),
      neighborhood: json['neighborhood']?.toString(),
      operatingRegion: json['operatingRegion']?.toString(),
      isProfileComplete: json['isProfileComplete'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
