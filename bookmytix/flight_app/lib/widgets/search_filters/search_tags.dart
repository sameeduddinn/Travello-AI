import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_radius.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/search_history_service.dart';

class TagHistory extends StatefulWidget {
  const TagHistory({super.key, this.onTagTap});

  final Function(String)? onTagTap;

  @override
  State<TagHistory> createState() => _TagHistoryState();
}

class _TagHistoryState extends State<TagHistory> {
  List<String> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final mode = await SearchHistoryService.getTravelMode();
    final history = mode == 'flight'
        ? await SearchHistoryService.getFlightHistory()
        : await SearchHistoryService.getTrainHistory();

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Default trending cities if no history
    final List<String> defaultCities = [
      'Lahore',
      'Karachi',
      'Islamabad',
      'Multan',
      'Peshawar'
    ];

    final displayList = _history.isEmpty ? defaultCities : _history;

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacingUnit(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search History',
              style: ThemeText.subtitle.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: spacingUnit(1.5)),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: displayList
                  .map((item) => Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (widget.onTagTap != null) {
                              widget.onTagTap!(item);
                            }
                          },
                          borderRadius: ThemeRadius.big,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                borderRadius: ThemeRadius.big,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest),
                            child: Text(item, style: ThemeText.paragraph),
                          ),
                        ),
                      ))
                  .toList())
        ],
      ),
    );
  }
}

class TagTrending extends StatelessWidget {
  const TagTrending({super.key, this.onTagTap});

  final Function(String)? onTagTap;

  @override
  Widget build(BuildContext context) {
    final List<String> tagsList = [
      'Gilgit',
      'Skardu',
      'Murree',
      'Quetta',
      'Faisalabad'
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacingUnit(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending Search',
              style: ThemeText.subtitle.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: spacingUnit(1.5)),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: tagsList
                  .map((item) => Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (onTagTap != null) {
                              onTagTap!(item);
                            }
                          },
                          borderRadius: ThemeRadius.big,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                borderRadius: ThemeRadius.big,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.trending_up,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                              const SizedBox(width: 4),
                              Text(item,
                                  style: ThemeText.paragraph.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer))
                            ]),
                          ),
                        ),
                      ))
                  .toList())
        ],
      ),
    );
  }
}
