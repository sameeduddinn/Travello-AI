import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flutter/material.dart';

final List<String> tagFilter = ['All', 'Flight', 'Hotel', 'Shopping', 'Discount', 'Food', 'Fashion'];

class TagFilterReward extends StatefulWidget {
  const TagFilterReward({super.key});

  @override
  State<TagFilterReward> createState() => _TagFilterRewardState();
}

class _TagFilterRewardState extends State<TagFilterReward> {
  final List<String> _selected = [tagFilter[0]];

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: 26,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tagFilter.length,
        itemBuilder: (context, index) {
          String item = tagFilter[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 4,
              right: 4
            ),
            child: TagButton(
              size: BtnSize.medium,
              text: item,
              selected: _selected.contains(item),
              onPressed: () {
                setState(() {
                  if (!_selected.contains(item)) {
                    _selected.add(item);
                  } else {
                    _selected.remove(item);
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }
}