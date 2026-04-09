import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/models/user.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/booking/passenger_detail.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ReviewOrder extends StatelessWidget {
  const ReviewOrder({super.key, this.withFlightDetail = true});

  static const double price = 600;
  static const double discount = 10;

  final bool withFlightDetail;

  @override
  Widget build(BuildContext context) {
    final Trip item = tripList[1];

    /// BAGAGE POPUP
    void showPassengerDetail() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return const PassengerDetail();
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }
    
    return ListView(shrinkWrap: true, physics: const ScrollPhysics(), padding: const EdgeInsets.all(0), children: [
      /// FLIGHT SUMMARY
      withFlightDetail ? const SizedBox(height: 16) : Container(),
      withFlightDetail ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FlightCard(
          from: cityList[1],
          to: cityList[2],
          plane: item.plane,
          price: 700,
          depart: item.depart,
          arrival: item.arrival,
          transit: item.transit,
          discount: 10,
          label: '10% OFF',
        ),
      ) : Container(),

      /// PASSENGGER LIST
      const LineSpace(),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TitleBasic(title: 'Passenger Detail', size: 'small',),
      ),
      ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const ClampingScrollPhysics(),
        itemCount: 3,
        itemBuilder: ((BuildContext context, int index) {
          User item = passengerList[index];
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppInputBox(
              content: InkWell(
                onTap: () {
                  showPassengerDetail();
                },
                child: ListTile(
                  title: Text('${item.title} ${item.name}', style: TravelloTheme.paragraphBold,),
                  subtitle: Row(children: [
                    Icon(Icons.home_repair_service, size: 18, color: colorScheme(context).outlineVariant),
                    const SizedBox(width: 4,),
                    Text('${item.baggage} Kg', style: TravelloTheme.paragraph),
                    const SizedBox(width: 32),
                    Icon(Icons.airline_seat_recline_normal_rounded, size: 18, color: colorScheme(context).outlineVariant),
                    Text(item.seat!, style: TravelloTheme.paragraph),
                    const SizedBox(width: 32),
                    Icon(Icons.playlist_add, size: 18, color: colorScheme(context).outlineVariant),
                    const SizedBox(width: 4,),
                    const Text('2', style: TravelloTheme.paragraph),
                  ]),
                  trailing: const Icon(Icons.more_horiz, color: TravelloTheme.primaryMain),
                  contentPadding: const EdgeInsets.all(0),
                  minTileHeight: 0,
                )
              )
            ),
          );
        })
      ),

      /// PRICE DETAIL
      const LineSpace(),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TitleBasic(title: 'Price Detail', size: 'small',),
      ),
      const VSpaceShort(),
      ListTile(
        title: Text('Ticket ${cityList[0].name} to ${cityList[6].name}', style: TravelloTheme.paragraph,),
        subtitle: const Text('\$200 x 3(Adult)', style: TravelloTheme.paragraph,),
        trailing: Text('\$$price', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),

      ListTile(
        title: const Text('Additional Baggage', style: TravelloTheme.paragraph,),
        subtitle: const Text('\$50 x 1(Adult)', style: TravelloTheme.paragraph,),
        trailing: Text('\$50', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),

      ListTile(
        title: const Text('Meal and Beverage', style: TravelloTheme.paragraph,),
        subtitle: const Text('\$20 x 2(Adult)', style: TravelloTheme.paragraph,),
        trailing: Text('\$40', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),

      ListTile(
        title: const Text('Fee and Tax', style: TravelloTheme.paragraph,),
        trailing: Text('\$10', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),

      const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: DashedBorder(),
      ),

      ListTile(
        title: Text('Subtotal', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold),),
        trailing: Text('\$700', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),
      ListTile(
        title: Text('Discount 10%', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold),),
        trailing: Text('-\$70', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
      ),

      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          borderRadius: ThemeRadius.small,
          color: TravelloTheme.primaryMainContainer
        ),
        child: ListTile(
          title: const Text('Total', style: TravelloTheme.subtitle2),
          trailing: Text('\$630', style: TravelloTheme.subtitle2.copyWith(color: colorScheme(context).onPrimaryContainer)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minTileHeight: 0,
        ),
      ),
      const VSpaceShort(),

      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: const Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tortor lectus, imperdiet vitae massa nec, malesuada congue massa. Nam sed venenatis lorem',
          style: TravelloTheme.paragraph
        ),
      ),
      const VSpace()
    ]);
  }
}