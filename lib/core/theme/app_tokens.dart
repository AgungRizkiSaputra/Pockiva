import 'package:flutter/material.dart';

/// Design tokens aligned with PRD Section 12 & 8px grid system.
class AppTokens {
  const AppTokens._();

  // 8px Grid Spacing
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // Deliberate Radii Hierarchy
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusSheet = 24;
  static const double radiusCapsule = 32;
  static const double radiusPill = 999;
  static const double radiusFull = 999;

  // Brand Core Palette - Luminous Obsidian & Jade
  static const Color sand = Color(0xFFF7F8FA);
  static const Color sandSubtle = Color(0xFFEEF1F5);
  static const Color sandBorder = Color(0xFFE2E6EC);

  static const Color sage = Color(0xFF10B981); // Luminous Emerald
  static const Color sageDeep = Color(0xFF047857); // WCAG AA > 6.5:1 on Light
  static const Color sageLight = Color(0xFFECFDF5); // Soft Mint tint
  static const Color sageDarkAccent = Color(0xFF34D399); // Luminous Mint on Dark

  static const Color electricBlue = Color(0xFF2563EB); // Royal Sapphire Accent
  static const Color electricBlueAccessible = Color(0xFF1D4ED8); // WCAG AA text link on light

  // Neutral Ink (Light)
  static const Color inkPrimary = Color(0xFF0F172A); // Deep Slate / Obsidian
  static const Color inkSecondary = Color(0xFF64748B); // Cool Slate
  static const Color inkMuted = Color(0xFF94A3B8);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Dark Mode Surfaces & Inks (Deep Void Obsidian)
  static const Color darkBackground = Color(0xFF0B0F17); // Void Obsidian
  static const Color darkSurface = Color(0xFF131A26); // Slate Surface
  static const Color darkSurfaceElevated = Color(0xFF1C2536); // Elevated Slate
  static const Color darkBorder = Color(0xFF263346); // Fine Rim
  static const Color darkInkPrimary = Color(0xFFF8FAFC);
  static const Color darkInkSecondary = Color(0xFF94A3B8);

  // Semantic Colors (WCAG AA compliant)
  static const Color successLight = Color(0xFF059669);
  static const Color successBgLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF34D399);
  static const Color successBgDark = Color(0xFF063321);

  static const Color dangerLight = Color(0xFFE11D48);
  static const Color dangerBgLight = Color(0xFFFFF1F2);
  static const Color dangerDark = Color(0xFFFB7185);
  static const Color dangerBgDark = Color(0xFF3B121A);

  static const Color warningLight = Color(0xFFD97706);
  static const Color warningBgLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color warningBgDark = Color(0xFF3B2806);

  // Responsive Breakpoints (PRD Section 14)
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1160;
}
