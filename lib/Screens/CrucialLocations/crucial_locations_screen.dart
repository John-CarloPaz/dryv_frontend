import 'package:flutter/material.dart';

import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class CrucialLocationsScreen extends StatefulWidget {
  const CrucialLocationsScreen({super.key});

  @override
  State<CrucialLocationsScreen> createState() => _CrucialLocationsScreenState();
}

class _CrucialLocationsScreenState extends State<CrucialLocationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _selected;
  String? _activeCategory;

  static const _categories = <String>[
    'Hospitals',
    'Evacuation Centers',
    'Charging Stations',
    'Comfort Rooms',
    'Parking Lots',
  ];

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

    setState(() {
      _selected = result;
      _activeCategory = null;
      _searchController.text = (result['name'] as String?) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

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
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selectedChip = _activeCategory == c;

                  return ChoiceChip(
                    label: Text(c),
                    selected: selectedChip,
                    onSelected: (_) {
                      setState(() => _activeCategory = c);
                      _openSearch(initialQuery: c);
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
            if (selected != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _selectedCard(selected),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyHintCard(),
              ),
            ],
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _emptyHintCard() {
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
            child: const Icon(Icons.place_outlined, color: AppColors.darkBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pick a category or tap the search bar to find a crucial location.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedCard(Map<String, dynamic> selected) {
    final name = (selected['name'] as String?) ?? 'Selected location';
    final address = (selected['address'] as String?) ?? '';

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
              color: AppColors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
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
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
