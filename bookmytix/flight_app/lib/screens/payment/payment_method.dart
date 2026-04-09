import 'dart:math';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/models/voucher.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/payment/voucher_list.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/payment/options.dart';
import 'package:flight_app/widgets/stepper/step_progress.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaymentMethod extends StatefulWidget {
  const PaymentMethod({super.key});

  @override
  State<PaymentMethod> createState() => _PaymentMethodState();
}

class _PaymentMethodState extends State<PaymentMethod> {
  static const double price = 700;
  static const double discount = 10;

  String _paymentMethod = '';
  final List<Voucher> _selectedVouchers = [];

  // Booking data forwarded from checkout
  Map<String, dynamic> _statusArgs = {};
  double _totalAmount = 0;

  String _generatePnr() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _generateTxnId() {
    return 'TXN${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void initState() {
    super.initState();
    final raw = Get.arguments as Map<String, dynamic>? ?? {};
    final searchParams = raw['searchParams'] as Map<String, dynamic>? ?? {};
    _totalAmount =
        (raw['totalAmount'] as double?) ?? (raw['grandTotal'] as double?) ?? 0;
    final baseFare = _totalAmount / 1.12;
    final taxes = _totalAmount - baseFare;

    _statusArgs = {
      ...raw,
      'bookingType': 'flight',
      'grandTotal': _totalAmount,
      'baseFare': baseFare,
      'taxes': taxes,
      'fromAirport': searchParams['fromAirport'],
      'toAirport': searchParams['toAirport'],
      'departureDate': searchParams['departureDate'],
      'returnDate': raw['returnDate'] ?? searchParams['returnDate'],
      'pnr': _generatePnr(),
      'transactionId': _generateTxnId(),
    };
  }

  void setPaymentMethod(val) {
    setState(() {
      _paymentMethod = val;
    });
  }

  void updateVoucherList(type, item) {
    setState(() {
      if (type == 'add') {
        _selectedVouchers.add(item);
      } else {
        _selectedVouchers.remove(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Trip item = tripList[1];

    final double finalPrice =
        _totalAmount > 0 ? _totalAmount : (price - price * discount / 100);

    void showVoucherList() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return VoucherList(
            selectedVouchers: _selectedVouchers,
            onSelected: (type, item) {
              setState(() {
                updateVoucherList(type, item);
              });
            },
          );
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: const Icon(Icons.arrow_back_ios_new)),
        centerTitle: true,
        title: const Text('Payment', style: TravelloTheme.subtitle),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StepProgress(activeIndex: 3, items: bookingSteps),
        Expanded(
            child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: FlightCard(
                from: cityList[1],
                to: cityList[2],
                plane: item.plane,
                price: 700,
                depart: item.depart,
                arrival: item.arrival,
                transit: item.transit,
                discount: 0,
              ),
            ),
            PaymentOptions(
              paymentMethod: _paymentMethod,
              setPaymentMethod: setPaymentMethod,
            ),
          ],
        )),
        Container(
          width: double.infinity,
          color: TravelloTheme.paperLight,
          child: Column(
            children: [
              /// VOUCHER INFO
              InkWell(
                onTap: () {
                  showVoucherList();
                },
                child: Container(
                    color: TravelloTheme.secondaryMainContainer,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: _selectedVouchers.isNotEmpty
                        ? Row(children: [
                            Wrap(
                              spacing: 4.0,
                              children: _selectedVouchers
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                int index = entry.key;
                                Voucher item = entry.value;

                                if (index > 1) {
                                  return Container();
                                }
                                return Container(
                                    width: 80,
                                    padding: const EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                        borderRadius: ThemeRadius.xsmall,
                                        border: Border.all(
                                            width: 1, color: item.color)),
                                    child: Text(
                                      item.title,
                                      style: TravelloTheme.caption,
                                      overflow: TextOverflow.ellipsis,
                                    ));
                              }).toList(),
                            ),
                            _selectedVouchers.length > 2
                                ? Text(
                                    '${_selectedVouchers.length - 2} more...',
                                    style: TravelloTheme.caption,
                                  )
                                : Container(),
                            const Spacer(),
                            Text('CHANGE',
                                style: TravelloTheme.paragraph.copyWith(
                                    color: colorScheme(context)
                                        .onSecondaryContainer,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                color:
                                    colorScheme(context).onSecondaryContainer,
                                size: 11),
                          ])
                        : Row(children: [
                            const Icon(Icons.discount,
                                color: TravelloTheme.primaryMain, size: 11),
                            const SizedBox(width: 4),
                            Text('5 Vouchers Available',
                                style: TravelloTheme.paragraph
                                    .copyWith(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('USE VOUCHERS',
                                style: TravelloTheme.paragraph.copyWith(
                                    color: colorScheme(context)
                                        .onSecondaryContainer,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                color:
                                    colorScheme(context).onSecondaryContainer,
                                size: 11),
                          ])),
              ),

              /// TOTAL PRICE AND ACTION BUTTON
              Padding(
                padding: EdgeInsets.only(
                    top: 8,
                    bottom: spacingUnit(5),
                    left: 16,
                    right: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ThemeBreakpoints.smUp(context)
                        ? const Spacer()
                        : Container(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${finalPrice.toStringAsFixed(0)}',
                          textAlign: TextAlign.end,
                          style: TravelloTheme.title.copyWith(
                              color: TravelloTheme.primaryMain,
                              height: 1,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: FilledButton(
                          onPressed: () {
                            Get.toNamed('/payment/$_paymentMethod', arguments: {
                              ..._statusArgs,
                              'paymentMethod': _paymentMethod
                            });
                          },
                          style: ThemeButton.btnBig.merge(ThemeButton.primary),
                          child: const Text('CONTINUE',
                              style: TravelloTheme.subtitle2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
