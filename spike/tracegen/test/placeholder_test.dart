import 'package:tracegen/tracegen.dart';
import 'package:test/test.dart';

void main() {
  test('library loads', () {
    expect(run, isA<Function>());
  });
}
