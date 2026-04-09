import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class TypographyCollection extends StatelessWidget {
  const TypographyCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Typography', style: ThemeText.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(spacingUnit(2)),
          child: const Column(
            children: [
              Text('Font Family:', style: ThemeText.headline,),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.all(Radius.circular(20))
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ubuntu', textAlign: TextAlign.center, style: TextStyle(fontSize: 48, color: Colors.white),),
                )
              ),
              Divider(height: 50,),
              TitleBasic(title: 'Title Basic Widget', desc: 'Description Text for Title Basic Widget',),
              VSpaceShort(),
              TitleBasicSmall(title: 'Title Basic Small Widget', desc: 'Description Text for Title Basic Small Widget',),
              Divider(height: 50,),
              Text('Font Weight 700', style: ThemeText.title2,),
              VSpace(),
              Text('Title', style: ThemeText.title,),
              VSpaceShort(),
              Text('Title2', style: ThemeText.title2,),
              VSpaceShort(),
              Text('Subtitle', style: ThemeText.subtitle,),
              Text('Sed iaculis quis lacus sed malesuada.', style: ThemeText.subtitle,),
              VSpaceShort(),
              Text('Subtitle 2', style: ThemeText.subtitle2,),
              Text('Sed iaculis quis lacus sed malesuada.', style: ThemeText.subtitle2,),
              VSpaceShort(),
              Text('Paragraph Bold', style: ThemeText.paragraphBold,),
              Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit, in eleifend lacus dignissim et. ', textAlign: TextAlign.center, style: ThemeText.paragraphBold,),
              Divider(height: 50,),
              Text('Font Weight 400', style: ThemeText.headline,),
              VSpace(),
              Text('Headline', style: ThemeText.headline,),
              Text('Sed iaculis quis lacus sed malesuada.', style: ThemeText.headline,),
              VSpaceShort(),
              Text('Paragraph', style: ThemeText.paragraph,),
              Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit, in eleifend lacus dignissim et. ', textAlign: TextAlign.center, style: ThemeText.paragraph,),
              VSpaceShort(),
              Text('Caption', style: ThemeText.caption,),
              Text('Sed iaculis quis lacus sed malesuada.', style: ThemeText.caption,),
              VSpaceBig()
            ],
          ),
        ),
      )
    );
  }
}