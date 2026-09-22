/// Shared layout widths for phone, tablet, and desktop shells.
abstract final class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Viewports narrower than this use the bottom navigation bar.
  static const double mobileMax = 640;

  /// Viewports wider than this use the extended sidebar.
  static const double desktopMin = 1024;

  static const double mobileTouchTarget = 48;
  static const double desktopTouchTarget = 32;

  static bool isMobile(double width) => width < mobileMax;

  static bool isTablet(double width) =>
      width >= mobileMax && width <= desktopMin;

  static bool isDesktop(double width) => width > desktopMin;
}
