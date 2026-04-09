import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/controllers/payment_form_controller.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/widgets/design_system_animated_price.dart';
import 'package:flight_app/widgets/design_system_page_fade.dart';
import 'package:flight_app/widgets/payment/credit_card_info.dart';
import 'package:flight_app/widgets/payment/identity_form.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

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
        title: const Text('Payment', style: TravelloTheme.subtitle),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('CARD INFORMATION'),
                        const SizedBox(height: 12),
                        const CreditCardInfo(),
                        const SizedBox(height: 24),
                        _sectionLabel('PASSENGER INFORMATION'),
                        const SizedBox(height: 12),
                        const IdentityForm(),
                        const SizedBox(height: 16),
                        _securityBadge(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Sticky CTA bar ────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: TravelloTheme.paperLightContainerLowest,
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
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 32,
                    left: 16,
                    right: 16,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total (incl. taxes)',
                            style: TravelloTheme.paragraph.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                          const DSAnimatedPrice(amount: 630),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DSOutlinedButton(
                              label: 'BACK',
                              onTap: () => Get.back(),
                            ),
                          ),
                          const SizedBox(width: 12),
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
        style: TravelloTheme.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: TravelloTheme.primaryMain,
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
                style: TravelloTheme.caption.copyWith(
                  color: const Color(0xFF065F46),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
