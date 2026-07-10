import 'package:flutter/material.dart';

/// Privacy Policy screen for the app.
/// Displays privacy policy information.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _Section(
              title: '1. Information We Collect',
              content: '''
We collect information that you provide directly to us, including:
• Phone number for authentication
• Name and contact information
• Library membership details
• Payment information processed securely by supported payment processors
• Location data (for check-in/check-out verification)
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
• Verify your location for attendance tracking
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
Website: https://pgsathi.in
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
