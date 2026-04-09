import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('Privacy Policy', style: TravelloTheme.subtitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TravelloTheme.title.copyWith(
                color: TravelloTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: March 2026',
              style: TravelloTheme.caption.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Travello AI ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our travel booking platform.',
            ),
            _buildSection(
              '1. Information We Collect',
              'We collect information that you provide directly to us, including:\n\n'
                  '• Personal Information: Name, email address, phone number, date of birth, gender, nationality\n'
                  '• Payment Information: Credit card details, billing address (processed securely through payment gateways)\n'
                  '• Travel Documents: Passport numbers, CNIC/ID card numbers, visa information\n'
                  '• Booking Preferences: Seat preferences, meal preferences, special requirements\n'
                  '• Usage Data: IP address, browser type, device information, pages visited',
            ),
            _buildSection(
              '2. How We Use Your Information',
              'We use the collected information for:\n\n'
                  '• Processing bookings and reservations\n'
                  '• Sending booking confirmations and updates\n'
                  '• Providing customer support\n'
                  '• Personalizing your experience\n'
                  '• Improving our services\n'
                  '• Sending promotional offers (with your consent)\n'
                  '• Complying with legal obligations',
            ),
            _buildSection(
              '3. Data Sharing',
              'We may share your information with:\n\n'
                  '• Airlines, railways, and hotels to complete bookings\n'
                  '• Payment processors for secure transactions\n'
                  '• Service providers who assist in operations\n'
                  '• Law enforcement when required by law\n\n'
                  'We do not sell your personal information to third parties.',
            ),
            _buildSection(
              '4. Data Security',
              'We implement industry-standard security measures to protect your data, including:\n\n'
                  '• SSL encryption for data transmission\n'
                  '• Secure servers and databases\n'
                  '• Regular security audits\n'
                  '• Access controls and authentication',
            ),
            _buildSection(
              '5. Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate information\n'
                  '• Request deletion of your data\n'
                  '• Opt-out of marketing communications\n'
                  '• Data portability',
            ),
            _buildSection(
              '6. Cookies',
              'We use cookies and similar technologies to enhance your experience, analyze usage, and personalize content. You can control cookie preferences through your browser settings.',
            ),
            _buildSection(
              '7. Contact Us',
              'For privacy-related inquiries, contact us at:\n\n'
                  'Email: privacy@travelloai.com\n'
                  'Phone: +92 (21) 1234-5678\n'
                  'Address: Karachi, Pakistan',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TravelloTheme.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              color: TravelloTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TravelloTheme.paragraph.copyWith(
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
