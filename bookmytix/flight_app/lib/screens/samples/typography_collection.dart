import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TypographyCollection extends StatelessWidget {
  const TypographyCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Typography', style: TravelloTheme.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: const Column(
            children: [
              Text('Font Family:', style: TravelloTheme.headline,),
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
              Text('Font Weight 700', style: TravelloTheme.title2,),
              VSpace(),
              Text('Title', style: TravelloTheme.title,),
              VSpaceShort(),
              Text('Title2', style: TravelloTheme.title2,),
              VSpaceShort(),
              Text('Subtitle', style: TravelloTheme.subtitle,),
              Text('Sed iaculis quis lacus sed malesuada.', style: TravelloTheme.subtitle,),
              VSpaceShort(),
              Text('Subtitle 2', style: TravelloTheme.subtitle2,),
              Text('Sed iaculis quis lacus sed malesuada.', style: TravelloTheme.subtitle2,),
              VSpaceShort(),
              Text('Paragraph Bold', style: TravelloTheme.paragraphBold,),
              Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit, in eleifend lacus dignissim et. ', textAlign: TextAlign.center, style: TravelloTheme.paragraphBold,),
              Divider(height: 50,),
              Text('Font Weight 400', style: TravelloTheme.headline,),
              VSpace(),
              Text('Headline', style: TravelloTheme.headline,),
              Text('Sed iaculis quis lacus sed malesuada.', style: TravelloTheme.headline,),
              VSpaceShort(),
              Text('Paragraph', style: TravelloTheme.paragraph,),
              Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit, in eleifend lacus dignissim et. ', textAlign: TextAlign.center, style: TravelloTheme.paragraph,),
              VSpaceShort(),
              Text('Caption', style: TravelloTheme.caption,),
              Text('Sed iaculis quis lacus sed malesuada.', style: TravelloTheme.caption,),
              VSpaceBig()
            ],
          ),
        ),
      )
    );
  }
}