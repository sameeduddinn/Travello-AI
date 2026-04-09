import 'package:flutter/material.dart';
import 'package:flight_app/utils/expanded_section.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/widgets/payment/bank_list.dart';
import 'package:flight_app/widgets/payment/wallet_list.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaymentOptions extends StatefulWidget {
  const PaymentOptions({super.key, required this.paymentMethod, required this.setPaymentMethod});

  final String paymentMethod;
  final Function(String) setPaymentMethod;

  @override
  State<PaymentOptions> createState() => _PaymentOptionsState();
}

class _PaymentOptionsState extends State<PaymentOptions> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      children: [
        const Text('Choose Payment Method', textAlign: TextAlign.center, style: TravelloTheme.subtitle),
        const VSpaceShort(),
        /// CREDIT CARD
        InkWell(
          onTap: () {
            widget.setPaymentMethod('credit-card');
          },
          child: PaperCard(
            flat: true,
            colouredBorder: widget.paymentMethod == 'credit-card',
            content: ListTile(
              leading: Icon(Icons.credit_card, size: 36, color: colorScheme(context).onPrimaryContainer),
              title: const Text('Credit Card', style: TravelloTheme.subtitle),
              subtitle: const Text('Payment with credit card', style: TravelloTheme.paragraph),
              trailing: widget.paymentMethod == 'credit-card' ?
                const Icon(Icons.check_circle, color: TravelloTheme.primaryMain)
                : Icon(Icons.circle_outlined, color: colorScheme(context).outline),
            )
          ),
        ),
        const SizedBox(height: 16),

        /// E-WALLET
        PaymentExpanded(
          title: 'E-Wallet',
          subtitle: 'Choose your e-wallet platform',
          icon: Icons.wallet,
          isExpanded: widget.paymentMethod == 'ewallet',
          onTap: () {
            widget.setPaymentMethod('ewallet');
          },
          child: const WalletList()
        ),
        const SizedBox(height: 16),

        /// VIRTUAL ACCOUNT
        PaymentExpanded(
          title: 'Virtual Account',
          subtitle: 'Choose virtual account bank',
          icon: Icons.contacts,
          isExpanded: widget.paymentMethod == 'vac',
          onTap: () {
            widget.setPaymentMethod('vac');
          },
          child: const BankList()
        ),
        const SizedBox(height: 16),

        /// TRANSFER BANK
        PaymentExpanded(
          title: 'Bank Transfer',
          subtitle: 'Choose bank for transfer method',
          icon: Icons.account_balance,
          isExpanded: widget.paymentMethod == 'transfer',
          onTap: () {
            widget.setPaymentMethod('transfer');
          },
          child: const BankList()
        ),
      ]
    );
  }
}

class PaymentExpanded extends StatefulWidget {
  const PaymentExpanded({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool isExpanded;
  final Function() onTap;

  @override
  State<PaymentExpanded> createState() => _PaymentExpandedState();
}

class _PaymentExpandedState extends State<PaymentExpanded> with SingleTickerProviderStateMixin {
  late AnimationController rotateController;
  late Animation<double> animation; 

  @override
  void initState() {
    super.initState();
    prepareAnimations();
    _runRotateCheck();
  }

  ///Setting up the animation
  void prepareAnimations() {
    rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100)
    );
    animation = CurvedAnimation(
      parent: rotateController,
      curve: Curves.fastOutSlowIn,
    );
  }

  void _runRotateCheck() {
    if(widget.isExpanded) {
      rotateController.forward();
    }
    else {
      rotateController.reverse();
    }
  }

  @override
  void didUpdateWidget(PaymentExpanded oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runRotateCheck();
  }

  @override
  void dispose() {
    rotateController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: PaperCard(
        flat: true,
        colouredBorder: widget.isExpanded,
        content: Column(
          children: [
            ListTile(
              leading: Icon(widget.icon, size: 36, color: colorScheme(context).onPrimaryContainer),
              title: Text(widget.title, style: TravelloTheme.subtitle),
              subtitle: Text(widget.subtitle, style: TravelloTheme.paragraph),
              trailing: RotationTransition(
                turns: Tween(begin: 0.0, end: 0.25).animate(animation),
                child: Icon(Icons.arrow_forward_ios_outlined, size: 24, color: colorScheme(context).onSurfaceVariant)
              ),
            ),
            ExpandedSection(
              expand: widget.isExpanded,
              child: widget.child
            )
          ],
        )
      ),
    );
  }
}