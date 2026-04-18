import 'package:flight_app/models/list_item.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FacilitiesSlider extends StatelessWidget {
  const FacilitiesSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ListItem> facilities = [
      ListItem(
        value: 'baggage',
        label: 'Extra Baggage',
        icon: Icons.business_center
      ),
      ListItem(
        value: 'food',
        label: 'Foods',
        icon: Icons.restaurant
      ),
      ListItem(
        value: 'beverage',
        label: 'Beverages',
        icon: Icons.coffee
      ),
      ListItem(
        value: 'medical',
        label: 'Medical Assistance',
        icon: Icons.medical_services
      ),
      ListItem(
        value: 'entertainment',
        label: 'Entertainment',
        icon: Icons.ondemand_video
      ),
      ListItem(
        value: 'wifi',
        label: 'Wi-Fi',
        icon: Icons.wifi
      ),
      ListItem(
        value: 'wheelchair',
        label: 'Assistance',
        icon: Icons.wheelchair_pickup_rounded
      )
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Facilities', style: TravelloTheme.subtitle2),
        ),
        const VSpaceShort(),
        SizedBox(
          height: 90,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: facilities.length,
            itemBuilder: ((context, index) {
              ListItem item = facilities[index];
          
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  Icon(item.icon, size: 48, color: colorScheme(context).outlineVariant),
                  const SizedBox(height: 8,),
                  Text(item.label, style: TravelloTheme.paragraph)
                ])
              );
            })
          ),
        ),
      ],
    );
  }
}