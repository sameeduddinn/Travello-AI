import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AppInputNumber extends StatefulWidget {
  const AppInputNumber({
    super.key,
    this.onAdd,
    this.onRemove,
    this.value,
    this.maxValue,
    this.unit,
  });

  final Function()? onAdd;
  final Function()? onRemove;
  final double? value;
  final double? maxValue;
  final String? unit;

  @override
  State<AppInputNumber> createState() => _AppInputNumberState();
}

class _AppInputNumberState extends State<AppInputNumber> {
  double _localValue = 0;

  void onAdd() {
    if (widget.maxValue != null && _localValue >= widget.maxValue!) return;
    setState(() {
      _localValue++;
    });
  }

  void onRemove() {
    if (_localValue == 0) return;
    setState(() {
      _localValue--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      IconButton(
        onPressed: widget.onRemove ?? onRemove,
        icon: const Icon(Icons.remove_circle_outline, color: TravelloTheme.primaryMain,),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(widget.value != null ? widget.value.toString() : _localValue.toString(), style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold),),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: widget.unit != null ? Text(widget.unit!) : Container(),
      ),
      IconButton(
        onPressed: widget.onAdd ?? onAdd,
        icon: const Icon(Icons.add_circle_outline, color: TravelloTheme.primaryMain,),
      ),
    ]);
  }
}