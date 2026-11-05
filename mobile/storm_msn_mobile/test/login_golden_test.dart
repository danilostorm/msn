import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/main.dart';

void main() {
  testWidgets('WLM 2009 login 360x800 portrait golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const StormMsnApp());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/wlm2009_login_360.png'),
    );
  });

  testWidgets('WLM 2009 login 600x600 landscape golden', (tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const StormMsnApp());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/wlm2009_login_600.png'),
    );
  });
}
