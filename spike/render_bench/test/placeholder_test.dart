import 'package:flutter_test/flutter_test.dart';
import 'package:render_bench/main.dart';

void main() {
  testWidgets('placeholder app builds', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    expect(find.textContaining('render_bench'), findsOneWidget);
  });
}
