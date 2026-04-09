import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:pinput/pinput.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/widgets/onboarding/city_selection_sheet.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class OtpForm extends StatefulWidget {
  const OtpForm({super.key});

  @override
  State<OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<OtpForm> {
  late final TextEditingController pinController;
  late final FocusNode focusNode;
  late final GlobalKey<FormState> formKey;

  @override
  void initState() {
    super.initState();
    formKey = GlobalKey<FormState>();
    pinController = TextEditingController();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    pinController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusedBorderColor = Theme.of(context).colorScheme.primary;
    final fillColor = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ThemeSize.xs),
      child: Column(
        children: [
          /// TITLE
          const VSpace(),
          const Text('Check Your Phone', style: TravelloTheme.title2),
          const SizedBox(height: 8),
          Text('We\'ve sent the code to your phone',
              style: TravelloTheme.headline
                  .copyWith(color: colorScheme(context).onSurfaceVariant)),
          const VSpace(),

          /// FORM
          Form(
            key: formKey,
            child: Column(
              children: [
                Directionality(
                  // Specify direction if desired
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    controller: pinController,
                    focusNode: focusNode,
                    defaultPinTheme: defaultPinTheme,
                    separatorBuilder: (index) => const SizedBox(width: 8),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      return value == '1234' ? null : 'Pin is incorrect';
                    },
                    onCompleted: (pin) {
                      debugPrint('onCompleted: $pin');
                    },
                    onChanged: (value) {
                      debugPrint('onChanged: $value');
                    },
                    cursor: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          width: 22,
                          height: 1,
                          color: focusedBorderColor,
                        ),
                      ],
                    ),
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: focusedBorderColor),
                      ),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: focusedBorderColor),
                      ),
                    ),
                    errorPinTheme: defaultPinTheme.copyBorderWith(
                      border: Border.all(color: Colors.redAccent),
                    ),
                  ),
                ),
                const VSpace(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: ThemeButton.btnBig
                        .merge(ThemeButton.tonalPrimary(context)),
                    onPressed: () async {
                      focusNode.unfocus();
                      if (formKey.currentState!.validate()) {
                        // Check if user has set their origin city
                        final hasCity =
                            await LocationPreferenceService.hasOriginCity();

                        if (!context.mounted) return;

                        if (!hasCity) {
                          // Show city selection for new users after verification
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            isDismissible: false,
                            enableDrag: false,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CitySelectionSheet(
                              onComplete: () {
                                Get.toNamed(AppLink.home);
                              },
                            ),
                          );
                        } else {
                          // Already has city preference, go directly to home
                          Get.toNamed(AppLink.home);
                        }
                      }
                    },
                    child: const Text('VERIFY'),
                  ),
                ),
                const VSpaceShort(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: ThemeButton.btnBig,
                    onPressed: null,
                    child: const Text('SEND AGAIN'),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                    text: TextSpan(
                        text: 'Please wait ',
                        style: TravelloTheme.paragraph
                            .copyWith(color: colorScheme(context).onSurface),
                        children: const [
                      TextSpan(
                          text: '1:30',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                        text: ' to send again',
                      )
                    ]))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
