import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/booking/ticket_list.dart';
import 'package:flight_app/widgets/search_filters/filter_transaction.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  String _sortby = 'date_newest';
  String _category = 'all';

  void _onSortByDate(val) {
    setState(() {
      _sortby = val;
    });
  }

  void _onChangeCategory(val) {
    setState(() {
      _category = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: colorScheme(context).surfaceContainerLowest,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios_new)
        ),
        centerTitle: true,
        title: const Text('Transaction History', style: ThemeText.subtitle),
        actions: [
          IconButton(
            onPressed: () {
              Get.toNamed(AppLink.faq);
            },
            icon: const Icon(Icons.help_outline)
          )
        ],
      ),
      body: SingleChildScrollView(child: Column(
        children: [
          SizedBox(height: spacingUnit(1)),
          FilterTransaction(
            sortby: _sortby,
            category: _category,
            onSortByDate: _onSortByDate,
            onChangeCategory: _onChangeCategory,
          ),
          TicketList(bookingList: bookingList),
          const VSpaceBig()
        ],
      ),)
    );
  }
}