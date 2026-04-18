class RoomType {
  final String id;
  final String name;
  final String description;
  final double pricePerNight;
  final int maxOccupancy;
  final int bedCount;
  final String bedType; // 'King', 'Queen', 'Twin', 'Single'
  final double sizeInSqFt;
  final List<String> amenities;
  final List<String> images;
  final bool hasCityView;
  final bool hasBalcony;
  final bool isRefundable;
  final String cancellationPolicy;
  final bool breakfastIncluded;
  final int roomsAvailable;

  RoomType({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerNight,
    required this.maxOccupancy,
    required this.bedCount,
    required this.bedType,
    required this.sizeInSqFt,
    required this.amenities,
    required this.images,
    required this.hasCityView,
    required this.hasBalcony,
    required this.isRefundable,
    required this.cancellationPolicy,
    required this.breakfastIncluded,
    required this.roomsAvailable,
  });
}
