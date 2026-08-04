import 'dart:ui' show ViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dynamic Type sizes used by the iOS layout matrix.
abstract final class IosDynamicType {
  static const standard = 1.0;
  static const accessibilityLarge = 2.0;
  static const accessibilityExtraLarge = 2.5;
  static const accessibilityExtraExtraExtraLarge = 3.2;

  static const presets = <double>[
    standard,
    accessibilityLarge,
    accessibilityExtraLarge,
    accessibilityExtraExtraExtraLarge,
  ];
}

/// A logical iOS viewport with safe-area geometry expressed in logical points.
///
/// These host-test profiles model common iPhone windows. They are layout
/// regression inputs, not substitutes for simulator or physical-device runs.
@immutable
class IosDeviceViewport {
  const IosDeviceViewport({
    required this.name,
    required this.logicalSize,
    required this.devicePixelRatio,
    required this.viewPadding,
    EdgeInsets? padding,
    this.viewInsets = EdgeInsets.zero,
  }) : padding = padding ?? viewPadding;

  final String name;
  final Size logicalSize;
  final double devicePixelRatio;
  final EdgeInsets viewPadding;
  final EdgeInsets padding;
  final EdgeInsets viewInsets;

  bool get isLandscape => logicalSize.width > logicalSize.height;

  IosDeviceViewport withKeyboard({double? height}) {
    final keyboardHeight = height ?? logicalSize.height * 0.42;
    return IosDeviceViewport(
      name: '$name + keyboard',
      logicalSize: logicalSize,
      devicePixelRatio: devicePixelRatio,
      viewPadding: viewPadding,
      padding: padding.copyWith(bottom: 0),
      viewInsets: viewInsets.copyWith(bottom: keyboardHeight),
    );
  }

  static const iPhoneSe = IosDeviceViewport(
    name: 'iPhone SE 320x568',
    logicalSize: Size(320, 568),
    devicePixelRatio: 2,
    viewPadding: EdgeInsets.only(top: 20),
  );

  static const iPhone375 = IosDeviceViewport(
    name: 'iPhone 375x667',
    logicalSize: Size(375, 667),
    devicePixelRatio: 2,
    viewPadding: EdgeInsets.only(top: 20),
  );

  static const standard = IosDeviceViewport(
    name: 'iPhone standard 390x844',
    logicalSize: Size(390, 844),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.only(top: 47, bottom: 34),
  );

  static const pro393 = IosDeviceViewport(
    name: 'iPhone Pro 393x852',
    logicalSize: Size(393, 852),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  static const pro402 = IosDeviceViewport(
    name: 'iPhone Pro 402x874',
    logicalSize: Size(402, 874),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.only(top: 62, bottom: 34),
  );

  static const proMax = IosDeviceViewport(
    name: 'iPhone Pro Max 430x932',
    logicalSize: Size(430, 932),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  static const iPhoneSeLandscape = IosDeviceViewport(
    name: 'iPhone SE 568x320 landscape',
    logicalSize: Size(568, 320),
    devicePixelRatio: 2,
    viewPadding: EdgeInsets.zero,
  );

  static const iPhone375Landscape = IosDeviceViewport(
    name: 'iPhone 667x375 landscape',
    logicalSize: Size(667, 375),
    devicePixelRatio: 2,
    viewPadding: EdgeInsets.zero,
  );

  static const standardLandscape = IosDeviceViewport(
    name: 'iPhone standard 844x390 landscape',
    logicalSize: Size(844, 390),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.fromLTRB(47, 0, 47, 21),
  );

  static const pro393Landscape = IosDeviceViewport(
    name: 'iPhone Pro 852x393 landscape',
    logicalSize: Size(852, 393),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.fromLTRB(59, 0, 59, 21),
  );

  static const pro402Landscape = IosDeviceViewport(
    name: 'iPhone Pro 874x402 landscape',
    logicalSize: Size(874, 402),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.fromLTRB(62, 0, 62, 21),
  );

  static const proMaxLandscape = IosDeviceViewport(
    name: 'iPhone Pro Max 932x430 landscape',
    logicalSize: Size(932, 430),
    devicePixelRatio: 3,
    viewPadding: EdgeInsets.fromLTRB(59, 0, 59, 21),
  );

  static const portrait = <IosDeviceViewport>[
    iPhoneSe,
    iPhone375,
    standard,
    pro393,
    pro402,
    proMax,
  ];

  static const landscape = <IosDeviceViewport>[
    iPhoneSeLandscape,
    iPhone375Landscape,
    standardLandscape,
    pro393Landscape,
    pro402Landscape,
    proMaxLandscape,
  ];

  static const all = <IosDeviceViewport>[...portrait, ...landscape];
}

/// Applies a profile to the test view and restores every changed value.
///
/// Register once per widget test before pumping the application. The returned
/// callback is also useful when a test needs to restore before its own teardown.
VoidCallback applyIosDeviceViewport(
  WidgetTester tester,
  IosDeviceViewport viewport, {
  double textScale = IosDynamicType.standard,
  double? keyboardHeight,
}) {
  final view = tester.view;
  final dispatcher = tester.platformDispatcher;
  final originalPhysicalSize = view.physicalSize;
  final originalDevicePixelRatio = view.devicePixelRatio;
  final originalPadding = _copyPadding(view.padding);
  final originalViewPadding = _copyPadding(view.viewPadding);
  final originalViewInsets = _copyPadding(view.viewInsets);
  final originalTextScale = dispatcher.textScaleFactor;
  var restored = false;

  final configured = keyboardHeight == null
      ? viewport
      : viewport.withKeyboard(height: keyboardHeight);
  view.devicePixelRatio = configured.devicePixelRatio;
  view.physicalSize = Size(
    configured.logicalSize.width * configured.devicePixelRatio,
    configured.logicalSize.height * configured.devicePixelRatio,
  );
  view.viewPadding = _fakePadding(
    configured.viewPadding,
    configured.devicePixelRatio,
  );
  view.padding = _fakePadding(configured.padding, configured.devicePixelRatio);
  view.viewInsets = _fakePadding(
    configured.viewInsets,
    configured.devicePixelRatio,
  );
  dispatcher.textScaleFactorTestValue = textScale;

  void restore() {
    if (restored) return;
    restored = true;
    view.devicePixelRatio = originalDevicePixelRatio;
    view.physicalSize = originalPhysicalSize;
    view.viewPadding = _fakePadding(originalViewPadding);
    view.padding = _fakePadding(originalPadding);
    view.viewInsets = _fakePadding(originalViewInsets);
    dispatcher.textScaleFactorTestValue = originalTextScale;
  }

  addTearDown(restore);
  return restore;
}

EdgeInsets _copyPadding(ViewPadding value) =>
    EdgeInsets.fromLTRB(value.left, value.top, value.right, value.bottom);

FakeViewPadding _fakePadding(EdgeInsets value, [double scale = 1]) =>
    FakeViewPadding(
      left: value.left * scale,
      top: value.top * scale,
      right: value.right * scale,
      bottom: value.bottom * scale,
    );
