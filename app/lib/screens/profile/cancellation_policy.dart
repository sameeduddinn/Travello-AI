import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CancellationPolicy extends StatelessWidget {
  const CancellationPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('Cancellation Policy', style: TravelloTheme.subtitle),
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
              'Cancellation & Refund Policy',
              style: TravelloTheme.title.copyWith(
                color: TravelloTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective from March 2026',
              style: TravelloTheme.caption.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Flight Cancellations',
              '**Within 24 Hours of Booking:**\n'
                  '• Full refund if cancelled within 24 hours of booking (if booked at least 7 days before departure)\n'
                  '• Processing fee: PKR 500\n\n'
                  '**More than 7 Days Before Departure:**\n'
                  '• Cancellation fee: PKR 2,500 + airline charges\n'
                  '• Refund timeline: 7-14 business days\n\n'
                  '**3-7 Days Before Departure:**\n'
                  '• Cancellation fee: PKR 5,000 + airline charges\n'
                  '• Refund: 50% of base fare\n\n'
                  '**Less than 3 Days Before Departure:**\n'
                  '• Cancellation fee: PKR 8,000 + airline charges\n'
                  '• Refund: 25% of base fare',
            ),
            _buildSection(
              'Train Cancellations',
              '**More than 48 Hours Before Departure:**\n'
                  '• Cancellation fee: PKR 200 per ticket\n'
                  '• Refund: 90% of ticket fare\n\n'
                  '**24-48 Hours Before Departure:**\n'
                  '• Cancellation fee: PKR 500 per ticket\n'
                  '• Refund: 70% of ticket fare\n\n'
                  '**Less than 24 Hours:**\n'
                  '• Cancellation fee: PKR 1,000 per ticket\n'
                  '• Refund: 30% of ticket fare\n\n'
                  '**After Departure:**\n'
                  '• No refund available',
            ),
            _buildSection(
              'Hotel Cancellations',
              '**Free Cancellation:**\n'
                  '• Cancel up to 48 hours before check-in for full refund (where applicable)\n\n'
                  '**Standard Cancellation:**\n'
                  '• 24-48 hours before check-in: 50% refund\n'
                  '• Less than 24 hours: No refund\n\n'
                  '**Note:** Cancellation policies vary by hotel. Please check specific hotel policies before booking.',
            ),
            _buildSection(
              'Refund Process',
              '1. Submit cancellation request through app or website\n'
                  '2. Cancellation will be processed within 24 hours\n'
                  '3. Refund will be initiated within 3-5 business days\n'
                  '4. Credit to original payment method: 7-14 business days\n'
                  '5. SMS/Email notification upon successful refund',
            ),
            _buildSection(
              'Important Notes',
              '• Refund amounts exclude payment gateway charges\n'
                  '• Special fare tickets may be non-refundable\n'
                  '• Group bookings have different cancellation policies\n'
                  '• Travel insurance is recommended for flexibility\n'
                  '• Airline/railway imposed charges are non-refundable',
            ),
            _buildSection(
              'Contact for Cancellations',
              'Email: cancellations@travelloai.com\n'
                  'Phone: +92 (21) 1234-5678 (24/7 Support)\n'
                  'WhatsApp: +92 300 1234567',
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
