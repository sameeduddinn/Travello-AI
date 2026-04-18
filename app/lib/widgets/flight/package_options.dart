import 'package:flight_app/models/list_item.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

final List<ListItem> packageList = [
  ListItem(
    value: '20',
    label: 'Special Meals',
    icon: Icons.restaurant,
    text: 'Vegetarian, Halal, Kosher, Gluten-free options'
  ),
  ListItem(
    value: '20',
    label: 'Beverages',
    icon: Icons.coffee,
    text: 'Beverages depending on airline and class'
  ),
  ListItem(
    value: '10',
    label: 'Snack Services',
    icon: Icons.card_giftcard,
    text: 'Light snacks and refreshments'
  ),
  ListItem(
    value: '10',
    label: 'Amenity',
    icon: Icons.local_library,
    text: 'Blankets, pillows, sleep masks, earplugs'
  ),
  ListItem(
    value: '25',
    label: 'Extra Baggage Options',
    icon: Icons.home_repair_service,
    text: 'Additional luggage for an extra fee'
  ),
  ListItem(
    value: '60',
    label: 'Priority Check-in & Boarding',
    icon: Icons.airplane_ticket,
    text: 'Available for premium classes and loyalty members'
  ),
  ListItem(
    value: '70',
    label: 'Lounge Access',
    icon: Icons.rice_bowl,
    text: 'Business and first-class lounges with food, Wi-Fi, and relaxation spaces'
  ),
  ListItem(
    value: '120',
    label: 'Pet Trave',
    icon: Icons.pets,
    text: 'In-cabin or cargo options for pets'
  ),
  ListItem(
    value: '100',
    label: 'Extra Insurance',
    icon: Icons.gpp_good,
    text: 'Medical Assistance, Lost and found, baggage tracking, etc'
  ),
  ListItem(
    value: '100',
    label: 'Fast Track Security',
    icon: Icons.snowshoeing,
    text: 'Avoid long queues at security checks and immigration'
  ),
];

class PackageOptions extends StatefulWidget {
  const PackageOptions({super.key, required this.getVal});

  final Function(String, double) getVal;

  @override
  State<PackageOptions> createState() => _PackageOptionsState();
}

class _PackageOptionsState extends State<PackageOptions> {
  final List<ListItem> _selectedPackages = [];
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Packages', style: TravelloTheme.subtitle2),
          const VSpaceShort(),
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              borderRadius: ThemeRadius.medium,
              border: Border.all(
                width: 1,
                color: colorScheme(context).onSecondaryContainer
              )
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(0),
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _showAll ? packageList.length : 5,
                    itemBuilder: (context, index) {
                      final ListItem item = packageList[index];
                      return CheckboxListTile(
                        contentPadding: const EdgeInsets.only(bottom: 8),
                        title: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(
                                children: [
                                  Icon(item.icon, size: 16, color: colorScheme(context).onSecondaryContainer),
                                  const SizedBox(width: 4,),
                                  Text(item.label, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(item.text!, style: TravelloTheme.caption)
                            ]),
                          ),
                          const SizedBox(width: 16),
                          Text('+\$${item.value}', textAlign: TextAlign.end, style: TravelloTheme.headline.copyWith(fontWeight: FontWeight.bold),)
                        ]),
                        value: _selectedPackages.contains(item),
                        onChanged: (bool? newValue) {
                          setState(() {
                            double countableVal = double.parse(item.value);
                            if (newValue == true) {
                              widget.getVal('add', countableVal);
                              _selectedPackages.add(item);
                            } else {
                              widget.getVal('remove', countableVal);
                              _selectedPackages.remove(item);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_showAll ? 'Show Fewer' : 'Show More Packages', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSecondaryContainer, fontWeight: FontWeight.bold),)
                  ),
                )
              ],
            )
          ),
        ],
      ),
    );
  }
}