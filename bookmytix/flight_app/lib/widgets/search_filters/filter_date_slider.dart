import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

class FilterDateSlider extends StatefulWidget {
  const FilterDateSlider({super.key});

  @override
  State<FilterDateSlider> createState() => _FilterDateSliderState();
}

class _FilterDateSliderState extends State<FilterDateSlider> {
  final _scrollController = ScrollController();
  final double stepWidth = 35;

  int _currentDate = 7;

  @override
  void initState() {
     SchedulerBinding.instance.addPostFrameCallback((_) => _scrollController.animateTo(
      _currentDate * stepWidth - 16,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn
    ));
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDateSelected(int index) {
    setState(() {
      _currentDate = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> dateList = [
      '13 Oct', '14 Oct', '15 Oct', '16 Oct', '17 Oct',
      '18 Oct', '19 Oct', '20 Oct', '21 Oct', '22 Oct',
      '23 Oct', '24 Oct', '25 Oct', '26 Oct'
    ];

    return SizedBox(
      height: 24,
      child: ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        controller: _scrollController,
        children: List.generate(14, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TagButton(
              size: BtnSize.small,
              text: dateList[index],
              selected: index == _currentDate,
              onPressed: () {
                _onDateSelected(index);
              }
            ),
          );
        }),
      ),
    );
  }
}