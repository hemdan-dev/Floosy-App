import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/core/app_theme.dart';

void main() {
  testWidgets('Floosy theme renders its name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('Floosy'))),
      ),
    );

    expect(find.text('Floosy'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
