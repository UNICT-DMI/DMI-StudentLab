import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentLab app', () {
    testWidgets(
      'crea correttamente l applicazione principale',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MyApp(),
        );

        expect(
          find.byType(MaterialApp),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'usa StudentLab come titolo applicazione',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MyApp(),
        );

        final MaterialApp app =
            tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(
          app.title,
          'StudentLab',
        );
      },
    );
  });
}