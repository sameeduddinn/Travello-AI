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
    // Auth gate at booking intent — browsing hotel details was free
    final isGuest = await AuthService.isGuestMode();
    if (isGuest && mounted) {
      AuthGateSheet.show(context, action: 'to book this hotel');
      return;
    }
    if (selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a room type', style: TextStyle(fontSize: 14)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Occupancy check: total guests must not exceed maxOccupancy × rooms
    final maxCapacity = selectedRoom!.maxOccupancy * rooms;
    if (guests > maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    body: Column(
      children: [
        // ── Collapsing image (not sticky, scrolls with content) ──
        SizedBox(
          height: 260,
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.white),
                        onPressed: () => Get.toNamed('/faq'),
                      ),
                    ],
                  ),
                ),
              ),
              if (hotel.images.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      hotel.images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
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

        // ── Hotel name / location / rating ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(hotel.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme(context)
                          .primary
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(hotel.category,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: TravelloTheme.primaryMain)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Color(0xFFB3B3B3)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(hotel.address,
                        style: TravelloTheme.subtitle.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  '${hotel.distanceFromCenter.toStringAsFixed(1)} km from city center',
                  style: TravelloTheme.caption.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(hotel.rating.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getRatingText(hotel.rating),
                          style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${hotel.totalReviews} reviews',
                          style: TravelloTheme.caption.copyWith(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── TabBar (sticky) ──
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: TravelloTheme.primaryMain,
            unselectedLabelColor: Colors.grey,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
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

        // ── Tab content fills all remaining space ──
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
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PKR ${totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TravelloTheme.primaryMain,
                ),
              ),
              Text(
                '$numberOfNights nights · $rooms room${rooms == 1 ? '' : 's'}',
                style: TravelloTheme.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _proceedToBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: TravelloTheme.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
          ),
        ],
      ),
    ),
  );
}
  // Overview Tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check-in',
                              style:
                                  TravelloTheme.caption.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d').format(checkInDate),
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward,
                        color: TravelloTheme.primaryMain),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check-out',
                              style:
                                  TravelloTheme.caption.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d').format(checkOutDate),
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration',
                              style:
                                  TravelloTheme.caption.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '$numberOfNights ${numberOfNights == 1 ? 'Night' : 'Nights'}',
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guests',
                              style:
                                  TravelloTheme.caption.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '$guests ${guests == 1 ? 'Guest' : 'Guests'}, $rooms ${rooms == 1 ? 'Room' : 'Rooms'}',
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          const Text('About This Hotel', style: TravelloTheme.title2),
          const SizedBox(height: 8),
          Text(
            hotel.description,
            style: TravelloTheme.paragraph.copyWith(fontSize: 14),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Rooms Tab
  Widget _buildRoomsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 96, // Extra padding for bottom nav
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Room',
            style: TravelloTheme.title2,
          ),
          const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? TravelloTheme.primaryMain : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? TravelloTheme.primaryMain.withValues(alpha: 0.05)
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              room.images.first,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.bed, size: 48),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Name
                Text(
                  room.name,
                  style: TravelloTheme.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                // Room Description
                Text(
                  room.description,
                  style: TravelloTheme.caption.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Room Details
                Row(
                  children: [
                    const Icon(Icons.people,
                        size: 18, color: TravelloTheme.primaryMain),
                    const SizedBox(width: 4),
                    Text('${room.maxOccupancy} guests',
                        style: TravelloTheme.caption.copyWith(fontSize: 13)),
                    const SizedBox(width: 16),
                    const Icon(Icons.bed,
                        size: 18, color: TravelloTheme.primaryMain),
                    const SizedBox(width: 4),
                    Text(room.bedType,
                        style: TravelloTheme.caption.copyWith(fontSize: 13)),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(Icons.aspect_ratio,
                        size: 18, color: TravelloTheme.primaryMain),
                    const SizedBox(width: 4),
                    Text('${room.sizeInSqFt} sq ft',
                        style: TravelloTheme.caption.copyWith(fontSize: 13)),
                    if (room.hasCityView) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.visibility,
                          size: 18, color: TravelloTheme.primaryMain),
                      const SizedBox(width: 4),
                      Text('City view',
                          style: TravelloTheme.caption.copyWith(fontSize: 13)),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Amenities
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: room.amenities.take(4).map((amenity) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        amenity,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Cancellation Policy
                Row(
                  children: [
                    Icon(
                      room.isRefundable ? Icons.check_circle : Icons.info,
                      size: 16,
                      color: room.isRefundable ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        room.cancellationPolicy,
                        style: TextStyle(
                          fontSize: 12,
                          color: room.isRefundable
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Price and Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PKR ${room.pricePerNight.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: TravelloTheme.primaryMain,
                            ),
                          ),
                          Text(
                            rooms > 1
                                ? 'PKR ${NumberFormat('#,##0').format(room.pricePerNight.round())}/night × $numberOfNights nights × $rooms rooms = PKR ${NumberFormat('#,##0').format(roomTotalPrice.round())}'
                                : 'PKR ${NumberFormat('#,##0').format(room.pricePerNight.round())}/night × $numberOfNights ${numberOfNights == 1 ? 'night' : 'nights'} = PKR ${NumberFormat('#,##0').format(roomTotalPrice.round())} total',
                            style: TravelloTheme.caption.copyWith(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          if (room.breakfastIncluded)
                            Text(
                              '✓ Breakfast included',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedRoom = room;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${room.name} selected',
                                style: const TextStyle(fontSize: 14)),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? TravelloTheme.primaryMain
                            : Colors.white,
                        foregroundColor: isSelected
                            ? Colors.white
                            : TravelloTheme.primaryMain,
                        side: const BorderSide(
                          color: TravelloTheme.primaryMain,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        isSelected ? 'Selected' : 'Select',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                if (room.roomsAvailable <= 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Only ${room.roomsAvailable} rooms left!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Amenities Tab
  Widget _buildAmenitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Amenities', style: TravelloTheme.title2),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: hotel.amenities.map((amenity) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.42,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getAmenityIcon(amenity),
                      size: 22,
                      color: TravelloTheme.primaryMain,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        amenity,
                        style: TravelloTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Reviews Tab
  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Rating
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      hotel.rating.toString(),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: TravelloTheme.primaryMain,
                      ),
                    ),
                    const Text('out of 5', style: TravelloTheme.caption),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRatingText(hotel.rating),
                        style: TravelloTheme.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on ${hotel.totalReviews} reviews',
                        style: TravelloTheme.caption.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Rating Breakdown
          const Text('Rating Breakdown', style: TravelloTheme.title2),
          const SizedBox(height: 12),

          _buildRatingBar('Cleanliness', 4.6),
          _buildRatingBar('Service', 4.4),
          _buildRatingBar('Location', 4.5),
          _buildRatingBar('Facilities', 4.3),
          _buildRatingBar('Value for Money', 4.2),

          const SizedBox(height: 24),

          // Sample Reviews
          const Text('Recent Reviews', style: TravelloTheme.title2),
          const SizedBox(height: 12),

          _buildReviewCard(
            'Excellent Stay',
            'Amazing hotel with great facilities and friendly staff. The room was spacious and clean. Highly recommended!',
            'Ahmed K.',
            5.0,
            '2 days ago',
          ),

          _buildReviewCard(
            'Great Location',
            'Perfect location in the heart of the city. Easy access to all major attractions. The breakfast was delicious.',
            'Sara M.',
            4.5,
            '5 days ago',
          ),

          _buildReviewCard(
            'Good Value',
            'Nice hotel for the price. Rooms could be a bit bigger but overall a pleasant stay. Staff was very helpful.',
            'Bilal R.',
            4.0,
            '1 week ago',
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String category, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              category,
              style: TravelloTheme.caption.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rating / 5,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  TravelloTheme.primaryMain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rating.toString(),
            style: TravelloTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(
    String title,
    String review,
    String author,
    double rating,
    String time,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: TravelloTheme.primaryMain,
                child: Text(
                  author[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: TravelloTheme.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      time,
                      style: TravelloTheme.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TravelloTheme.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            review,
            style: TravelloTheme.paragraph.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Policies Tab
  Widget _buildPoliciesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Policies', style: TravelloTheme.title2),
          const SizedBox(height: 16),
          _buildPolicyItem(
            Icons.check_circle,
            'Cancellation',
            hotel.isRefundable
                ? 'Free cancellation up to 24 hours before check-in. After that, cancellation charges may apply.'
                : 'Non-refundable booking. No refunds will be provided for cancellations.',
          ),
          _buildPolicyItem(
            Icons.access_time,
            'Check-in / Check-out',
            'Check-in from 2:00 PM\nCheck-out until 12:00 PM\nEarly check-in and late check-out available upon request (subject to availability)',
          ),
          _buildPolicyItem(
            Icons.restaurant,
            'Breakfast',
            hotel.hasBreakfast
                ? 'Complimentary breakfast included with your stay. Served daily from 7:00 AM to 10:30 AM.'
                : 'Breakfast not included in room rate. Available for purchase at our restaurant.',
          ),
          _buildPolicyItem(
            Icons.wifi,
            'WiFi',
            hotel.hasFreeWifi
                ? 'Free high-speed WiFi available throughout the property.'
                : 'WiFi available for purchase at reception desk.',
          ),
          _buildPolicyItem(
            Icons.local_parking,
            'Parking',
            hotel.hasParking
                ? 'Free on-site parking available for all guests. Valet parking service also available.'
                : 'Street parking available nearby (charges may apply).',
          ),
          _buildPolicyItem(
            Icons.pets,
            'Pets',
            'Pets are not allowed in the hotel premises.',
          ),
          _buildPolicyItem(
            Icons.smoking_rooms,
            'Smoking',
            'This is a non-smoking property. Smoking is only allowed in designated outdoor areas.',
          ),
          _buildPolicyItem(
            Icons.child_care,
            'Children',
            'Children of all ages are welcome. Children under 12 years stay free when using existing beds.',
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Helper: Build Policy Item
  Widget _buildPolicyItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: TravelloTheme.primaryMain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TravelloTheme.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TravelloTheme.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
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
