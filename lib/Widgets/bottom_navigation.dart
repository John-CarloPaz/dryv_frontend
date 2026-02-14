import 'package:flutter/material.dart';

import 'package:dryvmobapp/Services/bottom_nav_visibility.dart';

class BottomNavWidget extends StatefulWidget {
  final List<Widget> pages;
  final int initialIndex;

  const BottomNavWidget({
    super.key,
    required this.pages,
    this.initialIndex = 0,
  });

  @override
  State<BottomNavWidget> createState() => _BottomNavWidgetState();
}

class _BottomNavWidgetState extends State<BottomNavWidget> {
  late int _currentIndex;

  static const _cPrimary = Color(0xFF13005A);
  static const _cDarkBlue = Color(0xFF00337C);
  static const _cBlue = Color(0xFF1C82AD);
  static const _cAccent = Color(0xFF03C988);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: widget.pages),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: BottomNavVisibility.hideCountListenable,
        builder: (context, hideCount, _) {
          if (hideCount > 0) return const SizedBox.shrink();

          return NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              elevation: 8,
              height: 78,
              indicatorColor: _cAccent.withValues(alpha: 0.20),
              indicatorShape: const StadiumBorder(),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? _cPrimary
                      : _cDarkBlue.withValues(alpha: 0.70),
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 26,
                  color: isSelected
                      ? _cPrimary
                      : _cDarkBlue.withValues(alpha: 0.70),
                );
              }),
              overlayColor: WidgetStateProperty.all(
                _cBlue.withValues(alpha: 0.08),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.map), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.campaign),
                  label: 'Forecast',
                ),
                NavigationDestination(
                  icon: Icon(Icons.travel_explore),
                  label: 'Search',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
