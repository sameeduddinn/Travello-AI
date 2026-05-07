import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TermsCondition extends StatelessWidget {
  const TermsCondition({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('Terms & Conditions', style: TravelloTheme.subtitle),
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
              'Travello AI – Terms & Conditions',
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
            const SizedBox(height: 16),
            Text(
              'Welcome to Travello AI, an AI-powered travel booking platform for Pakistan domestic travel services. By using our platform, you agree to these terms and conditions.',
              style: TravelloTheme.paragraph.copyWith(
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. About Travello AI',
              'Travello AI is an intelligent travel aggregation and booking platform that uses AI-assisted search and recommendation technology to help users find the most suitable travel options within Pakistan.\n\n'
              'Our services include:\n'
              '• Domestic flight booking (PIA, Airblue, SereneAir, AirSial)\n'
              '• Pakistan Railways train booking\n'
              '• Hotel discovery and reservation\n'
              '• AI-based travel recommendations\n'
              '• Price comparisons across travel providers\n'
              '• Weather updates and travel alerts\n'
              '• Healthcare and travel assistance\n\n'
              'Travello AI acts primarily as an intermediary platform connecting users with airlines, Pakistan Railways, hotels, and third-party booking partners.',
            ),
            
            _buildSection(
              '2. User Eligibility',
              'By using Travello AI, you confirm that:\n\n'
              '• You are at least 18 years old, or using the platform under supervision of a guardian\n'
              '• The information you provide during registration and booking is accurate and complete\n'
              '• You possess valid CNIC or identification documents\n'
              '• You will use the platform only for lawful travel purposes within Pakistan\n\n'
              'Travello AI reserves the right to suspend or terminate accounts that provide false information or misuse the platform.',
            ),
            
            _buildSection(
              '3. Account Registration',
              'To access booking features, users may need to create an account.\n\n'
              'During registration, you may be required to provide:\n'
              '• Full Name (as per CNIC)\n'
              '• Email Address\n'
              '• Phone Number\n'
              '• CNIC Number (for domestic travel verification)\n'
              '• Passenger details for bookings\n\n'
              'Users are responsible for:\n'
              '• Maintaining the confidentiality of their login credentials\n'
              '• Ensuring all stored traveler information is accurate\n'
              '• Updating personal information when required\n\n'
              'Travello AI is not responsible for unauthorized access resulting from user negligence.',
            ),
            
            _buildSection(
              '4. Booking Services for Pakistan Domestic Travel',
              'Travello AI allows users to search and book domestic travel services within Pakistan.\n\n'
              '**4.1 Domestic Flight Bookings**\n'
              '• All domestic flights operate under Pakistan Civil Aviation Authority (PCAA) regulations\n'
              '• Airlines include PIA, Airblue, SereneAir, AirSial, and other PCAA-licensed carriers\n'
              '• Valid CNIC is mandatory for all passengers\n'
              '• Check-in opens 2-3 hours before departure\n'
              '• Baggage allowance varies by airline and fare class\n\n'
              '**4.2 Pakistan Railways Bookings**\n'
              '• Train tickets are subject to Pakistan Railways terms and conditions\n'
              '• Categories: Business Class, AC Sleeper, AC Standard, Economy\n'
              '• Valid CNIC required for booking confirmation\n'
              '• Chart preparation: 30 minutes before departure\n'
              '• Seat assignments are subject to availability\n\n'
              '**4.3 Hotel Reservations**\n'
              '• Hotels comply with Pakistan tourism and hospitality standards\n'
              '• Guests must present valid CNIC at check-in\n'
              '• Check-in times typically 2:00 PM, check-out 12:00 PM\n'
              '• Hotel policies may vary by property\n\n'
              'Important: Travello AI does not operate airlines, railways, or hotels. The actual service is provided by third-party travel providers. Each provider may have their own terms and policies.',
            ),
            
            _buildSection(
              '5. Pricing and Availability',
              'All prices shown on Travello AI are:\n\n'
              '• Displayed in Pakistani Rupees (PKR)\n'
              '• Based on real-time data from travel providers\n'
              '• Subject to availability at the time of booking\n'
              '• May include taxes and applicable service fees\n\n'
              'Prices may change due to:\n'
              '• Provider updates\n'
              '• Seat or room availability\n'
              '• Dynamic pricing algorithms\n'
              '• Government taxes and regulatory fees\n\n'
              'Travello AI cannot guarantee that a displayed price will remain available until the booking is completed.',
            ),
            
            _buildSection(
              '6. Payments',
              'Travello AI supports secure payment processing through approved payment providers.\n\n'
              'Available payment methods may include:\n'
              '• Credit / Debit Cards (Visa, MasterCard, UnionPay)\n'
              '• Bank transfers\n\n'
              'When making a payment:\n'
              '• You authorize Travello AI or its partners to process the transaction\n'
              '• All payments must be completed before a booking is confirmed\n'
              '• Payment gateway charges may apply\n\n'
              'Travello AI does not store full payment card details and uses secure payment processing systems compliant with PCI-DSS standards.',
            ),
            
            _buildSection(
              '7. Cancellations and Refunds',
              'Cancellation and refund policies depend on the individual travel provider and booking type.\n\n'
              '**Flight Cancellations:**\n'
              '• Within 24 hours of booking: Full refund (if booked at least 7 days before departure)\n'
              '• More than 7 days before departure: Cancellation fee PKR 2,500 + airline charges\n'
              '• 3-7 days before: Cancellation fee PKR 5,000 + 50% of fare\n'
              '• Less than 3 days: Cancellation fee PKR 8,000 + 75% of fare\n\n'
              '**Train Cancellations:**\n'
              '• More than 48 hours: PKR 200 fee, 90% refund\n'
              '• 24-48 hours: PKR 500 fee, 70% refund\n'
              '• Less than 24 hours: PKR 1,000 fee, 30% refund\n'
              '• After departure: No refund\n\n'
              '**Hotel Cancellations:**\n'
              '• Vary by property (typically 48 hours free cancellation)\n\n'
              'Refund processing:\n'
              '• Cancellation requests processed within 24 hours\n'
              '• Refund initiated within 3-5 business days\n'
              '• Credit to original payment method: 7-14 business days\n\n'
              'For detailed cancellation policies, please refer to our Cancellation Policy page.',
            ),
            
            _buildSection(
              '8. Travel Documents and Requirements',
              'Users are responsible for ensuring they possess all required travel documents:\n\n'
              '**For Domestic Flights:**\n'
              '• Valid CNIC (original)\n'
              '• For minors: Birth certificate or Form-B\n'
              '• E-ticket or booking confirmation\n\n'
              '**For Train Travel:**\n'
              '• Valid CNIC (original)\n'
              '• Reservation slip or e-ticket\n\n'
              '**For Hotel Check-in:**\n'
              '• Valid CNIC or passport\n'
              '• Booking confirmation\n\n'
              'Travello AI is not responsible for denied boarding or entry due to missing or invalid documents.',
            ),
            
            _buildSection(
              '9. AI Recommendations and Personalization',
              'Travello AI uses artificial intelligence algorithms to provide:\n\n'
              '• Travel suggestions based on your preferences\n'
              '• Price insights and fare predictions\n'
              '• Personalized deals and offers\n'
              '• Route recommendations\n'
              '• Weather-based travel advice\n\n'
              'These recommendations are intended to assist users but do not guarantee the best or lowest possible price. Users are encouraged to review all details before booking.',
            ),
            
            _buildSection(
              '10. Price Alerts and Notifications',
              'Users may opt to receive:\n\n'
              '• Price drop alerts\n'
              '• Booking reminders\n'
              '• Flight status updates\n'
              '• Train delay notifications\n'
              '• Promotional offers\n'
              '• Weather alerts\n\n'
              'Notifications may be delivered through:\n'
              '• Mobile push notifications\n'
              '• Email\n'
              '• SMS messages\n\n'
              'Users may disable notifications in their account settings.',
            ),
            
            _buildSection(
              '11. User Conduct',
              'Users agree not to:\n\n'
              '• Use the platform for fraudulent bookings\n'
              '• Attempt to manipulate pricing systems\n'
              '• Upload malicious software or harmful content\n'
              '• Violate any applicable laws or regulations of Pakistan\n'
              '• Provide false identification or travel documents\n'
              '• Resell tickets without authorization\n\n'
              'Travello AI reserves the right to restrict or terminate access for violations.',
            ),
            
            _buildSection(
              '12. Limitation of Liability',
              'Travello AI is not liable for:\n\n'
              '• Delays or cancellations by airlines or Pakistan Railways\n'
              '• Changes made by service providers\n'
              '• Travel disruptions due to weather, strikes, or force majeure events\n'
              '• Losses resulting from incorrect user information\n'
              '• Actions or omissions of hotels, airlines, or transport providers\n'
              '• Government-imposed travel restrictions or regulations\n\n'
              'Travello AI acts as a facilitator platform connecting users to travel providers. The primary service contract is between the user and the respective airline, railway, or hotel provider.',
            ),
            
            _buildSection(
              '13. Pakistan-Specific Regulations',
              '**13.1 Civil Aviation Authority (PCAA) Compliance**\n'
              '• All flight bookings comply with PCAA regulations\n'
              '• Baggage rules follow PCAA domestic standards\n'
              '• Security protocols as per PCAA requirements\n\n'
              '**13.2 Pakistan Railways Regulations**\n'
              '• Bookings follow Pakistan Railways reservation policies\n'
              '• Seat allocation subject to PR chart preparation\n'
              '• Refunds processed as per PR refund rules\n\n'
              '**13.3 Hotel Standards**\n'
              '• Hotels registered with tourism authorities\n'
              '• Compliance with local hospitality regulations\n'
              '• Guest safety and security standards',
            ),
            
            _buildSection(
              '14. Intellectual Property',
              'All content on Travello AI, including:\n\n'
              '• Platform design and user interface\n'
              '• Travello AI logo and branding\n'
              '• AI algorithms and technology\n'
              '• Text, graphics, and images\n'
              '• Software components\n\n'
              'is the intellectual property of Travello AI and may not be reproduced, distributed, or used without permission.',
            ),
            
            _buildSection(
              '15. Privacy and Data Protection',
              'Travello AI collects and processes user data according to its Privacy Policy.\n\n'
              'User data may be used for:\n'
              '• Booking processing and confirmation\n'
              '• Personalization and AI recommendations\n'
              '• Platform improvements\n'
              '• Customer support\n'
              '• Compliance with travel regulations\n\n'
              'Sensitive information (CNIC, payment details) is handled using secure encryption and industry-standard data protection practices.',
            ),
            
            _buildSection(
              '16. Platform Availability',
              'Travello AI aims to maintain reliable platform access 24/7 but cannot guarantee uninterrupted service.\n\n'
              'Service may be temporarily affected by:\n'
              '• Scheduled maintenance\n'
              '• Technical updates\n'
              '• Server issues\n'
              '• Internet connectivity problems\n\n'
              'We will make reasonable efforts to notify users of planned maintenance.',
            ),
            
            _buildSection(
              '17. Changes to Terms',
              'Travello AI reserves the right to modify these Terms and Conditions at any time.\n\n'
              'Updated versions will be published on the platform with the revised "Last Updated" date. Continued use of the platform indicates acceptance of the updated terms.\n\n'
              'Users will be notified of significant changes via email or platform notification.',
            ),
            
            _buildSection(
              '18. Governing Law',
              'These Terms and Conditions shall be governed by and interpreted in accordance with the laws of the Islamic Republic of Pakistan.\n\n'
              'Any disputes arising from the use of the platform shall be resolved through:\n'
              '• Mutual discussion and negotiation\n'
              '• Mediation where appropriate\n'
              '• Legal proceedings in Pakistani courts if necessary\n\n'
              'The courts of Pakistan shall have exclusive jurisdiction over any disputes.',
            ),
            
            _buildSection(
              '19. Contact Information',
              'For questions regarding these Terms & Conditions, users may contact Travello AI support:\n\n'
              '**Email:** support@travelloai.com\n'
              '**Phone:** +92 (21) 1234-5678 (24/7 Support)\n'
              '**WhatsApp:** +92 300 1234567\n'
              '**Address:** Travello AI, Karachi, Pakistan\n\n'
              '**Customer Support Hours:**\n'
              '• 24/7 for urgent booking issues\n'
              '• 9:00 AM - 9:00 PM for general inquiries',
            ),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TravelloTheme.primaryMain.withValues(alpha: 0.3)),
              ),
              child: Text(
                'By using Travello AI, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                style: TravelloTheme.paragraph.copyWith(
                  fontWeight: FontWeight.w600,
                  color: TravelloTheme.primaryDark,
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