import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Providers/forecast_provider.dart';
import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Services/location_service.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );

    if (!mounted || result == null) return;

    final lat = result['lat'];
    final lng = result['lng'];
    if (lat is! num || lng is! num) return;

    final label = (result['name'] as String?) ?? (result['address'] as String?);

    await ref
        .read(forecastProvider.notifier)
        .setLocation(
          LatLng(lat: lat.toDouble(), lng: lng.toDouble()),
          label: label,
        );
  }

  Future<void> _ensureLocationAndReload() async {
    final servicesOk = await LocationService.ensureLocationServicesEnabled(
      context,
    );
    if (!servicesOk) return;

    if (!mounted) return;

    final permOk = await LocationService.ensureLocationPermission(context);
    if (!permOk) return;

    if (!mounted) return;
    await ref.read(forecastProvider.notifier).clearLocationOverride();
  }

  @override
  Widget build(BuildContext context) {
    final asyncForecast = ref.watch(forecastProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(forecastProvider.notifier).reload(),
          child: asyncForecast.when(
            loading: () => _buildLoading(context),
            error: (err, _) => _buildError(context, err),
            data: (data) => _buildContent(context, data),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, {String? locationLabel}) {
    final text = (locationLabel ?? '').trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_searchController.text != text) {
        _searchController.text = text;
      }
    });

    return SearchBarWidget(
      onTap: _openSearch,
      controller: _searchController,
      hintText: _searchController.text.isNotEmpty
          ? _searchController.text
          : null,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildTopBar(context, locationLabel: _searchController.text),
        const SizedBox(height: 18),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object err) {
    final isLocationErr = err is ForecastLocationException;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildTopBar(context, locationLabel: _searchController.text),
        _sectionTitle('Forecast'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocationErr ? 'Location required' : 'Something went wrong',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: isLocationErr
                          ? _ensureLocationAndReload
                          : () => ref.read(forecastProvider.notifier).reload(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isLocationErr ? 'Enable location' : 'Retry'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _openSearch,
                      child: const Text('Search place'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ForecastData data) {
    final roads = data.flood.floodedRoads;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildTopBar(context, locationLabel: data.locationLabel),
        _sectionTitle('Dangers Near You'),
        if (roads.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _emptyCard(
              title: 'No flooded roads nearby',
              subtitle: 'No flooded roads reported within 200 meters.',
              icon: Icons.check_circle_outline,
              iconColor: AppColors.accent,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final r in roads) ...[
                  _dangerRow(
                    roadName: r.roadName,
                    roadType: r.roadType,
                    metersAway: r.metersAway,
                    riskLevel: r.riskLevel,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        _sectionTitle('Weather Updates'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _weatherCard(context, data),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _emptyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
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
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerRow({
    required String roadName,
    required String roadType,
    required double metersAway,
    required int riskLevel,
  }) {
    final (label, color, icon) = _riskMeta(riskLevel);

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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roadName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${metersAway.toStringAsFixed(0)} m away${roadType.trim().isEmpty ? '' : ' • $roadType'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.near_me_outlined, color: Colors.grey.shade700),
        ],
      ),
    );
  }

  (String, Color, IconData) _riskMeta(int riskLevel) {
    final scheme = Theme.of(context).colorScheme;
    return switch (riskLevel) {
      3 => ('High Risk Flood', scheme.error, Icons.report_rounded),
      2 => ('Moderate Flood', scheme.tertiary, Icons.warning_amber_rounded),
      _ => (
        'Possible Flooded Area',
        AppColors.blue,
        Icons.info_outline_rounded,
      ),
    };
  }

  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code >= 1 && code <= 3) return Icons.wb_cloudy_outlined;
    if (code == 45 || code == 48) return Icons.blur_on_outlined;
    if (code >= 51 && code <= 67) return Icons.grain_outlined;
    if (code >= 71 && code <= 77) return Icons.ac_unit_outlined;
    if (code >= 80 && code <= 82) return Icons.umbrella_outlined;
    if (code >= 95 && code <= 99) return Icons.flash_on_outlined;
    return Icons.cloud_outlined;
  }

  Widget _weatherCard(BuildContext context, ForecastData data) {
    final w = data.weather;

    final temp = w.temperatureC;
    final wind = w.windSpeedKmh;
    final precip = w.precipitationProbability;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _weatherIcon(w.weatherCode),
              color: AppColors.darkBlue,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.conditionLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (temp != null) _miniStat('${temp.toStringAsFixed(0)}°C'),
                    if (precip != null)
                      _miniStat('Precip ${precip.toStringAsFixed(0)}%'),
                    if (wind != null)
                      _miniStat('Wind ${wind.toStringAsFixed(0)} km/h'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
