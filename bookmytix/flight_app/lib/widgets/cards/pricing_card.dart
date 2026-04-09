import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/expanded_section.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PricingCard extends StatefulWidget {
  const PricingCard({
    super.key,
    required this.mainIcon,
    required this.color,
    required this.title,
    required this.price,
    required this.desc,
    required this.features,
    required this.enableIcons,
    this.isRecomended = false,
  });

  final Widget mainIcon;
  final Color color;
  final String title;
  final double price;
  final String desc;
  final bool isRecomended;
  final List<String> features;
  final List<bool> enableIcons;

  @override
  State<PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<PricingCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaperCard(
        content: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          /// TITLE HEADER
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              if (_isExpanded) {
                _controller.forward();
              } else {
                _controller.reverse();
              }
            },
            child: Row(children: [
              /// ICON
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('Total: 1/999',
                    style: TravelloTheme.caption.copyWith(color: widget.color)),
                const SizedBox(height: 4),
                widget.mainIcon,
              ]),
              const SizedBox(width: 16),

              /// DESCRIPTION
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.title,
                              style: TravelloTheme.title2
                                  .copyWith(fontWeight: FontWeight.bold)),
                          widget.isRecomended
                              ? Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    borderRadius: ThemeRadius.medium,
                                    color: widget.color,
                                  ),
                                  child: Text(' POPULAR ',
                                      style: TravelloTheme.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: TravelloTheme.paperLight)),
                                )
                              : Container()
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
              const SizedBox(width: 16),

              /// PRICE
              Text(widget.price > 0 ? '\$${widget.price}' : 'FREE',
                  style: TravelloTheme.title),

              /// ARROW
              const SizedBox(width: 8),
              RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.25).animate(_controller),
                  child: Icon(Icons.arrow_forward_ios_outlined,
                      size: 24, color: colorScheme(context).onSurfaceVariant)),
            ]),
          ),

          /// BODY DETAIL
          ExpandedSection(
              expand: _isExpanded,
              child: Column(children: [
                ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    physics: const ClampingScrollPhysics(),
                    itemCount: widget.features.length,
                    itemBuilder: ((BuildContext context, int index) {
                      String item = widget.features[index];
                      bool icon = widget.enableIcons[index];

                      return ListTile(
                        leading: icon
                            ? const Icon(Icons.check_circle,
                                color: TravelloTheme.primaryMain)
                            : Icon(Icons.close,
                                color: colorScheme(context)
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                        title: Text(item,
                            style: TravelloTheme.headline.copyWith(
                                color: icon
                                    ? colorScheme(context).onSurface
                                    : colorScheme(context)
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5))),
                      );
                    })),
                const VSpaceShort(),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: () {
                          Get.toNamed('/business-new/payment');
                        },
                        style: ThemeButton.btnBig
                            .merge(ThemeButton.invert(context)),
                        child: const Text(
                          'Choose This Package',
                          style: TravelloTheme.subtitle2,
                        )),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline_rounded, size: 32)),
                ])
              ]))
        ],
      ),
    ));
  }
}
