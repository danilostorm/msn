import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/main.dart';

void main() {
  testWidgets('login renders WLM mobile branding and credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const StormMsnApp());
    expect(find.text('Windows Live Messenger'), findsOneWidget);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('Entrar no Messenger'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
  layoutTests();
}

void layoutTests() {
  testWidgets('compact login fits 360 pixel phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const StormMsnApp());
    expect(find.text('Entrar no Messenger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide login keeps classic card centered', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const StormMsnApp());
    expect(find.text('Windows Live Messenger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
