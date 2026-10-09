import 'package:flutter_test/flutter_test.dart';
import 'package:h3_eval/main.dart';

void main() {
  testWidgets('placeholder app builds', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    expect(find.textContaining('h3_eval'), findsOneWidget);
  });
}
