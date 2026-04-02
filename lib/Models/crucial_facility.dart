class CrucialFacility {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? barangay;
  final String? municipality;
  final String? postalCode;
  final String? country;
  final String type;
  final String typeKey;
  final double? distanceMeters;

  const CrucialFacility({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.typeKey,
    this.barangay,
    this.municipality,
    this.postalCode,
    this.country,
    this.distanceMeters,
  });

  factory CrucialFacility.fromJson(Map<String, dynamic> json) {
    return CrucialFacility(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      barangay: json['barangay'] as String?,
      municipality: json['municipality'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      type: (json['type'] as String?) ?? '',
      typeKey: (json['type_key'] as String?) ?? '',
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
    );
  }
}

enum CrucialFacilityType {
  evacuationCenter,
  hospital,
  police,
}

extension CrucialFacilityTypeX on CrucialFacilityType {
  String get apiKey {
    switch (this) {
      case CrucialFacilityType.evacuationCenter:
        return 'evacuation_center';
      case CrucialFacilityType.hospital:
        return 'hospital';
      case CrucialFacilityType.police:
        return 'police';
    }
  }

  String get label {
    switch (this) {
      case CrucialFacilityType.evacuationCenter:
        return 'Evacuation Center';
      case CrucialFacilityType.hospital:
        return 'Hospital';
      case CrucialFacilityType.police:
        return 'Police';
    }
  }
}
