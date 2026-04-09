import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/transport.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  String _selectedType = 'Taxi';
  String _selectedCity = 'Karachi';
  int _passengers = 1;
  double _estimatedDistance = 5.0; // in km
  bool _requireAC = false;

  List<Transport> _availableTransports = [];

  @override
  void initState() {
    super.initState();
    _loadTransports();
  }

  void _loadTransports() {
    setState(() {
      _availableTransports = PakistanTransport.searchTransport(
        type: _selectedType,
        minSeats: _passengers,
        requireAC: _requireAC,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Transport'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TravelloTheme.primaryMain,
                  TravelloTheme.primaryMain.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.directions_car,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  'Book Your Ride',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Safe and reliable transport across Pakistan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Search/Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transport Type Selection (Tabs)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PakistanTransport.getTransportTypes().map((type) {
                      final isSelected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = type;
                              });
                              _loadTransports();
                            }
                          },
                          selectedColor: TravelloTheme.primaryMain,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // City and Passengers
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCity,
                        decoration: InputDecoration(
                          labelText: 'City',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: PakistanTransport.getCities().map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCity = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Passengers', style: TravelloTheme.caption),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: _passengers > 1
                                      ? () {
                                          setState(() => _passengers--);
                                          _loadTransports();
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  '$_passengers',
                                  style: TravelloTheme.subtitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() => _passengers++);
                                    _loadTransports();
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Distance Slider (for price estimation)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Distance: ${_estimatedDistance.toStringAsFixed(1)} km',
                      style: TravelloTheme.caption
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _estimatedDistance,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_estimatedDistance.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setState(() {
                          _estimatedDistance = value;
                        });
                      },
                    ),
                  ],
                ),

                // AC Filter
                CheckboxListTile(
                  title: const Text('AC Required'),
                  value: _requireAC,
                  onChanged: (value) {
                    setState(() {
                      _requireAC = value ?? false;
                    });
                    _loadTransports();
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),

          // Available Transports List
          Expanded(
            child: _availableTransports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transport available',
                          style: TravelloTheme.subtitle.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableTransports.length,
                    itemBuilder: (context, index) {
                      final transport = _availableTransports[index];
                      return _buildTransportCard(transport);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard(Transport transport) {
    final double estimatedPrice =
        transport.type == 'Rental Car' && transport.pricePerKm == 0
            ? transport.basePrice
            : transport.calculatePrice(_estimatedDistance);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _showBookingDialog(transport, estimatedPrice);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Vehicle Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  transport.imageUrl,
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 80,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.directions_car, size: 40),
                    );
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Type
                    Text(
                      transport.name,
                      style: TravelloTheme.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      transport.vehicleModel,
                      style: TravelloTheme.caption,
                    ),

                    const SizedBox(height: 8),

                    // Features Row
                    Row(
                      children: [
                        if (transport.isAC)
                          _buildFeatureChip(Icons.ac_unit, 'AC'),
                        const SizedBox(width: 4),
                        _buildFeatureChip(
                          Icons.person,
                          '${transport.seatingCapacity}',
                        ),
                        if (transport.driverRating > 0) ...[
                          const SizedBox(width: 4),
                          _buildFeatureChip(
                            Icons.star,
                            transport.driverRating.toString(),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PKR ${estimatedPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: TravelloTheme.primaryMain,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (transport.pricePerKm > 0)
                                Text(
                                  'PKR ${transport.pricePerKm}/km',
                                  style:
                                      TravelloTheme.caption.copyWith(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _showBookingDialog(transport, estimatedPrice);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Book'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6.4,
        vertical: spacingUnit(0.4),
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          SizedBox(width: spacingUnit(0.3)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(Transport transport, double estimatedPrice) {
    final pickupController = TextEditingController();
    final dropoffController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Book ${transport.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pickupController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Location',
                    prefixIcon: Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dropoffController,
                  decoration: const InputDecoration(
                    labelText: 'Drop-off Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Fare:'),
                          Text(
                            'PKR ${estimatedPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: TravelloTheme.primaryMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actual fare may vary based on traffic and route',
                        style: TravelloTheme.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Proceed to payment
                Navigator.pop(context);
                Get.toNamed(
                  '/payment-professional',
                  arguments: {
                    'transport': transport,
                    'pickup': pickupController.text,
                    'dropoff': dropoffController.text,
                    'phone': phoneController.text,
                    'totalPrice': estimatedPrice,
                    'bookingType': 'transport',
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TravelloTheme.primaryMain,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Booking'),
            ),
          ],
        );
      },
    );
  }
}
