import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_text.dart';

/// DSButton
/// Airline-grade primary button with:
/// • Scale press feedback (1.0 → 0.97, 80ms ease-out) — tactile confirmation
/// • Smooth color transition for disabled state (200ms)
/// • Loading state with inline spinner — communicates active processing
/// • [trailingIcon] slot for lock icon, arrow, etc.
class DSButton extends StatefulWidget {
  const DSButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.width = double.infinity,
    this.height = 52.0,
    this.color,
    this.textColor,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool disabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double width;
  final double height;
  final Color? color;
  final Color? textColor;
  final double? borderRadius;

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.disabled || widget.loading;

  void _onTapDown(TapDownDetails _) {
    if (_isDisabled) return;
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressCtrl.reverse();
    if (!_isDisabled) widget.onTap?.call();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDisabled
        ? const Color(0xFFCBD5E1)
        : (widget.color ?? ThemePalette.primaryMain);

    final fgColor = _isDisabled
        ? const Color(0xFF94A3B8)
        : (widget.textColor ?? Colors.white);

    return MouseRegion(
      cursor:
          _isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered && !_isDisabled
                  ? (widget.color ?? ThemePalette.primaryMain)
                      .withValues(alpha: 0.88)
                  : bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 12),
              boxShadow: _isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: (widget.color ?? ThemePalette.primaryMain)
                            .withValues(
                                alpha: _isPressed
                                    ? 0.18
                                    : (_isHovered ? 0.34 : 0.26)),
                        blurRadius: _isPressed ? 6 : (_isHovered ? 16 : 12),
                        offset:
                            Offset(0, _isPressed ? 2 : (_isHovered ? 6 : 4)),
                      ),
                    ],
            ),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, size: 18, color: fgColor),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: ThemeText.paragraphBold.copyWith(
                            color: fgColor,
                            fontSize: 15,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(widget.trailingIcon, size: 18, color: fgColor),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DSOutlinedButton
/// Secondary variant — transparent background with brand-colored border.
class DSOutlinedButton extends StatefulWidget {
  const DSOutlinedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
    this.leadingIcon,
    this.width = double.infinity,
    this.height = 52.0,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool disabled;
  final IconData? leadingIcon;
  final double width;
  final double height;

  @override
  State<DSOutlinedButton> createState() => _DSOutlinedButtonState();
}

class _DSOutlinedButtonState extends State<DSOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.disabled || widget.loading;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          _isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (!_isDisabled) _pressCtrl.forward();
        },
        onTapUp: (_) {
          _pressCtrl.reverse();
          if (!_isDisabled) widget.onTap?.call();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered && !_isDisabled
                  ? ThemePalette.primaryMain.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDisabled
                    ? const Color(0xFFCBD5E1)
                    : ThemePalette.primaryMain,
                width: _isHovered ? 2.0 : 1.5,
              ),
            ),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            ThemePalette.primaryMain),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon,
                              size: 18,
                              color: _isDisabled
                                  ? const Color(0xFF94A3B8)
                                  : ThemePalette.primaryMain),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: ThemeText.paragraphBold.copyWith(
                            color: _isDisabled
                                ? const Color(0xFF94A3B8)
                                : ThemePalette.primaryMain,
                            fontSize: 15,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
