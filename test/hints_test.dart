import 'package:flutter_test/flutter_test.dart';
import 'package:last_launcher/shared/data/hints.dart';

void main() {
  group('computeHints', () {
    test('returns null for single app', () {
      final result = computeHints(['Only'], ['Only']);
      expect(result['Only'], isNull);
    });

    test('returns null for empty list', () {
      final result = computeHints([], []);
      expect(result, isEmpty);
    });

    test('shortest unique character in simple case', () {
      final result = computeHints(['Foo', 'Bar'], ['Foo', 'Bar']);
      expect(result['Foo']!.start, 0);
      expect(result['Foo']!.length, 1);
      expect(result['Bar']!.start, 0);
      expect(result['Bar']!.length, 1);
    });

    test('unique hint survives original name collision', () {
      // "There Yet" has 'Y' unique in display, but "Yivi" (original of "Test")
      // also contains 'y', so 'Y' should not be the hint.
      final result = computeHints(['There Yet', 'Test'], ['There Yet', 'Yivi']);
      final hint = result['There Yet']!;
      final ch = 'There Yet'.substring(hint.start, hint.start + hint.length);
      // Should not be 'Y' — that matches "Yivi" via original name
      expect(ch, isNot('Y'));
      // Typing the hint should match only "There Yet" in search
      expect(ch, 'h'); // 'h' only in "There Yet"
    });

    test('null for duplicate display labels', () {
      final result = computeHints(['Chat', 'Chat'], ['Telegram', 'Signal']);
      expect(result['Chat'], isNull);
    });

    test('first-char collision falls back to later chars', () {
      // Telephone vs Telegram
      final result = computeHints(
        ['Telephone', 'Telegram'],
        ['Telephone', 'Telegram'],
      );
      final hint = result['Telephone']!;
      final ch = 'Telephone'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'p'); // 'p' is the first unique char by position
    });

    test('original name collision prevents hint across renamed apps', () {
      // Both renamed to the same display label — no unique substring
      final result = computeHints(['Same', 'Same'], ['Something', 'Else']);
      expect(result['Same'], isNull);
    });

    test('hint is from display label, not original', () {
      final result = computeHints(['Zebra', 'Alpha'], ['A', 'B']);
      final hint = result['Zebra']!;
      final ch = 'Zebra'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'Z');
    });
  });
}
