import 'package:flutter_test/flutter_test.dart';
import 'package:render_bench/main.dart';

void main() {
  testWidgets('app shell builds without the map', (tester) async {
    await tester.pumpWidget(const SpikeApp(showMap: false));
    expect(find.textContaining('render_bench'), findsOneWidget);
    expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.textContaining('OpenFreeMap © OpenMapTiles'), findsOneWidget);
  });
}
