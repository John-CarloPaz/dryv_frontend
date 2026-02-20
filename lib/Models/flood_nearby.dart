class FloodedRoad {
  final int roadGid;
  final String roadName;
  final String roadType;
  final int riskLevel;
  final double metersAway;

  const FloodedRoad({
    required this.roadGid,
    required this.roadName,
    required this.roadType,
    required this.riskLevel,
    required this.metersAway,
  });

  factory FloodedRoad.fromJson(Map<String, dynamic> json) {
    final roadNameRaw = json['road_name'];
    final roadName = (roadNameRaw is String && roadNameRaw.trim().isNotEmpty)
        ? roadNameRaw
        : 'Unknown road';

    final roadTypeRaw = json['road_type'];
    final roadType = (roadTypeRaw is String) ? roadTypeRaw : '';

    return FloodedRoad(
      roadGid: (json['road_gid'] as num?)?.toInt() ?? 0,
      roadName: roadName,
      roadType: roadType,
      riskLevel: (json['risk_level'] as num?)?.toInt() ?? 0,
      metersAway: (json['meters_away'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FloodNearbyResponse {
  final String status;
  final int? maxRiskLevel;
  final List<FloodedRoad> floodedRoads;
  final DateTime? lastUpdatedAt;

  const FloodNearbyResponse({
    required this.status,
    required this.maxRiskLevel,
    required this.floodedRoads,
    required this.lastUpdatedAt,
  });

  factory FloodNearbyResponse.fromJson(Map<String, dynamic> json) {
    final roadsRaw = json['flooded_roads'];
    final roads = <FloodedRoad>[];
    if (roadsRaw is List) {
      for (final item in roadsRaw) {
        if (item is Map) {
          roads.add(FloodedRoad.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    final lastUpdatedRaw =
        (json['last_updated_at'] as String?) ??
        (json['lastUpdatedAt'] as String?);
    final lastUpdatedAt =
        (lastUpdatedRaw == null || lastUpdatedRaw.trim().isEmpty)
        ? null
        : DateTime.tryParse(lastUpdatedRaw);

    return FloodNearbyResponse(
      status: (json['status'] as String?) ?? '',
      maxRiskLevel: (json['max_risk_level'] as num?)?.toInt(),
      floodedRoads: roads,
      lastUpdatedAt: lastUpdatedAt,
    );
  }
}
