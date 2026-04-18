import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive helper for scaling UI across different Android phone sizes.
///
/// Reference device: Pixel 4a (1080x2340, ~393x851 logical pixels)
/// Target range: 720x1440 (5.7") to 1080x2400 (6.7")
class R {
  R._();

  // Reference logical dimensions (Pixel 4a)
  static const double _refWidth = 393.0;
  static const double _refHeight = 851.0;

  /// Returns a percentage of screen width.
  /// Example: R.w(context, 50) returns 50% of screen width.
  static double w(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * (percent / 100);
  }

  /// Returns a percentage of screen height.
  /// Example: R.h(context, 10) returns 10% of screen height.
  static double h(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * (percent / 100);
  }

  /// Returns a responsive font size scaled relative to the reference width.
  /// Clamps between 0.85x and 1.15x to avoid extreme scaling.
  static double sp(BuildContext context, double size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / _refWidth).clamp(0.85, 1.15);
    return size * scale;
  }

  /// Returns a responsive size (padding, margin, icon, etc.) scaled
  /// relative to the reference width. Clamps between 0.82x and 1.18x.
  static double r(BuildContext context, double size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / _refWidth).clamp(0.82, 1.18);
    return size * scale;
  }

  /// Returns true if the device is a small phone (width < 370 logical pixels).
  /// e.g. Oppo A83 (360 logical width)
  static bool isSmall(BuildContext context) {
    return MediaQuery.of(context).size.width < 370;
  }

  /// Returns true if the device has a short screen (height < 700 logical pixels).
  static bool isShort(BuildContext context) {
    return MediaQuery.of(context).size.height < 700;
  }

  /// Screen width in logical pixels.
  static double screenW(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Screen height in logical pixels.
  static double screenH(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Returns a responsive horizontal padding — smaller on small phones.
  static double hPad(BuildContext context) {
    return r(context, 16);
  }

  /// Returns a responsive vertical padding — smaller on short screens.
  static double vPad(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = (screenHeight / _refHeight).clamp(0.82, 1.18);
    return 16 * scale;
  }

  /// Scale a height value relative to the reference height.
  /// Useful for SizedBox heights, image heights, etc.
  static double rh(BuildContext context, double size) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = (screenHeight / _refHeight).clamp(0.82, 1.18);
    return size * scale;
  }

  /// Returns the smaller of width-scaled and height-scaled values.
  /// Useful for square elements that shouldn't overflow in either direction.
  static double rMin(BuildContext context, double size) {
    return min(r(context, size), rh(context, size));
  }
}
