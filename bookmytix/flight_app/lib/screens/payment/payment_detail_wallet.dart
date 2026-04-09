import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaymentDetailWallet extends StatelessWidget {
  const PaymentDetailWallet({super.key});

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
              Padding(
                padding: const EdgeInsets.all(16),
                child: PaperCard(
                    flat: true,
                    content: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundImage:
                              AssetImage('assets/images/logos/logo11.jpg'),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        Text('Wallet ABC',
                            style: TravelloTheme.title2
                                .copyWith(fontWeight: FontWeight.bold)),
                        const Text(
                          'Continue Payment with Wallet ABC',
                          style: TravelloTheme.paragraph,
                        )
                      ]),
                    )),
              ),
              Expanded(
                  child: ListView(children: [
                const ListTile(
                  leading: Icon(Icons.shopping_bag_outlined),
                  title: Text('Billing Ammount:'),
                  trailing: Text(
                    '\$630.00',
                    style: TravelloTheme.paragraph,
                  ),
                ),
                const LineList(),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Tax 12%:'),
                  trailing: Text(
                    '\$75.6',
                    style: TravelloTheme.paragraph,
                  ),
                ),
                const LineList(),
                ListTile(
                  title: Text(
                    'Total:',
                    style:
                        TravelloTheme.title2.copyWith(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '\$705.6',
                    style: TravelloTheme.title2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: TravelloTheme.primaryMain),
                  ),
                ),
              ])),
              Container(
                color: TravelloTheme.paperLight,
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
                              child: const Text('OPEN WALLET APP')),
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
