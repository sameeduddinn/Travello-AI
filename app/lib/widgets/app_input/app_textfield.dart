import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.initialValue,
    this.height = 50,
    this.readOnly = false,
    this.maxLines = 1,
    this.controller,
    this.prefixIcon,
    this.suffix,
    this.onTap,
    this.obscureText = false,
    this.validator,
    this.focusCallback,
    this.blurCallback,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final String? hint;
  final String? errorText;
  final String? initialValue;
  final double height;
  final bool readOnly;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final void Function()? onTap;
  final void Function(String) onChanged;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Function()? focusCallback;
  final Function()? blurCallback;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final focusNode = FocusNode();
  bool boxFocus = false;

  @override
  void initState() {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (widget.focusCallback != null) {
          widget.focusCallback!();
        }
        setState(() {
          boxFocus = true;
        });
      } else {
        if (widget.blurCallback != null) {
          widget.blurCallback!();
        }
        setState(() {
          boxFocus = false;
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeBorderColor = widget.errorText != null
        ? Colors.red[400]!
        : boxFocus
            ? TravelloTheme.primaryMain
            : Theme.of(context).colorScheme.outline;

    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: ThemeRadius.small,
      borderSide:
          BorderSide(color: activeBorderColor, width: boxFocus ? 1.8 : 1.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          focusNode: focusNode,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          obscureText: widget.maxLines == 1 ? widget.obscureText : false,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onTap: widget.onTap,
          onChanged: (String value) => widget.onChanged(value),
          validator: widget.validator,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: TextStyle(
              color: widget.errorText != null
                  ? Colors.red[400]
                  : boxFocus
                      ? TravelloTheme.primaryMain
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
            ),
            hintStyle: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            alignLabelWithHint: widget.maxLines != 1,
            errorText: widget.errorText,
            errorStyle: TravelloTheme.caption.copyWith(color: Colors.red[400]),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
            errorBorder: OutlineInputBorder(
              borderRadius: ThemeRadius.small,
              borderSide: BorderSide(color: Colors.red[400]!, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: ThemeRadius.small,
              borderSide: BorderSide(color: Colors.red[400]!, width: 1.8),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20)
                : null,
            suffixIcon: widget.suffix,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
        ),
      ],
    );
  }
}
