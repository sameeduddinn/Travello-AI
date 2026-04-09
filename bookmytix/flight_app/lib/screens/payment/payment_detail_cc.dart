import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/controllers/payment_form_controller.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/widgets/design_system_animated_price.dart';
import 'package:flight_app/widgets/design_system_page_fade.dart';
import 'package:flight_app/widgets/payment/credit_card_info.dart';
import 'package:flight_app/widgets/payment/identity_form.dart';

class PaymentDetailCC extends StatefulWidget {
  const PaymentDetailCC({super.key});

  @override
  State<PaymentDetailCC> createState() => _PaymentDetailCCState();
}

class _PaymentDetailCCState extends State<PaymentDetailCC> {
  final _scrollCtrl = ScrollController();
  late final PaymentFormController _formCtrl;

  @override
  void initState() {
    super.initState();
    _formCtrl = Get.put(PaymentFormController());
  }

  @override
  void dispose() {
    Get.delete<PaymentFormController>();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPay() async {
    final valid = _formCtrl.validateAll(_scrollCtrl);
    if (!valid) return;
    _formCtrl.isLoading.value = true;
    await Future.delayed(const Duration(seconds: 2)); // replace with real API
    _formCtrl.isLoading.value = false;
    Get.toNamed('/payment/status',
        arguments: Get.arguments as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Get.toNamed('/faq'),
          ),
        ],
        centerTitle: true,
        title: const Text('Payment', style: ThemeText.subtitle),
      ),
      body: DSPageFade(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ThemeSize.sm),
            child: Column(
              children: [
                // ── Scrollable form ───────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.all(spacingUnit(2)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('CARD INFORMATION'),
                        SizedBox(height: spacingUnit(1.5)),
                        const CreditCardInfo(),
                        SizedBox(height: spacingUnit(3)),
                        _sectionLabel('PASSENGER INFORMATION'),
                        SizedBox(height: spacingUnit(1.5)),
                        const IdentityForm(),
                        SizedBox(height: spacingUnit(2)),
                        _securityBadge(),
                        SizedBox(height: spacingUnit(2)),
                      ],
                    ),
                  ),
                ),

                // ── Sticky CTA bar ────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme(context).surfaceContainerLowest,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme(context)
                            .outline
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    top: spacingUnit(2),
                    bottom: spacingUnit(4),
                    left: spacingUnit(2),
                    right: spacingUnit(2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total (incl. taxes)',
                            style: ThemeText.paragraph.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                          const DSAnimatedPrice(amount: 630),
                        ],
                      ),
                      SizedBox(height: spacingUnit(1.5)),
                      Row(
                        children: [
                          Expanded(
                            child: DSOutlinedButton(
                              label: 'BACK',
                              onTap: () => Get.back(),
                            ),
                          ),
                          SizedBox(width: spacingUnit(1.5)),
                          Expanded(
                            flex: 2,
                            child: Obx(() => DSButton(
                                  label: 'SECURE PAY',
                                  leadingIcon: Icons.lock_outline,
                                  loading: _formCtrl.isLoading.value,
                                  disabled: !_formCtrl.canPay,
                                  onTap: _onPay,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: ThemeText.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: ThemePalette.primaryMain,
        ),
      );

  Widget _securityBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '256-bit SSL encrypted  ·  PCI DSS Level 1 compliant',
                style: ThemeText.caption.copyWith(
                  color: const Color(0xFF065F46),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
