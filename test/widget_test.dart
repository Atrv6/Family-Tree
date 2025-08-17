// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree_app/main.dart'; // Make sure this path matches your project

void main() {
  testWidgets('FamilyTreeApp builds and shows title', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(const FamilyTreeApp());

    // Verify the title appears
    expect(find.text('Family Tree'), findsOneWidget);

    // Verify that the "Add Person" button is present
    expect(find.text('Add Person'), findsOneWidget);
  });
}
