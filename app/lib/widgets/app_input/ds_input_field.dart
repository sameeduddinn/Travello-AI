import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// DSInputField
/// Airline-grade form field with:
/// • Animated focus ring (200ms ease-out border color transition)
/// • Inline error message with fade-in + slide-down (250ms)
/// • Real-time validation on change via [validator]
/// • Support for [inputFormatters], obscure text, custom suffix/prefix
/// • Accessible labels — always-visible top label, not floating
class DSInputField extends StatefulWidget {
  const DSInputField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.autofillHints,
    this.prefixText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final String? prefixText;

  @override
  State<DSInputField> createState() => _DSInputFieldState();
}

class _DSInputFieldState extends State<DSInputField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  String? _errorText;
  bool _isDirty = false;

  // Animation for error message
  late AnimationController _errorAnimCtrl;
  late Animation<double> _errorFade;
  late Animation<Offset> _errorSlide;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _errorAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _errorFade = CurvedAnimation(
      parent: _errorAnimCtrl,
      curve: Curves.easeOut,
    );
    _errorSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _errorAnimCtrl,
      curve: Curves.easeOut,
    ));
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    // Validate on blur if already dirty
    if (!_focusNode.hasFocus && _isDirty) {
      _runValidation(widget.controller.text);
    }
  }

  void _runValidation(String value) {
    if (widget.validator == null) return;
    final error = widget.validator!(value);
    setState(() => _errorText = error);
    if (error != null) {
      _errorAnimCtrl.forward(from: 0);
    } else {
      _errorAnimCtrl.reverse();
    }
  }

  // Public: force-validate (called by form submission)
  void forceValidate() {
    _isDirty = true;
    _runValidation(widget.controller.text);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _errorAnimCtrl.dispose();
    super.dispose();
  }

  // ── Colors based on state ─────────────────────────────────────────────────
  Color get _borderColor {
    if (_errorText != null) return const Color(0xFFDC2626);
    if (_isFocused) return TravelloTheme.primaryMain;
    return const Color(0xFFE2E8F0);
  }

  double get _borderWidth {
    if (_errorText != null || _isFocused) return 1.5;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ─────────────────────────────────────────────────────────────
        Text(
          widget.label,
          style: TravelloTheme.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: _errorText != null
                ? const Color(0xFFDC2626)
                : isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF475569),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),

        // ── Animated border container ─────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFBFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _borderColor,
              width: _borderWidth,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            onTap: widget.onTap,
            style: TravelloTheme.paragraph.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            onChanged: (val) {
              _isDirty = true;
              _runValidation(val);
              widget.onChanged?.call(val);
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TravelloTheme.paragraph.copyWith(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: widget.maxLines == 1 ? 12 : 14,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 18,
                      color: _isFocused
                          ? TravelloTheme.primaryMain
                          : const Color(0xFF94A3B8),
                    )
                  : null,
              prefixText: widget.prefixText,
              prefixStyle: TravelloTheme.paragraph.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: TravelloTheme.primaryMain,
              ),
              suffixIcon: widget.suffix,
              // suppress default Flutter error display — we render our own
              errorStyle: const TextStyle(fontSize: 0, height: 0),
            ),
          ),
        ),

        // ── Animated error message ─────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _errorText != null
              ? FadeTransition(
                  opacity: _errorFade,
                  child: SlideTransition(
                    position: _errorSlide,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5, left: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 12,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _errorText!,
                              style: TravelloTheme.caption.copyWith(
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
