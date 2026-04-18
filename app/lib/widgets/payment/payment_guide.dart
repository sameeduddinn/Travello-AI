import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

final List<String> helpGuideList = [
  'Log in to the mobile banking application, internet banking, or ATM.',
  'Select the "Transfer to Virtual Account" menu.',
  'Enter the virtual account number.',
  'Please verify the amount. The amount must be same as in application.',
  'Complete the transfer process until successful. Save proof of transfer if necessary.',
  'Go back to the application, then select the "Confirm Payment" button.'
];

class PaymentGuide extends StatelessWidget {
  const PaymentGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const GrabberIcon(),
      const VSpaceShort(),
      const Text('Payment Guide', textAlign: TextAlign.center, style: TravelloTheme.subtitle),
      const VSpaceShort(),
      ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: helpGuideList.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.only(left: 24),
                margin: const EdgeInsets.only(left: 9),
                decoration: BoxDecoration(
                  border: index < helpGuideList.length - 1 ? const Border(left: BorderSide(color: TravelloTheme.primaryMainContainer, width: 1)) : null
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(helpGuideList[index], textAlign: TextAlign.start, style: TravelloTheme.paragraph),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: TravelloTheme.primaryMainContainer,
                  child: Text('${index + 1}', style: TravelloTheme.caption.copyWith(color: colorScheme(context).onPrimaryContainer))
                ),
              ),
            ],
          );
        }
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ThemeButton.btnBig.merge(ThemeButton.outlinedPrimary(context)),
          child: const Text('UNDERSTAND')
        ),
      ),
      const VSpaceBig()
    ]);
  }
}