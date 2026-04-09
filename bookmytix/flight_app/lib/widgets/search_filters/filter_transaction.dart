import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/models/list_item.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/picker.dart';
import 'package:change_case/change_case.dart';
import 'package:flight_app/ui/themes/theme_button.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:intl/intl.dart';

class FilterTransaction extends StatefulWidget {
  const FilterTransaction({
    super.key,
    required this.sortby,
    required this.category,
    required this.onSortByDate,
    required this.onChangeCategory,
    this.restorationId
  });

  final String sortby;
  final String category;
  final Function(String) onSortByDate;
  final Function(String) onChangeCategory;
  final String? restorationId;

  @override
  State<FilterTransaction> createState() => _FilterTransactionState();
}

class _FilterTransactionState extends State<FilterTransaction> with RestorationMixin {
  String sortbyTemp = '';
  String categoryTemp = '';

  @override
  String? get restorationId => widget.restorationId;

  final RestorableDateTimeN _startDate = RestorableDateTimeN(DateTime(2025));
  final RestorableDateTimeN _endDate = RestorableDateTimeN(DateTime(2025, 1, 5));
  
  late final RestorableRouteFuture<DateTimeRange?> _restorableDateRangePickerRouteFuture =
    RestorableRouteFuture<DateTimeRange?>(
      onComplete: _selectDateRange,
      onPresent: (NavigatorState navigator, Object? arguments) {
        return navigator.restorablePush(
          _dateRangePickerRoute,
          arguments: <String, dynamic>{
            'initialStartDate': _startDate.value?.millisecondsSinceEpoch,
            'initialEndDate': _endDate.value?.millisecondsSinceEpoch,
          },
        );
      },
    );

