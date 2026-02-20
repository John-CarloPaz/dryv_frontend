import 'package:flutter/material.dart';

import 'package:dryvmobapp/theme/app_colors.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Template placeholder\n\n'
              'Put your Terms and Conditions content here.\n\n'
              'Sections you may want to add:\n'
              '- Acceptance of terms\n'
              '- User accounts\n'
              '- Privacy and data usage\n'
              '- Prohibited activities\n'
              '- Disclaimer and limitation of liability\n'
              '- Contact information\n',
              style: TextStyle(height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}
