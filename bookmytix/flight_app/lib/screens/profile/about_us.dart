import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('About Us', style: TravelloTheme.subtitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: TravelloTheme.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.airplanemode_active,
                  size: 80,
                  color: TravelloTheme.primaryMain,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Welcome to Travello AI',
              style: TravelloTheme.title.copyWith(
                color: TravelloTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Your Intelligent Travel Companion',
              style: TravelloTheme.subtitle.copyWith(
                color: TravelloTheme.primaryMain,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              'Our Mission',
              'Travello AI is revolutionizing travel in Pakistan by combining cutting-edge AI technology with seamless booking experiences. We aim to make travel planning effortless, intelligent, and accessible to everyone.',
            ),

            _buildSection(
              'What We Offer',
              '**Flight Bookings** - Domestic and international flights with best prices\n\n'
                  '**Train Reservations** - Pakistan Railways booking made easy\n\n'
                  '**Hotel Bookings** - Wide selection of accommodations\n\n'
                  '**AI Travel Assistant** - Smart recommendations and 24/7 support\n\n'
                  '**Weather Updates** - Real-time weather for your destinations\n\n'
                  '**Healthcare Services** - Travel health tips and medical assistance',
            ),

            _buildSection(
              'Why Choose Us',
              '- **Best Prices**: We compare hundreds of options to find you the best deals\n\n'
                  '- **24/7 Support**: Our team is always ready to assist you\n\n'
                  '- **Secure Payments**: Your transactions are protected with bank-level security\n\n'
                  '- **Easy Cancellations**: Flexible policies with hassle-free refunds\n\n'
                  '- **AI-Powered**: Smart recommendations tailored to your preferences',
            ),

            _buildSection(
              'Our Vision',
              'We envision becoming Pakistan\'s leading AI-powered travel platform, making every journey seamless, safe, and memorable. Our goal is to empower travelers with technology that simplifies complex travel planning.',
            ),

            _buildSection(
              'Contact Information',
              'Email: info@travelloai.com\n'
                  'Phone: +92 (21) 1234-5678\n'
                  'Address: Karachi, Pakistan\n'
                  'Website: www.travelloai.com',
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                'Travel Smart with Travello AI',
                style: TravelloTheme.subtitle.copyWith(
                  color: TravelloTheme.primaryMain,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
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
