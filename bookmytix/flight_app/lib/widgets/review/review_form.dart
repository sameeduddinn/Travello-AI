import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/widgets/review/rating_star.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ReviewForm extends StatefulWidget {
  const ReviewForm({super.key});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  String _review = 'Awesome';
  bool _showKeyboard = false;

  void handleChange(val) {
    setState(() {
      switch(val) {
        case 1:
          _review = 'Worst';
        break;
        case 2:
          _review = 'Bad';
        break;
        case 3:
          _review = 'Not Bad';
        break;
        case 4:
          _review = 'Good';
        break;
        default:
          _review = 'Awesome';
        break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const GrabberIcon(),
        const VSpace(),
        
        /// TEXT
        Text('Write Review', textAlign: TextAlign.center, style: TravelloTheme.title2.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Click the star to change the rating. IMPORTANT: Reviews are public and include your name and avatar,', textAlign: TextAlign.center),
        const VSpace(),

        /// FORM
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RatingStar(initVal: 5, size: 32, onChanged: handleChange),
          const SizedBox(width: 8),
          Text(_review, style: TravelloTheme.subtitle)
        ]),
        const VSpace(),
        AppTextField(
          label: 'Write your description',
          maxLines: 4,
          onChanged: (_) {},
          focusCallback: () {
            setState(() {
              _showKeyboard = true;
            });
          },
          blurCallback: () {
            setState(() {
              _showKeyboard = false;
            });
          },
        ),
        const VSpace(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Get.back();
            },
            style: ThemeButton.btnBig.merge(ThemeButton.primary),
            child: const Text('POST REVIEW'),
          ),
        ),
        const VSpaceBig(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: _showKeyboard ? 300 : 0,
        )
      ]),
    );
  }
}