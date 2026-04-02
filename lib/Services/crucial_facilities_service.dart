import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Models/crucial_facility.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';

class CrucialFacilitiesException implements Exception {
  final String code;
  final String message;

  CrucialFacilitiesException(this.code, this.message);

  @override
  String toString() => 'CrucialFacilitiesException($code): $message';
}

class CrucialFacilitiesNearestResult {
  final Map<CrucialFacilityType, List<CrucialFacility>> facilities;

  const CrucialFacilitiesNearestResult({required this.facilities});

  List<CrucialFacility> forType(CrucialFacilityType type) {
    return facilities[type] ?? const <CrucialFacility>[];
  }
}

class CrucialFacilitiesService {
  final Uri nearestEndpoint;
  final http.Client _client;

  CrucialFacilitiesService({
    required this.nearestEndpoint,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<CrucialFacilitiesNearestResult> fetchNearest({
    required double latitude,
    required double longitude,
    int limitPerType = 5,
  }) async {
    final uri = nearestEndpoint.replace(
      queryParameters: {
        ...nearestEndpoint.queryParameters,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'limit_per_type': limitPerType.toString(),
      },
    );

    AppFileLogger.instance.info('Fetching nearest crucial facilities: $uri');

    late final http.Response resp;
    try {
      resp = await _client.get(uri);
    } on SocketException catch (e) {
      AppFileLogger.instance.error(
        'Crucial facilities backend unreachable: ${e.message}',
        err: e,
      );
      throw CrucialFacilitiesException(
        'BACKEND_UNREACHABLE',
        'Cannot connect to server. ${e.message}',
      );
    } catch (e) {
      AppFileLogger.instance.error('Crucial facilities request failed', err: e);
      throw CrucialFacilitiesException('REQUEST_FAILED', e.toString());
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final snippet = resp.body.length > 600
          ? '${resp.body.substring(0, 600)}...'
          : resp.body;
      AppFileLogger.instance.error(
        'Crucial facilities HTTP error: status=${resp.statusCode} body=$snippet',
      );
      throw CrucialFacilitiesException(
        'BACKEND_HTTP_${resp.statusCode}',
        'Backend returned HTTP ${resp.statusCode}',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw CrucialFacilitiesException(
        'INVALID_JSON',
        'Expected JSON object',
      );
    }

    final status = decoded['status'];
    final ok = status is String && status.toLowerCase() == 'ok';
    if (!ok) {
      throw CrucialFacilitiesException(
        'STATUS_NOT_OK',
        'status=$status',
      );
    }

    final data = decoded['data'];
    if (data is! Map) {
      throw CrucialFacilitiesException('MISSING_DATA', 'Missing data');
    }

    final facilities = <CrucialFacilityType, List<CrucialFacility>>{};

    for (final type in CrucialFacilityType.values) {
      final raw = data[type.apiKey];
      if (raw is! List) {
        facilities[type] = const <CrucialFacility>[];
        continue;
      }

      final parsed = <CrucialFacility>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          parsed.add(
            CrucialFacility.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // skip
        }
      }
      facilities[type] = parsed;
    }

    return CrucialFacilitiesNearestResult(facilities: facilities);
  }
}