  void _selectDateRange(DateTimeRange? newSelectedDate) {
    if (newSelectedDate != null) {
      setState(() {
        _startDate.value = newSelectedDate.start;
        _endDate.value = newSelectedDate.end;
      });
    }
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_startDate, 'start_date');
    registerForRestoration(_endDate, 'end_date');
    registerForRestoration(_restorableDateRangePickerRouteFuture, 'date_picker_route_future');
  }

  @pragma('vm:entry-point')
  static Route<DateTimeRange?> _dateRangePickerRoute(BuildContext context, Object? arguments) {
    return DialogRoute<DateTimeRange?>(
      context: context,
      builder: (BuildContext context) {
        return DateRangePickerDialog(
          restorationId: 'date_picker_dialog',
          initialDateRange: _initialDateTimeRange(arguments! as Map<dynamic, dynamic>),
          firstDate: DateTime(2021),
          currentDate: DateTime(2025, 1, 25),
          lastDate: DateTime(2026),
        );
      },
    );
  }

  static DateTimeRange? _initialDateTimeRange(Map<dynamic, dynamic> arguments) {
    if (arguments['initialStartDate'] != null && arguments['initialEndDate'] != null) {
      return DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(arguments['initialStartDate'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(arguments['initialEndDate'] as int),
      );
    }

    return null;
  }

  List<ListItem> sortOptions = [
    ListItem(
      value: 'date_newest',
      label: 'Newest',
      text: 'Sort from the latest released'
    ),
    ListItem(
      value: 'date_oldest',
      label: 'Oldest',
      text: 'Sort from the oldest released'
    ),
    ListItem(
      value: 'price_highest',
      label: 'Highest Price',
      text: 'Sort from the highest price'
    ),
    ListItem(
      value: 'price_lowest',
      label: 'Lowest Price',
      text: 'Sort from the lowest price'
    ),
  ];

  List<ListItem> categoryOptions = [
    ListItem(
      value: 'all',
      label: 'All',
    ),
    ListItem(
      value: 'active',
      label: 'Active',
    ),
    ListItem(
      value: 'waiting',
      label: 'Waiting',
    ),
    ListItem(
      value: 'canceled',
      label: 'Canceled',
    ),
    ListItem(
      value: 'done',
      label: 'Done',
    ),
  ];

  void openSortPicker(BuildContext context) {
    openRadioPicker(
      context: context,
      options: sortOptions,
      title: 'Sort By',
      initialValue: sortbyTemp,
      onSelected: (value) {
        if (value != null) {
          String result = sortOptions.firstWhere((e) => e.value == value).value;
          setState(() {
            sortbyTemp = result;
            switch(result) {
              case 'date_newest':
                widget.onSortByDate('desc');
                break;
              case 'date_oldest':
                widget.onSortByDate('asc');
                break;
              default:
                break;
            }
          });
        }
      }
    );
  }

  void openCategoryPicker(BuildContext context) {
    openRadioPicker(
      context: context,
      options: categoryOptions,
      title: 'Choose Category',
      initialValue: categoryTemp,
      onSelected: (value) {
        if (value != null) {
          String result = categoryOptions.firstWhere((e) => e.value == value).value;
          setState(() {
            categoryTemp = result;
            widget.onChangeCategory(result);
          });
        }
      }
    );
  }

  @override
  void initState() {
    sortbyTemp = widget.sortby;
    categoryTemp = widget.category;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ButtonStyle buttonStyle = ThemeButton.btnSmall.merge(ThemeButton.outlinedDefault(context));
    
    return Column(
      children: [
        /// FILTER BUTTON
        SizedBox(
          width: double.infinity,
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              /// FILTER BY CATEGORY
              SizedBox(width: spacingUnit(2)),
              OutlinedButton(
                onPressed: () {
                  openCategoryPicker(context);
                },
                style: buttonStyle,
                child: Row(children: [
                  Icon(Icons.grid_view_outlined, size: 16, color: ThemePalette.primaryMain),
                  const SizedBox(width: 2),
                  Text('Category: ${categoryTemp.toCapitalCase()}', style: ThemeText.caption),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: colorScheme(context).onSurface, size: 16),
                ])
              ),
        
              /// SORT BY DATE
              SizedBox(width: spacingUnit(1)),
              OutlinedButton(
                onPressed: () {
                  openSortPicker(context);
                },
                style: buttonStyle,
                child: Row(children: [
                  Icon(Icons.swap_vert, size: 16, color: ThemePalette.primaryMain),
                  const SizedBox(width: 2),
                  Text('Sort By ${sortbyTemp.toCapitalCase()}', style: ThemeText.caption),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: colorScheme(context).onSurface, size: 16),
                ])
              ),
        
              /// FILTER DATE
              SizedBox(width: spacingUnit(1)),
              OutlinedButton(
                onPressed: () {
                  _restorableDateRangePickerRouteFuture.present();
                },
                style: buttonStyle,
                child: Row(children: [
                  Icon(Icons.calendar_month, size: 16, color: ThemePalette.primaryMain),
                  const SizedBox(width: 2),
                  Text('${DateFormat.MMMd().format(_startDate.value!)} - ${DateFormat.MMMd().format(_endDate.value!)}', style: ThemeText.caption),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: colorScheme(context).onSurface, size: 16),
                ])
              ),
              
              /// TAG FILTERS
              SizedBox(width: spacingUnit(1)),
              OutlinedButton(
                onPressed: () {},
                style: buttonStyle,
                child: const Text('This Month', style: ThemeText.caption)
              ),
              SizedBox(width: spacingUnit(1)),
              OutlinedButton(
                onPressed: () {},
                style: buttonStyle,
                child: const Text('This Week', style: ThemeText.caption)
              ),
              SizedBox(width: spacingUnit(2)),
            ]
          ),
        ),

        /// TEXT RESULT AND RESET
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(1), horizontal: spacingUnit(2)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('22 Filtered Result', style: ThemeText.paragraph,),
            TextButton(
              onPressed: () {},
              child: Text('RESET FILTER', style: ThemeText.paragraph.copyWith(color: ThemePalette.primaryMain))
            )
          ]),
        )
      ],
    );
  }
}