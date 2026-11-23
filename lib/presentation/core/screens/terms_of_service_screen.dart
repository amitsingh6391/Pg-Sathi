import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_ui_constants.dart';
import '../widgets/premium_kit.dart';

/// Terms of Service screen for the app.
/// Displays terms and conditions.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static final Uri _standardAppleEulaUri = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(title: const Text('Terms of Service')),
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
                      Icons.gavel_rounded,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terms of Service',
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
              title: '1. Acceptance of Terms',
              content: '''
By using PG Sathi, you agree to be bound by these Terms of Service. If you do not agree, please do not use the service.
''',
            ),
            _Section(
              title: '2. Service Description',
              content: '''
PG Sathi is a platform for PG and hostel owners to manage tenants, rooms, beds, rent, deposits, notices, and payment records.
''',
            ),
            _Section(
              title: '3. User Responsibilities',
              content: '''
Users agree to:
• Provide accurate information
• Maintain the security of their account
• Use the service only for lawful purposes
• Respect other users' rights
• Comply with PG house rules and regulations
''',
            ),
            _Section(
              title: '4. Payment Terms',
              content: '''
• Payments are processed securely through supported payment processors
• Rent and fees are non-refundable unless otherwise stated
• Owners are responsible for setting pricing and payment terms
• Residents must pay rent and fees as agreed
''',
            ),
            _Section(
              title: '5. Auto-Renewable Subscriptions',
              content: '''
PG Sathi Pro subscriptions purchased through the App Store are auto-renewable subscriptions.

• Payment is charged to your Apple ID account at confirmation of purchase
• Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period
• Your account may be charged for renewal within 24 hours before the end of the current period
• You can manage or cancel subscriptions in your App Store account settings
• Access continues until the end of the paid subscription period after cancellation
• PG Sathi uses Apple's standard End User License Agreement for App Store purchases
''',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton(
                onPressed: () => launchUrl(
                  _standardAppleEulaUri,
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  'Apple Standard Terms of Use (EULA)',
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            _Section(
              title: '6. Stay Terms',
              content: '''
• Stays are subject to the PG owner's terms
• Bed assignments are at the discretion of PG owners
• Stays may be ended by owner or resident
• Refunds are subject to PG owner's policy
''',
            ),
            _Section(
              title: '7. Limitation of Liability',
              content: '''
PG Sathi is provided "as is" without warranties. We are not liable for:
• Service interruptions or errors
• Loss of data or information
• Disputes between owners and residents
• Third-party payment processor issues
''',
            ),
            _Section(
              title: '8. Contact Information',
              content: '''
For questions about these Terms, contact us at:
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
