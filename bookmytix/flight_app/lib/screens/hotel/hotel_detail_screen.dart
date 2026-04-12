import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/models/room_type.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({super.key});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen>
    with SingleTickerProviderStateMixin {
  late Hotel hotel;
  late DateTime checkInDate;
  late DateTime checkOutDate;
  late int rooms;
  late int guests;

  int _currentImageIndex = 0;
  late TabController _tabController;
  RoomType? selectedRoom;
  double? finalPriceFromPackage;
  double? discountPct;

  // Sample room types (in a real app, these would come from the hotel data)
  List<RoomType> availableRooms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final args = Get.arguments as Map? ?? {};
    hotel = args['hotel'] as Hotel;
    checkInDate = args['checkInDate'] as DateTime;
    checkOutDate = args['checkOutDate'] as DateTime;
    rooms = args['rooms'] as int;
    guests = args['guests'] as int;
    finalPriceFromPackage =
        (args['finalPriceFromPackage'] as num?)?.toDouble() ??
            (args['finalPrice'] as num?)?.toDouble();
    discountPct = (args['discountPct'] as num?)?.toDouble();

    _initializeRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeRooms() {
    // Use regular hotel pricing

    // If hotel has specific rooms defined, use them
    if (hotel.rooms != null && hotel.rooms!.isNotEmpty) {
      availableRooms = hotel.rooms!
          .map((r) => RoomType(
                id: r.id,
                name: r.name,
                description: r.description,
                pricePerNight: r.pricePerNight,
                maxOccupancy: r.maxOccupancy,
                bedCount: r.bedCount,
                bedType: r.bedType,
                sizeInSqFt: r.sizeInSqFt,
                amenities: r.amenities,
                images: r.images.isNotEmpty ? r.images : hotel.images,
                hasCityView: r.hasCityView,
                hasBalcony: r.hasBalcony,
                isRefundable: r.isRefundable,
                cancellationPolicy: r.cancellationPolicy,
                breakfastIncluded: r.breakfastIncluded,
                roomsAvailable: r.roomsAvailable,
              ))
          .toList();
      return;
    }

    final base = hotel.pricePerNight;
    final cat = hotel.category;

    // Mountain/tourist cities get nature-themed room names
    final bool isMountain = [
      'Skardu',
      'Hunza',
      'Gilgit',
      'Swat',
      'Murree',
      'Abbottabad'
    ].contains(hotel.city);

    if (isMountain) {
      if (cat.contains('5')) {
        availableRooms = [
          RoomType(
              id: '${hotel.id}-1',
              name: 'Standard Mountain View Room',
              description:
                  'Cozy room with a stunning mountain panorama, premium bedding and all modern comforts.',
              pricePerNight: base,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 350,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '42" Flat-screen TV',
                'Private Bathroom',
                'Mini Bar',
                'Heating'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 8),
          RoomType(
              id: '${hotel.id}-2',
              name: 'Deluxe Valley View Room',
              description:
                  'Spacious deluxe room with floor-to-ceiling windows overlooking the valley, premium furnishings.',
              pricePerNight: base * 1.3,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 430,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '55" Flat-screen TV',
                'Mini Bar',
                'In-room Safe',
                'Coffee Maker',
                'Bathrobe & Slippers',
                'Heating'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: false,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 48 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 6),
          RoomType(
              id: '${hotel.id}-3',
              name: 'Balcony Suite with Mountain View',
              description:
                  'Luxurious suite with private balcony, a sitting area and breathtaking 270° mountain views.',
              pricePerNight: base * 1.65,
              maxOccupancy: 3,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 600,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '65" Flat-screen TV',
                'Mini Bar',
                'In-room Safe',
                'Private Balcony',
                'Sitting Area',
                'Bathrobe & Slippers',
                'Heating',
                'Complimentary Fruits'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: true,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 48 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 4),
          RoomType(
              id: '${hotel.id}-4',
              name: 'Executive Mountain Suite',
              description:
                  'Elegant suite with panoramic mountain vistas, a full living room, dining area and dedicated butler service.',
              pricePerNight: base * 2.2,
              maxOccupancy: 4,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 950,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '65" Flat-screen TV',
                'Full Mini Bar',
                'In-room Safe',
                'Private Balcony',
                'Living Room',
                'Dining Area',
                'Nespresso Machine',
                'Bathrobe & Slippers',
                'Butler Service',
                'Heating'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: true,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 72 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 2),
          RoomType(
              id: '${hotel.id}-5',
              name: 'Presidential Suite',
              description:
                  'The ultimate alpine escape — sprawling two-bedroom suite with a panoramic terrace, grand living room and private plunge pool.',
              pricePerNight: base * 3.5,
              maxOccupancy: 4,
              bedCount: 2,
              bedType: '2 King Beds',
              sizeInSqFt: 2000,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                'Multiple 65" TVs',
                'Full Bar',
                'In-room Safe',
                'Private Terrace',
                'Plunge Pool',
                'Nespresso & Tea Station',
                'Grand Living Room',
                'Dining Area',
                'Dedicated Butler 24/7',
                'Airport Transfer',
                'Heating'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: true,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 72 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 1),
        ];
      } else if (cat.contains('4')) {
        availableRooms = [
          RoomType(
              id: '${hotel.id}-1',
              name: 'Standard Double Room',
              description:
                  'Comfortable double room with garden or mountain view, clean modern décor.',
              pricePerNight: base,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'Double Bed',
              sizeInSqFt: 240,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '40" Flat-screen TV',
                'Work Desk',
                'Private Bathroom',
                'Heating',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 10),
          RoomType(
              id: '${hotel.id}-2',
              name: 'Deluxe Mountain View Room',
              description:
                  'Upgraded room with direct mountain view, larger bed and enhanced amenities.',
              pricePerNight: base * 1.25,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 300,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '50" Flat-screen TV',
                'Work Desk',
                'In-room Safe',
                'Coffee Maker',
                'Heating',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: false,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 48 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 7),
          RoomType(
              id: '${hotel.id}-3',
              name: 'Superior Valley View Room',
              description:
                  'Best room category — commanding valley views, premium bedding and complimentary breakfast.',
              pricePerNight: base * 1.5,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 350,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '50" Flat-screen TV',
                'Mini Bar',
                'In-room Safe',
                'Coffee Maker',
                'Bathrobe',
                'Heating',
                'Premium Toiletries'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: true,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 48 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 4),
          RoomType(
              id: '${hotel.id}-4',
              name: 'Family Room',
              description:
                  'Spacious room with two double beds, ideal for families with mountain views.',
              pricePerNight: base * 1.7,
              maxOccupancy: 4,
              bedCount: 2,
              bedType: '2 Double Beds',
              sizeInSqFt: 420,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '50" Flat-screen TV',
                'Work Desk',
                'In-room Safe',
                'Heating',
                'Extra Pillows & Blankets',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 3),
          RoomType(
              id: '${hotel.id}-5',
              name: 'Deluxe Suite',
              description:
                  'Well-appointed suite with a sitting room, valley-facing balcony and luxury mountain resort feel.',
              pricePerNight: base * 2.0,
              maxOccupancy: 3,
              bedCount: 1,
              bedType: 'King Bed',
              sizeInSqFt: 550,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '55" Flat-screen TV',
                'Full Mini Bar',
                'In-room Safe',
                'Living Room',
                'Private Balcony',
                'Nespresso Machine',
                'Bathrobe & Slippers',
                'Heating'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: true,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 72 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 2),
        ];
      } else if (cat.contains('3')) {
        availableRooms = [
          RoomType(
              id: '${hotel.id}-1',
              name: 'Standard Single Room',
              description:
                  'Simple and clean single room with garden view, ideal for solo travellers.',
              pricePerNight: base * 0.8,
              maxOccupancy: 1,
              bedCount: 1,
              bedType: 'Single Bed',
              sizeInSqFt: 160,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '32" TV',
                'Private Bathroom',
                'Heating',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 8),
          RoomType(
              id: '${hotel.id}-2',
              name: 'Standard Twin Room',
              description:
                  'Two single beds side by side — perfect for friends or colleagues exploring the mountains.',
              pricePerNight: base,
              maxOccupancy: 2,
              bedCount: 2,
              bedType: '2 Single Beds',
              sizeInSqFt: 200,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '32" TV',
                'Private Bathroom',
                'Heating',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 8),
          RoomType(
              id: '${hotel.id}-3',
              name: 'Mountain View Double Room',
              description:
                  'Double bed room with a picture-window view of the mountains, warm ambience.',
              pricePerNight: base * 1.2,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'Double Bed',
              sizeInSqFt: 220,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '40" TV',
                'Private Bathroom',
                'Heating',
                'Coffee Station',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 6),
          RoomType(
              id: '${hotel.id}-4',
              name: 'Family Room',
              description:
                  'Larger room with one double and one single bed, suitable for small families.',
              pricePerNight: base * 1.5,
              maxOccupancy: 3,
              bedCount: 2,
              bedType: 'Double + Single',
              sizeInSqFt: 280,
              amenities: [
                'Free WiFi',
                'Air Conditioning',
                '40" TV',
                'Private Bathroom',
                'Heating',
                'Extra Bedding',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 4),
        ];
      } else {
        // Budget mountain guesthouse
        availableRooms = [
          RoomType(
              id: '${hotel.id}-1',
              name: 'Economy Shared Room',
              description:
                  'Budget-friendly room with basic amenities, shared facilities available.',
              pricePerNight: base * 0.8,
              maxOccupancy: 1,
              bedCount: 1,
              bedType: 'Single Bed',
              sizeInSqFt: 100,
              amenities: ['Free WiFi', 'Heating', 'Shared Bathroom'],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: false,
              cancellationPolicy: 'Non-refundable',
              breakfastIncluded: false,
              roomsAvailable: 10),
          RoomType(
              id: '${hotel.id}-2',
              name: 'Standard Room',
              description:
                  'Cozy room with private bathroom and basic mountain retreat comforts.',
              pricePerNight: base,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'Double Bed',
              sizeInSqFt: 150,
              amenities: [
                'Free WiFi',
                'Heating',
                'Private Bathroom',
                'Basic Toiletries'
              ],
              images: hotel.images,
              hasCityView: false,
              hasBalcony: false,
              isRefundable: hotel.isRefundable,
              cancellationPolicy:
                  'Free cancellation up to 24 hours before check-in',
              breakfastIncluded: false,
              roomsAvailable: 8),
          RoomType(
              id: '${hotel.id}-3',
              name: 'Mountain View Room',
              description:
                  'Best room in the property with a mountain view, comfortable double bed.',
              pricePerNight: base * 1.3,
              maxOccupancy: 2,
              bedCount: 1,
              bedType: 'Double Bed',
              sizeInSqFt: 180,
              amenities: [
                'Free WiFi',
                'Heating',
                'Private Bathroom',
                '32" TV',
                'Toiletries'
              ],
              images: hotel.images,
              hasCityView: true,
              hasBalcony: false,
              isRefundable: true,
              cancellationPolicy:
                  'Free cancellation up to 48 hours before check-in',
              breakfastIncluded: true,
              roomsAvailable: 4),
        ];
      }
      return;
    }

    if (cat.contains('5')) {
      // ── 5-Star: Pakistan Hotel Association standard room types ──────────
      availableRooms = [
        RoomType(
          id: '${hotel.id}-1',
          name: 'Standard Room',
          description:
              'Well-appointed room with all essential luxury amenities and a comfortable king bed.',
          pricePerNight: base,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 350,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '42" Flat-screen TV',
            'Mini Bar',
            'In-room Safe',
            'Work Desk',
            'Premium Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 8,
        ),
        RoomType(
          id: '${hotel.id}-2',
          name: 'Deluxe Room',
          description:
              'Larger room with city views, premium furnishings and enhanced amenities.',
          pricePerNight: base * 1.3,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 430,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '55" Flat-screen TV',
            'Mini Bar',
            'In-room Safe',
            'Work Desk',
            'Coffee Maker',
            'Bathrobe & Slippers',
            'Premium Toiletries',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: false,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 6,
        ),
        RoomType(
          id: '${hotel.id}-3',
          name: 'Junior Suite',
          description:
              'Spacious suite with a separate sitting area, balcony and panoramic city views.',
          pricePerNight: base * 1.65,
          maxOccupancy: 3,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 600,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '65" Flat-screen TV',
            'Mini Bar',
            'In-room Safe',
            'Work Desk',
            'Coffee Maker',
            'Bathrobe & Slippers',
            'Sitting Area',
            'Premium Toiletries',
            'Complimentary Fruits',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: true,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 4,
        ),
        RoomType(
          id: '${hotel.id}-4',
          name: 'Executive Suite',
          description:
              'Luxury suite with a full living room, dining area and floor-to-ceiling panoramic windows.',
          pricePerNight: base * 2.2,
          maxOccupancy: 4,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 950,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '65" Flat-screen TV',
            'Full Mini Bar',
            'In-room Safe',
            'Work Desk',
            'Nespresso Machine',
            'Bathrobe & Slippers',
            'Living Room',
            'Dining Area',
            'Premium Toiletries',
            'Complimentary Fruits & Flowers',
            'Express Check-in/out',
            'Butler Service',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: true,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 72 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 2,
        ),
        RoomType(
          id: '${hotel.id}-5',
          name: 'Presidential Suite',
          description:
              'The pinnacle of luxury — a sprawling two-bedroom suite with a private terrace, grand living space and dedicated butler.',
          pricePerNight: base * 3.8,
          maxOccupancy: 4,
          bedCount: 2,
          bedType: '2 King Beds',
          sizeInSqFt: 2000,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            'Multiple 65" TVs',
            'Full Bar',
            'In-room Safe',
            'Private Office',
            'Nespresso & Tea Station',
            'Bathrobe & Slippers',
            'Grand Living Room',
            'Private Dining Room',
            'Luxury Toiletries',
            'Daily Fruits, Flowers & Chocolates',
            'Dedicated Butler 24/7',
            'Airport Transfer',
            'Private Terrace',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: true,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 72 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 1,
        ),
      ];
    } else if (cat.contains('4')) {
      // ── 4-Star ────────────────────────────────────────────────────────
      availableRooms = [
        RoomType(
          id: '${hotel.id}-1',
          name: 'Standard Double Room',
          description:
              'Comfortable double room with modern décor and all standard amenities.',
          pricePerNight: base,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'Double Bed',
          sizeInSqFt: 240,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '40" Flat-screen TV',
            'Work Desk',
            'In-room Safe',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 10,
        ),
        RoomType(
          id: '${hotel.id}-2',
          name: 'Twin Room',
          description:
              'Ideal for two travellers — two single beds with shared bathroom facilities.',
          pricePerNight: base * 1.05,
          maxOccupancy: 2,
          bedCount: 2,
          bedType: '2 Single Beds',
          sizeInSqFt: 250,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '40" Flat-screen TV',
            'Work Desk',
            'In-room Safe',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 8,
        ),
        RoomType(
          id: '${hotel.id}-3',
          name: 'Superior Room',
          description:
              'Upgraded room with a larger bed, better view and additional comforts.',
          pricePerNight: base * 1.25,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 310,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '50" Flat-screen TV',
            'Mini Bar',
            'Work Desk',
            'In-room Safe',
            'Coffee Maker',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: false,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 6,
        ),
        RoomType(
          id: '${hotel.id}-4',
          name: 'Deluxe Room',
          description:
              'Spacious room with premium bedding, balcony and enhanced city views.',
          pricePerNight: base * 1.5,
          maxOccupancy: 3,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 380,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '50" Flat-screen TV',
            'Mini Bar',
            'Work Desk',
            'In-room Safe',
            'Coffee Maker',
            'Bathrobe & Slippers',
            'Premium Toiletries',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: true,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 4,
        ),
        RoomType(
          id: '${hotel.id}-5',
          name: 'Suite',
          description:
              'Well-appointed suite with a separate living room and premium city-view balcony.',
          pricePerNight: base * 2.0,
          maxOccupancy: 4,
          bedCount: 1,
          bedType: 'King Bed',
          sizeInSqFt: 600,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '55" Flat-screen TV',
            'Full Mini Bar',
            'Work Desk',
            'In-room Safe',
            'Nespresso Machine',
            'Bathrobe & Slippers',
            'Living Room',
            'Premium Toiletries',
            'Complimentary Breakfast',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: true,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 72 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 2,
        ),
      ];
    } else if (cat.contains('3')) {
      // ── 3-Star ────────────────────────────────────────────────────────
      availableRooms = [
        RoomType(
          id: '${hotel.id}-1',
          name: 'Standard Single Room',
          description:
              'Cozy single room with all essential amenities for a comfortable stay.',
          pricePerNight: base * 0.8,
          maxOccupancy: 1,
          bedCount: 1,
          bedType: 'Single Bed',
          sizeInSqFt: 160,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '32" Flat-screen TV',
            'Work Desk',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 12,
        ),
        RoomType(
          id: '${hotel.id}-2',
          name: 'Standard Double Room',
          description:
              'Comfortable double room with a private bathroom and essential amenities.',
          pricePerNight: base,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'Double Bed',
          sizeInSqFt: 200,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '32" Flat-screen TV',
            'Work Desk',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 10,
        ),
        RoomType(
          id: '${hotel.id}-3',
          name: 'Superior Double Room',
          description:
              'A step up with better furnishings, improved bedding and a partial view.',
          pricePerNight: base * 1.25,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'Queen Bed',
          sizeInSqFt: 240,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '40" Flat-screen TV',
            'Work Desk',
            'In-room Safe',
            'Coffee Station',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: false,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 6,
        ),
        RoomType(
          id: '${hotel.id}-4',
          name: 'Family Room',
          description:
              'Spacious room suitable for families with two double beds.',
          pricePerNight: base * 1.5,
          maxOccupancy: 4,
          bedCount: 2,
          bedType: '2 Double Beds',
          sizeInSqFt: 300,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '40" Flat-screen TV',
            'Work Desk',
            'Toiletries',
            'Extra Pillows & Blankets',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 4,
        ),
      ];
    } else {
      // ── Budget Hotel ─────────────────────────────────────────────────
      availableRooms = [
        RoomType(
          id: '${hotel.id}-1',
          name: 'Economy Room',
          description: 'Clean and simple room with all the basics covered.',
          pricePerNight: base * 0.8,
          maxOccupancy: 1,
          bedCount: 1,
          bedType: 'Single Bed',
          sizeInSqFt: 120,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '24" TV',
            'Shared Bathroom',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: false,
          cancellationPolicy: 'Non-refundable',
          breakfastIncluded: false,
          roomsAvailable: 15,
        ),
        RoomType(
          id: '${hotel.id}-2',
          name: 'Standard Room',
          description:
              'Affordable room with private bathroom and basic amenities.',
          pricePerNight: base,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'Double Bed',
          sizeInSqFt: 160,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '32" TV',
            'Private Bathroom',
            'Basic Toiletries',
          ],
          images: hotel.images,
          hasCityView: false,
          hasBalcony: false,
          isRefundable: hotel.isRefundable,
          cancellationPolicy:
              'Free cancellation up to 24 hours before check-in',
          breakfastIncluded: false,
          roomsAvailable: 10,
        ),
        RoomType(
          id: '${hotel.id}-3',
          name: 'Deluxe Room',
          description:
              'Best room in the property — larger bed, better bedding and flat-screen TV.',
          pricePerNight: base * 1.3,
          maxOccupancy: 2,
          bedCount: 1,
          bedType: 'Queen Bed',
          sizeInSqFt: 200,
          amenities: [
            'Free WiFi',
            'Air Conditioning',
            '40" Flat-screen TV',
            'Private Bathroom',
            'In-room Safe',
            'Toiletries',
          ],
          images: hotel.images,
          hasCityView: true,
          hasBalcony: false,
          isRefundable: true,
          cancellationPolicy:
              'Free cancellation up to 48 hours before check-in',
          breakfastIncluded: true,
          roomsAvailable: 5,
        ),
      ];
    }
  }

  int get numberOfNights {
    return checkOutDate.difference(checkInDate).inDays;
  }

  double get totalPrice {
    // BUG 14 FIX: if a discount was passed from package listing, honour it.
    // finalPriceFromPackage already includes rooms × nights × discount.
    if (finalPriceFromPackage != null && selectedRoom == null) {
      return finalPriceFromPackage!;
    }
    final roomPrice = selectedRoom?.pricePerNight ?? hotel.pricePerNight;
    final base = roomPrice * numberOfNights * rooms;
    // Apply discount from package listing if a room hasn't been manually chosen
    if (discountPct != null && discountPct! > 0 && selectedRoom == null) {
      return base * (1 - discountPct! / 100);
    }
    return base;
  }

  void _proceedToBooking() async {
    final messenger = ScaffoldMessenger.of(context);
    // Auth gate at booking intent — browsing hotel details was free
    final isGuest = await AuthService.isGuestMode();
    if (isGuest && mounted) {
      AuthGateSheet.show(context, action: 'to book this hotel');
      return;
    }
    if (selectedRoom == null) {
      // Guide user to the Rooms tab instead of just showing a snackbar
      _tabController.animateTo(1);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Choose a room from the Rooms tab to continue',
              style: TextStyle(fontSize: 14)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Occupancy check: total guests must not exceed maxOccupancy × rooms
    final maxCapacity = selectedRoom!.maxOccupancy * rooms;
    if (guests > maxCapacity) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This room holds $maxCapacity guest${maxCapacity == 1 ? '' : 's'} max ($rooms room${rooms == 1 ? '' : 's'} × ${selectedRoom!.maxOccupancy} per room). '
            'Please add more rooms or choose a larger room type.',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    Get.toNamed(
      '/hotel-guest-form',
      arguments: {
        'hotel': hotel,
        'roomType': selectedRoom,
        'checkInDate': checkInDate,
        'checkOutDate': checkOutDate,
        'rooms': rooms,
        'guests': guests,
        'totalPrice': totalPrice,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBookingBar(),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ── Image carousel (compact) ────────────────────────────────
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: hotel.images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) => Image.network(
                      hotel.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.hotel, size: 64),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Get.back(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.help_outline,
                                color: Colors.white),
                            onPressed: () => Get.toNamed('/faq'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hotel.images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          hotel.images.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Hotel name / location / rating (compact single row) ─────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hotel.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 13, color: Color(0xFFB3B3B3)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${hotel.address} · ${hotel.distanceFromCenter.toStringAsFixed(1)} km',
                              style:
                                  TravelloTheme.caption.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(hotel.category,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: TravelloTheme.primaryMain)),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(children: [
                            const Icon(Icons.star,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(hotel.rating.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(width: 5),
                        Text(_getRatingText(hotel.rating),
                            style: TravelloTheme.caption.copyWith(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Sticky TabBar ───────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: TravelloTheme.primaryMain,
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.normal),
                indicatorColor: TravelloTheme.primaryMain,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Rooms'),
                  Tab(text: 'Amenities'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Policies'),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Tab content — fills all remaining space ─────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildRoomsTab(),
                  _buildAmenitiesTab(),
                  _buildReviewsTab(),
                  _buildPoliciesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PKR ${NumberFormat('#,##0').format(totalPrice.round())}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TravelloTheme.primaryMain,
                    ),
                  ),
                  if (selectedRoom != null)
                    Text(
                      selectedRoom!.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '$numberOfNights night${numberOfNights == 1 ? '' : 's'} · $rooms room${rooms == 1 ? '' : 's'}',
                      style: TravelloTheme.caption.copyWith(fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _proceedToBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: TravelloTheme.primaryMain,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                selectedRoom == null ? 'Select a Room' : 'Book Now',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Summary Card — compact 2×2 grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                _summaryCell(
                    'Check-in', DateFormat('EEE, MMM d').format(checkInDate)),
                const Icon(Icons.arrow_forward,
                    size: 16, color: TravelloTheme.primaryMain),
                _summaryCell(
                    'Check-out', DateFormat('EEE, MMM d').format(checkOutDate)),
                const VerticalDivider(width: 20, thickness: 1),
                _summaryCell(
                    '$numberOfNights ${numberOfNights == 1 ? 'Night' : 'Nights'}',
                    '$guests ${guests == 1 ? 'Guest' : 'Guests'} · $rooms ${rooms == 1 ? 'Room' : 'Rooms'}'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // About Section
          const Text('About This Hotel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            hotel.description,
            style: TravelloTheme.paragraph.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TravelloTheme.caption
                  .copyWith(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // Rooms Tab
  Widget _buildRoomsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Your Room',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...availableRooms.map((room) => _buildRoomCard(room)),
        ],
      ),
    );
  }

  // Room Card Widget
  Widget _buildRoomCard(RoomType room) {
    final isSelected = selectedRoom?.id == room.id;
    final roomTotalPrice = room.pricePerNight * numberOfNights * rooms;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? TravelloTheme.primaryMain : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? TravelloTheme.primaryMain.withValues(alpha: 0.04)
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              topRight: Radius.circular(11),
            ),
            child: Image.network(
              room.images.first,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.bed, size: 40),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + quick specs row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(room.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    if (room.roomsAvailable <= 3)
                      Text('Only ${room.roomsAvailable} left!',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),

                // Specs chips row
                Row(children: [
                  _specChip(
                      Icons.people_outline, '${room.maxOccupancy} guests'),
                  const SizedBox(width: 8),
                  _specChip(Icons.bed_outlined, room.bedType),
                  const SizedBox(width: 8),
                  _specChip(Icons.aspect_ratio, '${room.sizeInSqFt} ft²'),
                ]),
                const SizedBox(height: 8),

                // Top amenities
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: room.amenities
                      .take(3)
                      .map((a) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child:
                                Text(a, style: const TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),

                // Cancellation
                Row(children: [
                  Icon(
                    room.isRefundable ? Icons.check_circle : Icons.info,
                    size: 13,
                    color: room.isRefundable ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(room.cancellationPolicy,
                        style: TextStyle(
                            fontSize: 11,
                            color: room.isRefundable
                                ? Colors.green.shade700
                                : Colors.orange.shade700)),
                  ),
                ]),
                const SizedBox(height: 10),

                // Price + Select button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PKR ${NumberFormat('#,##0').format(room.pricePerNight.round())}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TravelloTheme.primaryMain,
                            ),
                          ),
                          Text(
                            '× $numberOfNights ${numberOfNights == 1 ? 'night' : 'nights'}${rooms > 1 ? ' × $rooms rooms' : ''} = PKR ${NumberFormat('#,##0').format(roomTotalPrice.round())}',
                            style: TravelloTheme.caption.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (room.breakfastIncluded)
                            Text('✓ Breakfast included',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => selectedRoom = room);
                        Get.snackbar(
                          'Room Selected',
                          '${room.name} selected',
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: const Color(0xFF2E7D32),
                          colorText: Colors.white,
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.white),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          borderRadius: 12,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? TravelloTheme.primaryMain
                            : Colors.white,
                        foregroundColor: isSelected
                            ? Colors.white
                            : TravelloTheme.primaryMain,
                        side:
                            const BorderSide(color: TravelloTheme.primaryMain),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(isSelected ? 'Selected ✓' : 'Select',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: TravelloTheme.primaryMain),
      const SizedBox(width: 3),
      Text(label, style: TravelloTheme.caption.copyWith(fontSize: 11)),
    ]);
  }

  // Amenities Tab
  Widget _buildAmenitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Amenities',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hotel.amenities.map((amenity) {
              return Container(
                width: (MediaQuery.of(context).size.width - 40) / 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(_getAmenityIcon(amenity),
                      size: 16, color: TravelloTheme.primaryMain),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(amenity,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Reviews Tab
  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall rating + breakdown side by side
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(hotel.rating.toString(),
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: TravelloTheme.primaryMain)),
                  Text('/ 5',
                      style: TravelloTheme.caption.copyWith(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_getRatingText(hotel.rating),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('${hotel.totalReviews} reviews',
                      style: TravelloTheme.caption.copyWith(fontSize: 10)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(children: [
                    _buildRatingBar('Cleanliness', 4.6),
                    _buildRatingBar('Service', 4.4),
                    _buildRatingBar('Location', 4.5),
                    _buildRatingBar('Facilities', 4.3),
                    _buildRatingBar('Value', 4.2),
                  ]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text('Recent Reviews',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildReviewCard(
              'Excellent Stay',
              'Amazing hotel with great facilities and friendly staff. Highly recommended!',
              'Ahmed K.',
              5.0,
              '2 days ago'),
          _buildReviewCard(
              'Great Location',
              'Perfect location in the city. Easy access to attractions. Breakfast was delicious.',
              'Sara M.',
              4.5,
              '5 days ago'),
          _buildReviewCard(
              'Good Value',
              'Nice hotel for the price. Staff was very helpful and rooms were clean.',
              'Bilal R.',
              4.0,
              '1 week ago'),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String category, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Text(category,
              style: TravelloTheme.caption.copyWith(fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rating / 5,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  TravelloTheme.primaryMain),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(rating.toString(),
            style: TravelloTheme.caption
                .copyWith(fontWeight: FontWeight.bold, fontSize: 10)),
      ]),
    );
  }

  Widget _buildReviewCard(
      String title, String review, String author, double rating, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: TravelloTheme.primaryMain,
            child: Text(author[0],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              Text(time, style: TravelloTheme.caption.copyWith(fontSize: 10)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.orange, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const Icon(Icons.star, size: 11, color: Colors.white),
              const SizedBox(width: 3),
              Text(rating.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 2),
        Text(review, style: TravelloTheme.caption.copyWith(fontSize: 11)),
      ]),
    );
  }

  // Policies Tab
  Widget _buildPoliciesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Policies',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildPolicyItem(
              Icons.check_circle,
              'Cancellation',
              hotel.isRefundable
                  ? 'Free cancellation up to 24 hrs before check-in.'
                  : 'Non-refundable. No refunds for cancellations.'),
          _buildPolicyItem(Icons.access_time, 'Check-in / Check-out',
              'Check-in: 2:00 PM · Check-out: 12:00 PM\nEarly/late available on request.'),
          _buildPolicyItem(
              Icons.restaurant,
              'Breakfast',
              hotel.hasBreakfast
                  ? 'Complimentary breakfast — 7:00 AM to 10:30 AM daily.'
                  : 'Breakfast not included. Available at restaurant.'),
          _buildPolicyItem(
              Icons.wifi,
              'WiFi',
              hotel.hasFreeWifi
                  ? 'Free high-speed WiFi throughout the property.'
                  : 'WiFi available for purchase at reception.'),
          _buildPolicyItem(
              Icons.local_parking,
              'Parking',
              hotel.hasParking
                  ? 'Free on-site parking. Valet available.'
                  : 'Street parking nearby (charges may apply).'),
          _buildPolicyItem(Icons.pets, 'Pets', 'Pets not allowed.'),
          _buildPolicyItem(Icons.smoking_rooms, 'Smoking',
              'Non-smoking property. Designated outdoor areas only.'),
          _buildPolicyItem(Icons.child_care, 'Children',
              'All ages welcome. Under 12 stay free on existing beds.'),
        ],
      ),
    );
  }

  Widget _buildPolicyItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: TravelloTheme.primaryMain),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(description,
                style: TravelloTheme.caption.copyWith(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // Helper: Get Amenity Icon
  IconData _getAmenityIcon(String amenity) {
    final lowerAmenity = amenity.toLowerCase();
    if (lowerAmenity.contains('wifi')) return Icons.wifi;
    if (lowerAmenity.contains('pool') || lowerAmenity.contains('swimming')) {
      return Icons.pool;
    }
    if (lowerAmenity.contains('gym') || lowerAmenity.contains('fitness')) {
      return Icons.fitness_center;
    }
    if (lowerAmenity.contains('restaurant') ||
        lowerAmenity.contains('dining')) {
      return Icons.restaurant;
    }
    if (lowerAmenity.contains('parking')) return Icons.local_parking;
    if (lowerAmenity.contains('spa') || lowerAmenity.contains('massage')) {
      return Icons.spa;
    }
    if (lowerAmenity.contains('bar') || lowerAmenity.contains('lounge')) {
      return Icons.local_bar;
    }
    if (lowerAmenity.contains('room service')) return Icons.room_service;
    if (lowerAmenity.contains('laundry') || lowerAmenity.contains('cleaning')) {
      return Icons.local_laundry_service;
    }
    if (lowerAmenity.contains('concierge') ||
        lowerAmenity.contains('reception')) {
      return Icons.support_agent;
    }
    if (lowerAmenity.contains('conference') ||
        lowerAmenity.contains('meeting')) {
      return Icons.meeting_room;
    }
    if (lowerAmenity.contains('airport')) return Icons.flight;
    return Icons.check_circle;
  }

  // Helper: Get Rating Text
  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    return 'Fair';
  }
}
