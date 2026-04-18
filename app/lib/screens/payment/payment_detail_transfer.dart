import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/payment/payment_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/alert_info/alert_info.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/widgets/counter/counter_down.dart';
import 'package:flight_app/widgets/payment/bank_acc_form.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaymentDetailTransfer extends StatelessWidget {
  const PaymentDetailTransfer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          leading: IconButton(
              onPressed: () {
                Get.back();
              },
              icon: const Icon(Icons.arrow_back_ios_new)),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                Get.toNamed('/faq');
              },
            )
          ],
          centerTitle: true,
          title: const Text('Payment', style: TravelloTheme.subtitle),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ThemeSize.sm),
            child: Column(children: [
              const Column(children: [
                /// TIMER
                VSpace(),
                Text('Time left:'),
                CounterDown(
                    duration: Duration(
                      days: 1,
                      hours: 11,
                      minutes: 47,
                    ),
                    format: CountDownTimerFormat.daysHoursMinutes),
                VSpaceShort(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: AlertInfo(
                      type: AlertType.warning,
                      text:
                          'Please finish your payment before 22 May 2025:17:45'),
                )
              ]),
              const VSpace(),

              /// DETAIL BANK ACCOUNT
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    PaperCard(
                        content: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text('\$630.00',
                            style: TravelloTheme.title.copyWith(
                                color: TravelloTheme.primaryMain,
                                fontWeight: FontWeight.bold)),
                        const Text('Please transfer the amount above to'),
                        Image.asset(
                          'assets/images/logos/logo1.png',
                          height: 50,
                        ),
                        const VSpaceShort(),
                        ListTile(
                          title: const Text(
                            'Account Name',
                            style: TravelloTheme.caption,
                          ),
                          subtitle: Text(
                            'Bank Lorem Ipsum',
                            style: TravelloTheme.subtitle2
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const LineList(),
                        ListTile(
                            title: const Text(
                              'Account Number',
                              style: TravelloTheme.caption,
                            ),
                            subtitle: Text(
                              '1234567890',
                              style: TravelloTheme.subtitle2
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {},
                            )),
                      ]),
                    )),
                    const VSpace(),

                    /// BANK ACCOUNT DETAIL
                    Text('Please complete your bank account detail!',
                        style: TravelloTheme.subtitle2
                            .copyWith(fontWeight: FontWeight.bold)),
                    const VSpaceShort(),
                    const BankAccForm(),
                    const SizedBox(height: 16),
                    AppInputBox(
                        content: ListTile(
                      contentPadding: const EdgeInsets.all(0),
                      leading: const Icon(Icons.help_outline,
                          color: TravelloTheme.primaryMain),
                      title: const Text('Need guide for this transfer method?',
                          style: TextStyle(color: TravelloTheme.primaryMain)),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        showModalBottomSheet<dynamic>(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) {
                              return const Wrap(children: [PaymentGuide()]);
                            });
                      },
                    ))
                  ],
                ),
              ),

              /// ACTION BUTTON
              Container(
                color: Get.isDarkMode
                    ? TravelloTheme.paperLight
                    : TravelloTheme.paperLightContainerHighest,
                padding: EdgeInsets.only(
                    top: 8,
                    bottom: spacingUnit(5),
                    left: 16,
                    right: 16),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text(
                        'By continuing, you agree with the',
                        style: TravelloTheme.caption,
                      ),
                      InkWell(
                          onTap: () {
                            Get.toNamed(AppLink.terms);
                          },
                          child: Text(' Terms and Conditions',
                              style: TravelloTheme.caption
                                  .copyWith(color: TravelloTheme.primaryMain))),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                              onPressed: () {
                                Get.back();
                              },
                              style: ThemeButton.btnBig
                                  .merge(ThemeButton.outlinedPrimary(context)),
                              child: const Text('BACK')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                              onPressed: () {
                                Get.toNamed('/payment/status',
                                    arguments: Get.arguments
                                            as Map<String, dynamic>? ??
                                        {});
                              },
                              style: ThemeButton.btnBig
                                  .merge(ThemeButton.tonalPrimary(context)),
                              child: const Text('CONFIRM TRANSFER')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ));
  }
}
