class Faq {
  Faq({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });

  String expandedValue;
  String headerValue;
  bool isExpanded;
}

final List<Faq> faqData = [
  Faq(
    expandedValue:
        'You can create an account by clicking the "Sign Up" button on the welcome screen. You can register using your email, Google, or Apple account. If you prefer to explore first, you can also continue as a guest.',
    headerValue: 'How do I create an account on Travello AI?',
  ),
  Faq(
    expandedValue:
        'To book a flight, tap "Create New Booking" on the home screen, select your departure and destination cities, choose your travel dates, and select the number of passengers. Then browse available flights and complete your booking.',
    headerValue: 'How do I book a flight?',
  ),
  Faq(
    expandedValue:
        'Yes! To book a train, tap the train icon in the top navigation to switch to train mode. Select your departure and arrival stations, choose your travel date, class preference, and number of passengers. Browse available trains and complete your booking.',
    headerValue: 'How do I book a train ticket?',
  ),
  Faq(
    expandedValue:
        'Yes! Travello AI now supports hotel bookings. Navigate to the Hotels section, search for your destination, select check-in and check-out dates, choose the number of guests, browse available hotels, select your preferred room type, and complete your booking.',
    headerValue: 'Can I book hotels on Travello AI?',
  ),
  Faq(
    expandedValue:
        'You can view all your bookings by tapping "My Bookings" in the bottom navigation bar. This will show you all your past and upcoming trips including flights, trains, and hotels with detailed booking information. You can filter by booking type.',
    headerValue: 'Where can I see my bookings?',
  ),
  Faq(
    expandedValue:
        'Yes! Travello AI supports flights, trains, and hotels. You can switch between modes using the icons in the top navigation. Each mode offers tailored search and booking options designed specifically for that travel type.',
    headerValue: 'Can I book trains and hotels as well as flights?',
  ),
  Faq(
    expandedValue:
        'You can cancel your booking from the "My Bookings" section. Select the booking you want to cancel and follow the cancellation process. Note that cancellation policies vary by airline, railway, hotel, and fare type. Hotels typically allow cancellation up to 24 hours before check-in.',
    headerValue: 'How do I cancel my booking?',
  ),
  Faq(
    expandedValue:
        'Travello AI accepts all major credit cards, debit cards, and digital payment methods including JazzCash, Easypaisa, and bank transfers. All payments are processed securely through our encrypted payment gateway with PCI DSS compliance.',
    headerValue: 'What payment methods are accepted?',
  ),
  Faq(
    expandedValue:
        'After completing your booking, you will receive a confirmation email with your e-ticket/booking confirmation. For flights, you\'ll get a boarding pass. For trains, you\'ll receive an e-ticket with QR code. For hotels, you\'ll get a booking confirmation voucher. You can also access all documents anytime from the "My Bookings" section and download them as PDF.',
    headerValue: 'How do I get my ticket after booking?',
  ),
  Faq(
    expandedValue:
        'Yes, you can modify certain booking details like passenger names, contact information, or travel dates (subject to airline, railway, or hotel policies) from the "My Bookings" section. Flight and train modifications may have restrictions. Hotel modifications are typically allowed up to 24 hours before check-in. Additional charges may apply.',
    headerValue: 'Can I modify my booking after confirmation?',
  ),
  Faq(
    expandedValue:
        'Travello AI offers three booking modes: Guest Mode (no login required), Email/Password registration, and Social Login (Google/Apple). In Guest Mode, your bookings are stored locally. For full features like booking history sync across devices and profile management, create an account.',
    headerValue: 'What are the different login options available?',
  ),
  Faq(
    expandedValue:
        'Your booking reference (PNR) is a unique code generated for each booking. For flights and trains, it starts with the booking type prefix. For hotels, it starts with "HTL". You can find it in your booking confirmation email, booking details screen, and on your e-ticket/voucher.',
    headerValue: 'What is a booking reference and where can I find it?',
  ),
  Faq(
    expandedValue:
        'For trains, you can choose between different classes like Economy, Business, and AC Sleeper. Each class offers different comfort levels and pricing. You can also select seat preferences during booking and view the coach layout.',
    headerValue: 'What train classes are available?',
  ),
  Faq(
    expandedValue:
        'Hotel bookings allow you to search by city or hotel name, filter by star rating, price range, and amenities. You can add extras like breakfast, airport transfer, and late checkout during booking. Each hotel displays photos, reviews, and detailed information.',
    headerValue: 'What features are available for hotel bookings?',
  ),
  Faq(
    expandedValue:
        'Yes! Travello AI provides personalized location-based suggestions. When you allow location access, the app shows nearby airports, train stations, popular destinations, and recommended hotels based on your current location.',
    headerValue: 'Does Travello AI provide location-based suggestions?',
  ),
  Faq(
    expandedValue:
        'You can download your booking documents as PDF by opening your booking details and tapping the download button. For flights, you get e-tickets and boarding passes. For trains, you get railway e-tickets with QR codes. For hotels, you get tax invoices and booking confirmations.',
    headerValue: 'How do I download my booking receipts and invoices?',
  ),
  Faq(
    expandedValue:
        'Yes! Travello AI offers smart add-ons like destination weather updates, quick actions for sharing bookings, travel insurance options, and enhanced journey features. You can access these from your booking confirmation screen.',
    headerValue: 'Are there any additional features or add-ons?',
  ),
  Faq(
    expandedValue:
        'Our 24/7 customer support team is available to help you. Tap "Contact Us" on any help screen or navigate to Profile > Help & Support. You can reach us via email at support@travelloai.com or call our helpline for immediate assistance.',
    headerValue: 'How do I contact customer support?',
  ),
];
