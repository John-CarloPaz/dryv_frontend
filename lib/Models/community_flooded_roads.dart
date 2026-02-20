class CommunityFloodedRoadsResponse {
  final String status;
  final int? maxRiskLevel;
  final int? windowHours;
  final int? minRiskLevel;
  final List<CommunityFloodedRoad> floodedRoads;

  const CommunityFloodedRoadsResponse({
    required this.status,
    required this.maxRiskLevel,
    required this.windowHours,
    required this.minRiskLevel,
    required this.floodedRoads,
  });

  factory CommunityFloodedRoadsResponse.fromJson(Map<String, dynamic> json) {
    final roadsRaw =
        json['community_flooded_roads'] ?? json['communityFloodedRoads'];

    final roads = <CommunityFloodedRoad>[];
    if (roadsRaw is List) {
      for (final item in roadsRaw) {
        if (item is Map) {
          roads.add(
            CommunityFloodedRoad.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
    }

    return CommunityFloodedRoadsResponse(
      status: (json['status'] as String?) ?? '',
      maxRiskLevel: (json['max_risk_level'] as num?)?.toInt(),
      windowHours: (json['window_hours'] as num?)?.toInt(),
      minRiskLevel: (json['min_risk_level'] as num?)?.toInt(),
      floodedRoads: roads,
    );
  }
}

class CommunityFloodedRoad {
  final double lat;
  final double lng;
  final CommunityRoadInfo road;
  final CommunityFloodChi chi;

  const CommunityFloodedRoad({
    required this.lat,
    required this.lng,
    required this.road,
    required this.chi,
  });

  factory CommunityFloodedRoad.fromJson(Map<String, dynamic> json) {
    final roadRaw = json['road'];
    final chiRaw = json['chi'];

    return CommunityFloodedRoad(
      lat: (json['flooded_road_lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['flooded_road_lng'] as num?)?.toDouble() ?? 0.0,
      road: roadRaw is Map
          ? CommunityRoadInfo.fromJson(roadRaw.cast<String, dynamic>())
          : const CommunityRoadInfo.empty(),
      chi: chiRaw is Map
          ? CommunityFloodChi.fromJson(chiRaw.cast<String, dynamic>())
          : const CommunityFloodChi.empty(),
    );
  }
}

class CommunityRoadInfo {
  final int gid;
  final int segmentKey;
  final String name;
  final String type;
  final String ref;

  const CommunityRoadInfo({
    required this.gid,
    required this.segmentKey,
    required this.name,
    required this.type,
    required this.ref,
  });

  const CommunityRoadInfo.empty()
    : gid = 0,
      segmentKey = 0,
      name = '',
      type = '',
      ref = '';

  factory CommunityRoadInfo.fromJson(Map<String, dynamic> json) {
    return CommunityRoadInfo(
      gid: (json['gid'] as num?)?.toInt() ?? 0,
      segmentKey: (json['segment_key'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      ref: (json['ref'] as String?) ?? '',
    );
  }
}

class CommunityFloodChi {
  final int score;
  final int riskLevel;
  final int reportsCount;
  final DateTime? lastReportedAt;
  final double? avgEstimatedDepth;
  final int? avgEstimatedDepthLevel;
  final String avgEstimatedDepthLabel;

  const CommunityFloodChi({
    required this.score,
    required this.riskLevel,
    required this.reportsCount,
    required this.lastReportedAt,
    required this.avgEstimatedDepth,
    required this.avgEstimatedDepthLevel,
    required this.avgEstimatedDepthLabel,
  });

  const CommunityFloodChi.empty()
    : score = 0,
      riskLevel = 0,
      reportsCount = 0,
      lastReportedAt = null,
      avgEstimatedDepth = null,
      avgEstimatedDepthLevel = null,
      avgEstimatedDepthLabel = '';

  factory CommunityFloodChi.fromJson(Map<String, dynamic> json) {
    final last =
        (json['last_reported_at'] as String?) ??
        (json['lastReportedAt'] as String?);
    final lastReportedAt = (last == null || last.trim().isEmpty)
        ? null
        : DateTime.tryParse(last);

    return CommunityFloodChi(
      score: (json['score'] as num?)?.toInt() ?? 0,
      riskLevel: (json['risk_level'] as num?)?.toInt() ?? 0,
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
      lastReportedAt: lastReportedAt,
      avgEstimatedDepth: (json['avg_estimated_depth'] as num?)?.toDouble(),
      avgEstimatedDepthLevel: (json['avg_estimated_depth_level'] as num?)
          ?.toInt(),
      avgEstimatedDepthLabel:
          (json['avg_estimated_depth_label'] as String?) ??
          (json['avgEstimatedDepthLabel'] as String?) ??
          '',
    );
  }
}
