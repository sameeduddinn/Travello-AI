import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/ui/themes/theme_button.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/booking/tag_filter.dart';
import 'package:flight_app/widgets/booking/ticket_list.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class OrderList extends StatelessWidget {
  const OrderList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: CustomScrollView(
        slivers: <Widget>[
          /// SLIVER APPBAR AND BANNER
          SliverAppBar(
            expandedHeight: 250.0,
            collapsedHeight: 120,
            floating: true,
            pinned: true,
            toolbarHeight: 100,
            centerTitle: false,
            backgroundColor: colorScheme(context).primary,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.all(spacingUnit(2)),
              background: Image.asset(
                ImgApi.myTicketBanner,
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// INFO
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacingUnit(2), vertical: spacingUnit(1)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('My Tickets', style: ThemeText.title.copyWith(color: Colors.white)),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                onPressed: () {
                                  Get.toNamed(AppLink.orderHistory);
                                },
                                style: ThemeButton.iconBtn(context),
                                icon: Icon(Icons.history, color: colorScheme(context).primary, size: 24)
                              ),
                            )
                          ],
                        ),
                        Text(
                          'All your active tickets and waiting for payment',
                          textAlign: TextAlign.start,
                          style: ThemeText.headline.copyWith(color: Colors.white)
                        ),
                      ],
                    ),
                  ),
              
                  /// DECORATION
                  Container(
                    width: double.infinity,
                    height: 70,
                    decoration: BoxDecoration(
                      color: colorScheme(context).surfaceContainerLowest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme(context).surfaceContainerLowest,
                          offset: const Offset(0, 2),
                          blurRadius: 0,
                          spreadRadius: 0
                        )
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: spacingUnit(3), bottom: spacingUnit(2)),
                      child: const TagFilter(),
                    )
                  )
                ],
              ),
            ),
          ),

          /// CONTENT
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: spacingUnit(1)),
                TicketList(bookingList: bookingList.sublist(0, 2)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacingUnit(2)),
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.toNamed(AppLink.searchFlight);
                    },
                    style: ThemeButton.btnBig.merge(ThemeButton.outlinedPrimary(context)),
                    child: const Text('CHECK & ADD MORE TICKET')
                  ),
                ),
                const SizedBox(height: 160)
              ],
            )
          )
        ],
      ),
    );
  }
}