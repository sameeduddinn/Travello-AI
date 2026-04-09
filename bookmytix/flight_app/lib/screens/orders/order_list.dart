import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/widgets/booking/tag_filter.dart';
import 'package:flight_app/widgets/booking/ticket_list.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

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
            backgroundColor: TravelloTheme.primaryMain,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('My Tickets', style: TravelloTheme.title.copyWith(color: Colors.white)),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                onPressed: () {
                                  Get.toNamed(AppLink.orderHistory);
                                },
                                style: ThemeButton.iconBtn(context),
                                icon: const Icon(Icons.history, color: TravelloTheme.primaryMain, size: 24)
                              ),
                            )
                          ],
                        ),
                        Text(
                          'All your active tickets and waiting for payment',
                          textAlign: TextAlign.start,
                          style: TravelloTheme.headline.copyWith(color: Colors.white)
                        ),
                      ],
                    ),
                  ),
              
                  /// DECORATION
                  Container(
                    width: double.infinity,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: TravelloTheme.paperLightContainerLowest,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TravelloTheme.paperLightContainerLowest,
                          offset: Offset(0, 2),
                          blurRadius: 0,
                          spreadRadius: 0
                        )
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 16),
                      child: TagFilter(),
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
                const SizedBox(height: 8),
                TicketList(bookingList: bookingList.sublist(0, 2)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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