import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Models/crucial_facility.dart';
import 'package:dryvmobapp/Services/crucial_facilities_service.dart';
import 'package:dryvmobapp/Services/location_service.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:dryvmobapp/Services/bottom_nav_state.dart';
import 'package:dryvmobapp/Services/crucial_facility_selection_state.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class CrucialLocationsScreen extends StatefulWidget {
  const CrucialLocationsScreen({super.key});

  @override
  State<CrucialLocationsScreen> createState() => _CrucialLocationsScreenState();
}

class _CrucialLocationsScreenState extends State<CrucialLocationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  CrucialFacilityType _activeType = CrucialFacilityType.evacuationCenter;
  CrucialFacilitiesNearestResult? _nearest;
  bool _loading = false;
  String? _errorMessage;

  static const _pillTypes = <CrucialFacilityType>[
    CrucialFacilityType.evacuationCenter,
    CrucialFacilityType.hospital,
    CrucialFacilityType.police,
  ];

  @override
  void initState() {
    super.initState();
    // Fetch immediately when the module loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNearestFacilities();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSearch({String? initialQuery}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: initialQuery),
      ),
    );

    if (!mounted || result == null) return;

    // Keep search as an optional manual lookup, but don't override the
    // pill-driven list UX.
    setState(() {
      _searchController.text = (result['name'] as String?) ?? '';
    });
  }

  Future<void> _fetchNearestFacilities() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final servicesEnabled =
          await LocationService.ensureLocationServicesEnabled(context);
      if (!mounted) return;
      if (!servicesEnabled) {
        setState(() {
          _errorMessage =
              'Location is turned off. Enable GPS to load nearby facilities.';
          _nearest = null;
        });
        return;
      }

      final granted = await LocationService.ensureLocationPermission(context);
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _errorMessage =
              'Location permission is required to load nearby facilities.';
          _nearest = null;
        });
        return;
      }

      final originMap = await LocationService.getLastKnownLocation();
      if (!mounted) return;
      if (originMap == null) {
        setState(() {
          _errorMessage =
              'Unable to determine your current location. Try again.';
          _nearest = null;
        });
        return;
      }

      final baseUrl = dotenv.env['API_BASE_URL'];
      final endpointEnv = dotenv.env['DRYV_CRUCIAL_FACILITIES_NEAREST_URL'];
      final endpoint = (endpointEnv != null && endpointEnv.trim().isNotEmpty)
          ? endpointEnv
          : (baseUrl == null || baseUrl.trim().isEmpty)
              ? null
              : '${baseUrl.replaceAll(RegExp(r"/+$"), "")}/crucial-facilities/nearest';

      if (endpoint == null || endpoint.trim().isEmpty) {
        setState(() {
          _errorMessage =
              'Backend URL not configured. Set API_BASE_URL (or DRYV_CRUCIAL_FACILITIES_NEAREST_URL) in .env';
          _nearest = null;
        });
        return;
      }

      final service = CrucialFacilitiesService(nearestEndpoint: Uri.parse(endpoint));

      final lat = originMap['lat'] ?? 0.0;
      final lng = originMap['lng'] ?? 0.0;

      final nearest = await service.fetchNearest(
        latitude: lat,
        longitude: lng,
        limitPerType: 5,
      );

      if (!mounted) return;
      setState(() {
        _nearest = nearest;
      });
    } on CrucialFacilitiesException catch (e) {
      AppFileLogger.instance.warn('Crucial facilities error: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _nearest = null;
      });
    } catch (e) {
      AppFileLogger.instance.error('Crucial facilities unexpected error', err: e);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load facilities: $e';
        _nearest = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearest = _nearest;
    final items = nearest?.forType(_activeType) ?? const <CrucialFacility>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            SearchBarWidget(
              onTap: () => _openSearch(),
              controller: _searchController,
              hintText: _searchController.text.isNotEmpty
                  ? _searchController.text
                  : 'Search crucial locations…',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Crucial Locations',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _pillTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final type = _pillTypes[i];
                  final selectedChip = _activeType == type;

                  return ChoiceChip(
                    label: Text(type.label),
                    selected: selectedChip,
                    onSelected: (_) {
                      setState(() => _activeType = type);
                    },
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selectedChip ? Colors.white : AppColors.primary,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    shape: StadiumBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBody(items: items),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({required List<CrucialFacility> items}) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final err = _errorMessage;
    if (err != null && err.trim().isNotEmpty) {
      return _messageCard(
        icon: Icons.info_outline,
        iconColor: AppColors.darkBlue,
        message: err,
        actionLabel: 'Retry',
        onAction: _fetchNearestFacilities,
      );
    }

    if (_nearest == null) {
      return _messageCard(
        icon: Icons.place_outlined,
        iconColor: AppColors.darkBlue,
        message: 'Loading nearby facilities…',
        actionLabel: 'Refresh',
        onAction: _fetchNearestFacilities,
      );
    }

    if (items.isEmpty) {
      return _messageCard(
        icon: Icons.search_off,
        iconColor: AppColors.darkBlue,
        message: 'No nearby ${_activeType.label.toLowerCase()} found.',
        actionLabel: 'Refresh',
        onAction: _fetchNearestFacilities,
      );
    }

    return Column(
      children: items
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _facilityCard(f),
            ),
          )
          .toList(growable: false),
    );
  }


  Widget _messageCard({
    required IconData icon,
    required Color iconColor,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _facilityCard(CrucialFacility facility) {
    final name = _toDisplayName(facility.name);
    final placeLine = _formatPlaceLine(facility);
    final distance = facility.distanceMeters;

    final icon = switch (_activeType) {
      CrucialFacilityType.evacuationCenter => Icons.home_work_outlined,
      CrucialFacilityType.hospital => Icons.local_hospital_outlined,
      CrucialFacilityType.police => Icons.local_police_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // Switch to map and show this facility.
        CrucialFacilitySelectionState.select(
          CrucialFacilityMapSelection(
            lat: facility.latitude,
            lng: facility.longitude,
            name: name,
            address: placeLine == '—' ? '' : placeLine,
          ),
        );
        BottomNavState.setIndex(0);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    placeLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.2),
                  ),
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 10),
              Text(
                _formatDistance(distance),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _toDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '—';
    return _titleCase(trimmed);
  }

  String _titleCase(String input) {
    // Basic title-casing for API-provided lowercase names.
    final words = input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map(_titleCaseWord).join(' ');
  }

  String _titleCaseWord(String word) {
    // Preserve acronyms/numeric tokens.
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(word);
    if (!hasLetter) return word;

    // Handle hyphenated / apostrophized words.
    if (word.contains('-')) {
      return word.split('-').map(_titleCaseWord).join('-');
    }
    if (word.contains("'")) {
      return word.split("'").map(_titleCaseWord).join("'");
    }

    // If already looks like an acronym (all caps and short), keep it.
    final lettersOnly = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (lettersOnly.isNotEmpty &&
        lettersOnly.toUpperCase() == lettersOnly &&
        lettersOnly.length <= 4) {
      return word;
    }

    final first = word.substring(0, 1).toUpperCase();
    final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
    return '$first$rest';
  }

  String _formatPlaceLine(CrucialFacility f) {
    final parts = <String>[];
    if (f.barangay != null && f.barangay!.trim().isNotEmpty) {
      parts.add(f.barangay!.trim());
    }
    if (f.municipality != null && f.municipality!.trim().isNotEmpty) {
      parts.add(f.municipality!.trim());
    }
    if (f.postalCode != null && f.postalCode!.trim().isNotEmpty) {
      parts.add(f.postalCode!.trim());
    }

    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _formatDistance(double meters) {
    if (!meters.isFinite) return '—';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }
}
