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
      // "The Yeti" has 'Y' unique in display, but "Yodel" (original of "Tap")
      // also contains 'y', so 'Y' should not be the hint.
      final result = computeHints(['The Yeti', 'Tap'], ['The Yeti', 'Yodel']);
      final hint = result['The Yeti']!;
      final ch = 'The Yeti'.substring(hint.start, hint.start + hint.length);
      // Should not be 'Y' — that matches "Yodel" via original name
      expect(ch, isNot('Y'));
      // Typing the hint should match only "The Yeti" in search
      expect(ch, 'h'); // 'h' only in "The Yeti"
    });

    test('null for duplicate display labels', () {
      final result = computeHints(['Chat', 'Chat'], ['Notify', 'Remind']);
      expect(result['Chat'], isNull);
    });

    test('first-char collision falls back to later chars', () {
      // Bramble vs Brave
      final result = computeHints(['Bramble', 'Brave'], ['Bramble', 'Brave']);
      final hint = result['Bramble']!;
      final ch = 'Bramble'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'm'); // 'm' is the first unique char by position
    });

    test('original name collision prevents hint across renamed apps', () {
      // Both renamed to the same display label — no unique substring
      final result = computeHints(['Same', 'Same'], ['Anything', 'Other']);
      expect(result['Same'], isNull);
    });

    test('hint is from display label, not original', () {
      final result = computeHints(['Zephyr', 'Ardent'], ['A', 'B']);
      final hint = result['Zephyr']!;
      final ch = 'Zephyr'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'Z');
    });

    test('hint is alphabetical only', () {
      final result = computeHints(
        ['Hike Planner', 'Mailbox'],
        ['Hike Planner', 'Mailbox'],
      );
      final hint = result['Hike Planner']!;
      final ch = 'Hike Planner'.substring(hint.start, hint.start + hint.length);
      expect(ch, contains(RegExp(r'^[a-zA-Z]+$')));
    });

    test('hint skips non-alphabetical characters', () {
      // "App (Beta)" has unique 'B' at position 5, but position 3 is space
      // and position 4 is '(' — both must be skipped.
      final result = computeHints(
        ['App (Beta)', 'App Alpha'],
        ['App (Beta)', 'App Alpha'],
      );
      final hint = result['App (Beta)']!;
      final ch = 'App (Beta)'.substring(hint.start, hint.start + hint.length);
      expect(ch, contains(RegExp(r'^[a-zA-Z]+$')));
      expect(ch, 'B');
    });
  });
}
