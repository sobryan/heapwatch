import 'package:flutter_test/flutter_test.dart';

import 'package:heapwatch/main.dart';

void main() {
  testWidgets('App renders HeapWatch title', (WidgetTester tester) async {
    await tester.pumpWidget(const HeapWatchApp());
    expect(find.text('HeapWatch'), findsOneWidget);
  });
}
