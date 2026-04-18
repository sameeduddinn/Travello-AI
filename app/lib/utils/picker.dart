import 'package:flight_app/models/list_item.dart';
import 'package:flight_app/widgets/app_input/app_bottom_picker.dart';
import 'package:flutter/material.dart';

Future openRadioPicker({
  required BuildContext context,
  required List<ListItem> options,
  required String title,
  String? initialValue,
  required Function(String?) onSelected,
}) async {
  var selectedOption = await showModalBottomSheet<String>(
    context: context,
    barrierColor: Colors.grey.shade800.withValues(alpha: 0.5),
    isScrollControlled: true,
    builder: (BuildContext context) {
      return BottomPickerRadio(
        title: title,
        initialValue: initialValue,
        options: options,
      );
    },
  );
  onSelected(selectedOption);
}
