import 'package:material_ui/material_ui.dart';

import '../app_ui_constants.dart';
import '../widgets/premium_kit.dart';

/// Privacy Policy screen for the app.
/// Displays privacy policy information.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_rounded,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Privacy Policy',
                          style: AppUIConstants.headingLg,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: ${DateTime.now().year}',
                          style: AppUIConstants.bodySm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Section(
              title: '1. Information We Collect',
              content: '''
We collect information that you provide directly to us, including:
• Phone number for authentication
• Name and contact information
• PG stay details
• Payment information processed securely by supported payment processors
• Approximate location (to show PGs near you, if you allow it)
• Device information for push notifications
''',
            ),
            _Section(
              title: '2. How We Use Your Information',
              content: '''
We use the information we collect to:
• Provide and maintain our services
• Process payments and manage memberships
• Send you notifications about your membership
• Improve our services and user experience
''',
            ),
            _Section(
              title: '3. Data Storage and Security',
              content: '''
• Your data is stored securely in Firebase (Google Cloud)
• We use industry-standard encryption for sensitive data
• Payment information is processed by supported payment processors and not stored by us
• We implement appropriate security measures to protect your data
''',
            ),
            _Section(
              title: '4. Data Sharing',
              content: '''
We do not sell your personal information. We may share data with:
• Library owners (for membership management)
• Payment processors for transaction processing
• Service providers (Firebase) for app functionality
''',
            ),
            _Section(
              title: '5. Your Rights',
              content: '''
You have the right to:
• Access your personal data
• Request correction of inaccurate data
• Request deletion of your data
• Opt-out of non-essential communications
''',
            ),
            _Section(
              title: '6. Contact Us',
              content: '''
If you have questions about this Privacy Policy, please contact us at:
Email: support@pgsathi.in
Phone: 9548582776
Website: https://pg-sathi.web.app
''',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppUIConstants.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppUIConstants.headingSm)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
