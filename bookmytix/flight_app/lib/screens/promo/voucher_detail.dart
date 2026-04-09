import 'package:change_case/change_case.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/promo.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/widgets/promo/promo_desc.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class VoucherDetail extends StatefulWidget {
  const VoucherDetail({
    super.key,
  });

  @override
  State<VoucherDetail> createState() => _VoucherDetailState();
}

class _VoucherDetailState extends State<VoucherDetail> {
  final ScrollController _scrollref = ScrollController();

  bool _isFixed = false;

  @override
  void dispose() {
    _scrollref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Promotion promoItem = promoList[1]; 

    _scrollref.addListener(() {
      setState(() {
        if(_scrollref.offset > 100) {
          _isFixed = true;
        } else {
          _isFixed = false;
        }
      });
    });
  
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        forceMaterialTransparency: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
        centerTitle: false,
        titleSpacing: 0,
        /// TITLE
        title: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: _isFixed ? 1 : 0)),
          child: Text(
            promoItem.name.toCapitalCase(),
            overflow: TextOverflow.ellipsis,
            style: TravelloTheme.subtitle2,
          ),
        ),
        actions: [
          // POINT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: ThemeRadius.big
            ),
            child: Text('${promoItem.price} POINT', style: TravelloTheme.paragraph)
          ),
          const SizedBox(width: 8),
          /// LIKED
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [ThemeShade.shadeMedium(context)],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_outlined,
                size: 16,
                color: Colors.pink
              )
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ThemeSize.sm),
          child: ListView(
            controller: _scrollref,
            children: [
              /// EVENT BANNER HERO AND DESCRIPTON
              PromoDesc(
                title: promoItem.name.toCapitalCase(),
                desc: promoItem.desc,
                thumb: promoItem.thumb,
                terms1: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                terms2: 'Integer sem massa, interdum commodo leo ac, posuere molestie leo',
                terms3: 'Sed iaculis quis lacus sed malesuada. Nam suscipit lacus',
                date: promoItem.date,
                point: promoItem.price,
                liked: true
              ),
            ]
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 24
        ),
        child: Center(
          child: Container(
            height: 48,
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: ThemeSize.sm),
            child: OutlinedButton(
              onPressed: () {
                Get.toNamed(AppLink.searchFlight);
              },
              style: ThemeButton.btnBig.merge(ThemeButton.outlinedSecondary(context)),
              child: const Text('USE THIS COUPON', style: TravelloTheme.subtitle2)
            ),
          ),
        ),
      ),
    );
  }
}
