import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary gradient
  static const primaryStart = Color(0xFF5B6FD8);
  static const primaryEnd = Color(0xFF7C4DFF);
  static const primaryMid = Color(0xFF6B5FD8);
  static const primaryHoverStart = Color(0xFF4D5FC7);
  static const primaryHoverEnd = Color(0xFF6B3EEF);

  // Dark surfaces
  static const darkBg = Color(0xFF0A0A0F);
  static const darkNav = Color(0xFF0F0F14);
  static const darkPanel = Color(0xFF121218);
  static const darkCardFill = Color(0x0DFFFFFF);
  static const darkCardBorder = Color(0x1AFFFFFF);
  static const darkNavBg = Color(0xE60F0F14); // 90%
  static const darkPanelBg = Color(0xF2121218); // 95%

  // Light surfaces
  static const lightBgStart = Color(0xFFE8EAFF);
  static const lightBgMid = Color(0xFFF5F3FF);
  static const lightBgEnd = Color(0xFFFDF4FF);
  static const lightCardFill = Color(0x80FFFFFF); // 50%
  static const lightCardBorder = Color(0x99FFFFFF); // 60%
  static const lightNavBg = Color(0xCCFFFFFF); // 80%
  static const lightPanelBg = Color(0xE6FFFFFF); // 90%

  // Text
  static const darkText = Color(0xFFFFFFFF);
  static const darkSecondaryText = Color(0xFF9CA3AF); // gray-400
  static const lightText = Color(0xFF1A1A2E);
  static const lightSecondaryText = Color(0xFF4B5563); // gray-600

  // Accents
  static const teal = Color(0xFF4ECDC4);
  static const tealDark = Color(0xFF44A6A0);
  static const yellow = Color(0xFFFFD93D);
  static const yellowDark = Color(0xFFFFC93D);
  static const pink = Color(0xFFFF6B9D);
  static const pinkLight = Color(0xFFFF8FA3);
  static const red = Color(0xFFFF6B6B);
  static const coral = Color(0xFFFF8787);

  // Chart lines
  static const chartFlow = Color(0xFF5B6FD8);
  static const chartDebugging = Color(0xFFFF6B6B);
  static const chartResearch = Color(0xFF4ECDC4);
  static const chartCommunication = Color(0xFFFFD93D);
  static const chartDistracted = Color(0xFFFF6B9D);

  // Misc
  static const unreadBadge = Color(0xFF5B6FD8);
  static const destructive = Color(0xFFD4183D);

  // Glass helpers
  static const glassDarkFill = Color(0x0DFFFFFF);
  static const glassDarkBorder = Color(0x1AFFFFFF);
  static const glassLightFill = Color(0x80FFFFFF);
  static const glassLightBorder = Color(0x99FFFFFF);

  // Orb colors
  static const orbPurpleDark = Color(0x269B59B6); // purple-600/15
  static const orbBlueDark = Color(0x142563EB); // blue-600/8
  static const orbPurpleLight = Color(0x14A78BFA); // purple-400/8

  static const primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
  );

  static const agentCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE67C4DFF), // 90%
      Color(0xE66B5FD8),
      Color(0xE65B6FD8),
    ],
  );
}
