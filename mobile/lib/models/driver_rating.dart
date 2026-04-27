class DriverRating {
  const DriverRating({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.clientId,
    required this.stars,
    required this.satisfactionLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String rideId;
  final String driverId;
  final String clientId;
  final int stars;
  final String satisfactionLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DriverRating.fromJson(Map<String, dynamic> json) {
    return DriverRating(
      id: json['id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      satisfactionLabel: json['satisfactionLabel']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class DriverRatingSummary {
  const DriverRatingSummary({
    required this.driverId,
    required this.totalRatings,
    required this.averageStars,
    required this.star1,
    required this.star2,
    required this.star3,
    required this.star4,
    required this.star5,
  });

  final String driverId;
  final int totalRatings;
  final double averageStars;
  final int star1;
  final int star2;
  final int star3;
  final int star4;
  final int star5;

  factory DriverRatingSummary.fromJson(Map<String, dynamic> json) {
    return DriverRatingSummary(
      driverId: json['driverId']?.toString() ?? '',
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      averageStars: (json['averageStars'] as num?)?.toDouble() ?? 0,
      star1: (json['star1'] as num?)?.toInt() ?? 0,
      star2: (json['star2'] as num?)?.toInt() ?? 0,
      star3: (json['star3'] as num?)?.toInt() ?? 0,
      star4: (json['star4'] as num?)?.toInt() ?? 0,
      star5: (json['star5'] as num?)?.toInt() ?? 0,
    );
  }
}
