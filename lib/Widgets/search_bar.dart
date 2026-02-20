import 'package:flutter/material.dart';

import 'package:dryvmobapp/Screens/Profile/profile_screen.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? hintText;

  const SearchBarWidget({
    super.key,
    this.onTap,
    this.onProfileTap,
    this.controller,
    this.onChanged,
    this.readOnly = true,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    const cPrimary = AppColors.primary;
    const cDarkBlue = AppColors.darkBlue;
    const cBlue = AppColors.blue;
    const cAccent = AppColors.accent;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cBlue.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Image.asset(
                    'lib/assets/images/logo.png',
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.map, color: cPrimary, size: 22);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: readOnly,
                      child: TextField(
                        controller: controller,
                        onChanged: onChanged,
                        readOnly: readOnly,
                        decoration: InputDecoration(
                          hintText: hintText ?? 'Try petrol stations, cash...',
                          hintStyle: TextStyle(
                            color: cDarkBlue.withValues(alpha: 0.60),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onProfileTap ??
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: cAccent.withValues(alpha: 0.95),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
