import 'package:flutter/material.dart';

import 'package:dryvmobapp/theme/app_colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String lastUpdated = 'February 2026';

  TextStyle _h1Style(BuildContext context) => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  TextStyle _h2Style(BuildContext context) => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  TextStyle _bodyStyle(BuildContext context) => TextStyle(
    height: 1.45,
    fontSize: 13,
    color: AppColors.darkBlue.withValues(alpha: 0.78),
  );

  Widget _spacer([double h = 10]) => SizedBox(height: h);

  Widget _h1(BuildContext context, String text) =>
      Text(text, style: _h1Style(context));

  Widget _h2(BuildContext context, String text) =>
      Text(text, style: _h2Style(context));

  Widget _p(BuildContext context, String text) =>
      Text(text, style: _bodyStyle(context));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _h1(
                    context,
                    'AlistoPH: A Flood‑Aware Route Planning Navigation Application',
                  ),
                  _spacer(8),
                  _p(context, 'Last Updated: $lastUpdated'),
                  _spacer(2),
                  _p(
                    context,
                    'Owned and Operated by: YunoH, CCIS 8C, Systems Plus College Foundation',
                  ),
                  _spacer(16),

                  _h2(context, '1. Information We Collect'),
                  _spacer(6),
                  _p(
                    context,
                    'AlistoPH collects personal information such as your name and email address when you create an account. The application also collects real‑time GPS location data to provide navigation, hazard detection, and flood‑aware routing. Additionally, users may submit flood reports containing flood depth, descriptions, timestamps, and location information. Device information such as model, operating system, and diagnostic logs may also be collected to improve system performance.',
                  ),
                  _spacer(14),

                  _h2(context, '2. How We Use Your Information'),
                  _spacer(6),
                  _p(
                    context,
                    'The information collected by AlistoPH is used to provide real‑time flood alerts, compute RWR and CHI values, generate safe route recommendations, maintain account functionality, and improve system accuracy. User‑generated flood reports are used to enhance hazard mapping and validate system outputs. We do not sell or share personal information for advertising purposes.',
                  ),
                  _spacer(14),

                  _h2(context, '3. Data Sources Used by AlistoPH'),
                  _spacer(6),
                  _p(
                    context,
                    'AlistoPH integrates data from PAGASA, Project NOAH, Open‑Meteo, OpenWeatherMap, and Mapbox. These services may collect anonymized usage data according to their respective Privacy Policies. AlistoPH does not control how these third‑party services process their data.',
                  ),
                  _spacer(14),

                  _h2(context, '4. Data Storage and Retention'),
                  _spacer(6),
                  _p(
                    context,
                    'User accounts, flood reports, and system logs are stored permanently in our secure cloud database unless the user requests deletion. Diagnostic logs may be retained for troubleshooting and system improvement. All data is stored using industry‑standard security measures.',
                  ),
                  _spacer(14),

                  _h2(context, '5. Data Sharing'),
                  _spacer(6),
                  _p(
                    context,
                    'We may share anonymized or aggregated data with academic researchers, disaster management agencies, or local government units to support flood preparedness and disaster risk reduction. Personal identifiers such as names and email addresses will not be shared without explicit user consent.',
                  ),
                  _spacer(14),

                  _h2(context, '6. Security Measures'),
                  _spacer(6),
                  _p(
                    context,
                    'We implement encryption, secure authentication, and access‑controlled databases to protect user information. However, no system is completely secure, and users acknowledge that data transmission and storage carry inherent risks.',
                  ),
                  _spacer(14),

                  _h2(context, '7. Children’s Privacy'),
                  _spacer(6),
                  _p(
                    context,
                    'AlistoPH is not intended for children under the age of 13. We do not knowingly collect personal information from minors. If we discover that a child has provided personal data, we will take steps to delete it promptly.',
                  ),
                  _spacer(14),

                  _h2(context, '8. User Rights'),
                  _spacer(6),
                  _p(
                    context,
                    'Users have the right to access, update, or delete their personal information. Users may also request account deletion or withdraw consent for location tracking, although this may limit the functionality of the application.',
                  ),
                  _spacer(14),

                  _h2(context, '9. Changes to This Policy'),
                  _spacer(6),
                  _p(
                    context,
                    'We may update this Privacy Policy periodically. Significant changes will be communicated through the application or via email. Continued use of the application after updates constitutes acceptance of the revised policy.',
                  ),
                  _spacer(14),

                  _h2(context, '10. Contact Information'),
                  _spacer(6),
                  _p(context, 'For privacy‑related concerns, you may contact:'),
                  _spacer(6),
                  _p(context, 'Email: alistoph1357@gmail.com'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
