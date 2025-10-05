// Basic Flutter widget test for verifying counter increment functionality.
//
// Use WidgetTester from the flutter_test package to interact with widgets, perform gestures, and verify widget properties and values.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ledgerlite/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const PatoTrack());

    // Verify that the counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame update.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that the counter has incremented to 1.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
