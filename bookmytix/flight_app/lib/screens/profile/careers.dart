import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class Careers extends StatelessWidget {
  const Careers({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('Careers', style: TravelloTheme.subtitle),
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
              'Join Our Team',
              style: TravelloTheme.title.copyWith(
                color: TravelloTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Build the future of travel with Travello AI',
              style: TravelloTheme.subtitle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Why Work With Us?',
              '**Innovation**: Work on cutting-edge AI and travel technology\n\n'
                  '**Impact**: Help millions of travelers plan better journeys\n\n'
                  '**Growth**: Continuous learning and career development\n\n'
                  '**Culture**: Collaborative and inclusive environment\n\n'
                  '**Benefits**: Competitive salary, health insurance, and perks\n\n'
                  '**Work-Life Balance**: Flexible hours and remote options',
            ),
            const SizedBox(height: 24),
            Text(
              'Open Positions',
              style: TravelloTheme.subtitle.copyWith(
                fontWeight: FontWeight.bold,
                color: TravelloTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            _buildJobCard(
              'Senior Flutter Developer',
              'Engineering',
              'Full-time',
              'Karachi, Pakistan',
              Icons.code,
            ),
            _buildJobCard(
              'AI/ML Engineer',
              'Engineering',
              'Full-time',
              'Remote',
              Icons.psychology,
            ),
            _buildJobCard(
              'Product Manager',
              'Product',
              'Full-time',
              'Karachi, Pakistan',
              Icons.dashboard,
            ),
            _buildJobCard(
              'UI/UX Designer',
              'Design',
              'Full-time',
              'Hybrid',
              Icons.palette,
            ),
            _buildJobCard(
              'Customer Support Specialist',
              'Support',
              'Full-time',
              'Karachi, Pakistan',
              Icons.support_agent,
            ),
            _buildJobCard(
              'Digital Marketing Manager',
              'Marketing',
              'Full-time',
              'Karachi, Pakistan',
              Icons.campaign,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Application Process',
              '1. **Submit Application**: Send your resume to careers@travelloai.com\n\n'
                  '2. **Initial Screening**: Our HR team will review your profile\n\n'
                  '3. **Technical Assessment**: Complete a relevant skills test\n\n'
                  '4. **Interviews**: Meet with team leads and managers\n\n'
                  '5. **Offer**: Receive and accept your offer letter',
            ),
            _buildSection(
              'Internship Program',
              'We offer internship opportunities for students and fresh graduates. Gain hands-on experience working on real projects with mentorship from industry experts.',
            ),
            _buildSection(
              'Contact HR',
              'Email: careers@travelloai.com\n'
                  'Phone: +92 (21) 1234-5678\n'
                  'Office: Karachi, Pakistan',
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

  Widget _buildJobCard(
    String title,
    String department,
    String type,
    String location,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: TravelloTheme.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: TravelloTheme.primaryMain, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TravelloTheme.subtitle2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: TravelloTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$department • $type',
                  style: TravelloTheme.caption.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: spacingUnit(0.25)),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TravelloTheme.caption.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
