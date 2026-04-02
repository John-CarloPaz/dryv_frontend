import 'dart:convert';

import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MapboxTilesetMetadataService {
  MapboxTilesetMetadataService._();

  static const Duration _defaultTtl = Duration(minutes: 10);

  static final Map<String, _VectorLayerCacheEntry> _vectorLayerCache =
      <String, _VectorLayerCacheEntry>{};

  /// Returns the tileset id without the `mapbox://` prefix.
  ///
  /// Examples:
  /// - `mapbox://alistoph.dryv_tileset_5` -> `alistoph.dryv_tileset_5`
  /// - `alistoph.dryv_tileset_5` -> `alistoph.dryv_tileset_5`
  static String normalizeTilesetId(String tilesetUrlOrId) {
    final trimmed = tilesetUrlOrId.trim();
    const prefix = 'mapbox://';
    return trimmed.startsWith(prefix)
        ? trimmed.substring(prefix.length)
        : trimmed;
  }

  static String? _accessToken() {
    final token = (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '').trim();
    return token.isEmpty ? null : token;
  }

  /// Fetches tileset metadata from the Mapbox Tiles API (v4) and returns the
  /// list of vector layer ids (aka "source-layer" names).
  ///
  /// If the token cannot access the tileset (private tileset / wrong account),
  /// this will log the HTTP status and return null.
  static Future<List<String>?> fetchVectorLayerIds(
    String tilesetUrlOrId, {
    bool forceRefresh = false,
    Duration ttl = _defaultTtl,
  }) async {
    final tilesetId = normalizeTilesetId(tilesetUrlOrId);

    final cached = _vectorLayerCache[tilesetId];
    if (!forceRefresh && cached != null && !cached.isExpired(ttl)) {
      return cached.ids;
    }

    final token = _accessToken();
    if (token == null) {
      AppFileLogger.instance.warn(
        'Mapbox tileset introspection skipped: MAPBOX_ACCESS_TOKEN is empty.',
      );
      return null;
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/v4/$tilesetId.json',
      <String, String>{'access_token': token},
    );

    try {
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        final body = resp.body;
        final snippet = body.length > 400 ? body.substring(0, 400) : body;
        AppFileLogger.instance.warn(
          'Mapbox tileset metadata failed: tileset=$tilesetId '
          'status=${resp.statusCode} body=$snippet',
        );
        return null;
      }

      final obj = jsonDecode(resp.body);
      final layers = (obj is Map<String, dynamic>)
          ? obj['vector_layers']
          : null;
      if (layers is! List) {
        AppFileLogger.instance.warn(
          'Mapbox tileset metadata unexpected shape: tileset=$tilesetId',
        );
        return null;
      }

      final ids = <String>[];
      for (final layer in layers) {
        if (layer is Map<String, dynamic>) {
          final id = layer['id'];
          if (id is String && id.trim().isNotEmpty) {
            ids.add(id.trim());
          }
        }
      }

      if (ids.isEmpty) {
        AppFileLogger.instance.warn(
          'Mapbox tileset metadata has no vector layers: tileset=$tilesetId',
        );
        return null;
      }

      _vectorLayerCache[tilesetId] = _VectorLayerCacheEntry(
        ids: ids,
        fetchedAt: DateTime.now(),
      );
      AppFileLogger.instance.info(
        'Mapbox tileset vector layers: tileset=$tilesetId layers=${ids.join(',')}',
      );
      return ids;
    } catch (e, st) {
      AppFileLogger.instance.error(
        'Mapbox tileset metadata error: tileset=$tilesetId',
        err: e,
        stack: st,
      );
      return null;
    }
  }

  /// Attempts to pick a valid source-layer id for the tileset.
  ///
  /// - Returns the first preferred id that exists in the metadata.
  /// - Otherwise returns the first layer from the tileset.
  /// - If metadata can’t be fetched, returns null.
  static Future<String?> resolveSourceLayer(
    String tilesetUrlOrId, {
    required List<String> preferred,
    bool forceRefresh = false,
    Duration ttl = _defaultTtl,
  }) async {
    final ids = await fetchVectorLayerIds(
      tilesetUrlOrId,
      forceRefresh: forceRefresh,
      ttl: ttl,
    );
    if (ids == null || ids.isEmpty) return null;

    for (final candidate in preferred) {
      if (ids.contains(candidate)) return candidate;
    }

    return ids.first;
  }
}

class _VectorLayerCacheEntry {
  final List<String> ids;
  final DateTime fetchedAt;

  const _VectorLayerCacheEntry({required this.ids, required this.fetchedAt});

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(fetchedAt) > ttl;
  }
}
