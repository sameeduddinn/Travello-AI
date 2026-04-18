import 'package:flutter/material.dart';

/// DSPageFade
/// Wraps any page content in a 280ms fade-in + subtle upward slide.
/// Drops directly into Scaffold body — zero configuration needed.
///
/// Why: Airline apps feel premium because pages never "snap" into view.
/// A gentle fade-in signals the transition is intentional, not abrupt.
class DSPageFade extends StatefulWidget {
  const DSPageFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 280),
  });

  final Widget child;

  /// Optional delay before the animation starts (useful for staggered sections)
  final Duration delay;

  /// Total fade-in duration. Keep between 200–320ms for airline-grade feel.
  final Duration duration;

  @override
  State<DSPageFade> createState() => _DSPageFadeState();
}

class _DSPageFadeState extends State<DSPageFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03), // subtle 3% vertical shift
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
