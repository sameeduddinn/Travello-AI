import 'package:change_case/change_case.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TrainPackageCard extends StatelessWidget {
  const TrainPackageCard({
    super.key,
    required this.image,
    required this.label,
    required this.trainName,
    required this.trainNumber,
    required this.from,
    required this.to,
    required this.date,
    required this.duration,
    required this.tags,
    required this.price,
    required this.trainClass,
    this.roundTrip = true,
  });

  final String image;
  final String label;
  final String trainName;
  final String trainNumber;
  final String from;
  final String to;
  final String date;
  final String duration;
  final List<String> tags;
  final double price;
  final String trainClass;
  final bool roundTrip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        /// IMAGES
        ClipRRect(
          borderRadius: ThemeRadius.medium,
          child: Stack(
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 130,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                      width: double.infinity,
                      height: 130,
                      child: ShimmerPreloader());
                },
              ),
              // ── Discount corner badge — top-left ──────────────────
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: TravelloTheme.secondaryMain,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.start,
                    style: TravelloTheme.paragraphBold
                        .copyWith(color: const Color(0xFF000000)),
                  ),
                ),
              ),
            ],
          ),
        ),

        /// PROPERTIES
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              const SizedBox(height: 100),
              PaperCard(
                  content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(children: [
                  /// DESTINATIONS
                  SizedBox(
                    child: Row(children: [
                      Flexible(
                          child: Text(from,
                              overflow: TextOverflow.ellipsis,
                              style: TravelloTheme.subtitle)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          roundTrip
                              ? CupertinoIcons.arrow_right_arrow_left
                              : CupertinoIcons.arrow_right,
                          size: 16,
                        ),
                      ),
                      Flexible(
                          child: Text(to,
                              overflow: TextOverflow.ellipsis,
                              style: TravelloTheme.subtitle)),
                    ]),
                  ),

                  /// DATE + TRIP TYPE & PRICE
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      date,
                                      overflow: TextOverflow.ellipsis,
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: roundTrip
                                          ? colorScheme(context)
                                              .primaryContainer
                                          : colorScheme(context)
                                              .secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      roundTrip ? 'Round-Trip' : 'One-Way',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              colorScheme(context).onSurface),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Wrap(
                                    spacing: 4,
                                    children: tags.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      String tag = entry.value;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        decoration: BoxDecoration(
                                            borderRadius: ThemeRadius.xsmall,
                                            color: index % 2 == 0
                                                ? colorScheme(context)
                                                    .primaryContainer
                                                : colorScheme(context)
                                                    .secondaryContainer),
                                        child: Text(tag.toCapitalCase(),
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme(context)
                                                    .onSurface)),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                        borderRadius: ThemeRadius.xsmall,
                                        color: colorScheme(context)
                                            .tertiaryContainer),
                                    child: Icon(CupertinoIcons.arrow_uturn_left,
                                        color: colorScheme(context).tertiary,
                                        size: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Start from',
                                style: TravelloTheme.caption.copyWith(
                                    color:
                                        colorScheme(context).onSurfaceVariant),
                              ),
                              Text('Rs.${price.toStringAsFixed(0)}',
                                  style: TravelloTheme.title2.copyWith(
                                      color: TravelloTheme.primaryMain,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1)),
                            ],
                          ),
                        ]),
                  ),

                  /// TRAIN INFO
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: DashedBorder()),
                  Row(children: [
                    Icon(CupertinoIcons.train_style_one,
                        size: 14, color: colorScheme(context).onSurfaceVariant),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '$trainName $trainNumber · $trainClass',
                        overflow: TextOverflow.ellipsis,
                        style: TravelloTheme.caption,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: TravelloTheme.caption.copyWith(
                          color: TravelloTheme.primaryMain,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ]),
              )),
            ],
          ),
        ),
      ],
    );
  }
}
