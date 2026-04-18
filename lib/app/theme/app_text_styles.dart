import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const heading1 = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);
  static const heading2 = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.25);
  static const heading3 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);
  static const heading4 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35);
  static const subtitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static const caption = TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1.4);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.0);
  static const metricValue = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2);
}
