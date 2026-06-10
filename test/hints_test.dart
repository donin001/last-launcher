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

  group('computeHintsWithQuery', () {
    test('falls back to computeHints for empty query', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        '',
      );
      expect(result['Camera']!.start, 4);
      expect(result['Camera']!.length, 1);
      expect(result['Cameo']!.start, 4);
      expect(result['Cameo']!.length, 1);
    });

    test('prefix completion for query matching start', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'c',
      );
      expect(result['Camera']!.start, 0);
      expect(result['Camera']!.length, 5);
      expect(result['Cameo']!.start, 0);
      expect(result['Cameo']!.length, 5);
    });

    test('prefix completion for longer query', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'ca',
      );
      expect(result['Camera']!.start, 0);
      expect(result['Cameo']!.start, 0);
    });

    test('null for single app with query', () {
      final result = computeHintsWithQuery(['Only'], ['Only'], 'c');
      expect(result['Only'], isNull);
    });

    test('null for duplicate labels with query', () {
      final result = computeHintsWithQuery(
        ['Chat', 'Chat'],
        ['Notify', 'Remind'],
        'c',
      );
      expect(result['Chat'], isNull);
    });

    test('prefix hint does not collide with original name Yodel', () {
      final result = computeHintsWithQuery(
        ['The Yeti', 'Tap'],
        ['The Yeti', 'Yodel'],
        't',
      );
      // 'th' is unique: 'tap' doesn't start with 'th' and 'yodel' doesn't either.
      final hint = result['The Yeti']!;
      final ch = 'The Yeti'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'Th');
    });

    test('app matched by contains but not startsWith falls back', () {
      // "Camera" doesn't start with "am", but contains it.
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'am',
      );
      // Both contain "am", neither starts with it → hints must contain "am":
      // "amer" for Camera vs "ameo" for Cameo.
      expect(result['Camera']!.start, 1);
      expect(result['Camera']!.length, 4);
      final ch = 'Camera'.substring(
        result['Camera']!.start,
        result['Camera']!.start + result['Camera']!.length,
      );
      expect(ch, contains('am'));
      expect(result['Cameo']!.start, 1);
      expect(result['Cameo']!.length, 4);
      final ch2 = 'Cameo'.substring(
        result['Cameo']!.start,
        result['Cameo']!.start + result['Cameo']!.length,
      );
      expect(ch2, contains('am'));
    });

    test('one prefix candidate, one non-prefix candidate', () {
      // "Phone" starts with "ph", "Alphabet" contains "ph".
      final result = computeHintsWithQuery(
        ['Phone', 'Alphabet'],
        ['Phone', 'Alphabet'],
        'ph',
      );
      // "Phone" gets a prefix hint starting at 0.
      expect(result['Phone']!.start, 0);
      expect(result['Phone']!.length, greaterThan(2));
      // "Alphabet" doesn't start with "ph" — gets shortest hint containing "ph"
      // that's unique vs "Phone". Both "lph" (start=1, len=3) and "pha"
      // (start=4, len=3) are shortest; "lph" wins by earlier start scan order.
      expect(result['Alphabet']!.start, 1);
      expect(result['Alphabet']!.length, 3);
      final ch = 'Alphabet'.substring(
        result['Alphabet']!.start,
        result['Alphabet']!.start + result['Alphabet']!.length,
      );
      expect(ch, 'lph');
      expect(ch, contains('ph'));
    });

    test('Bramble vs Brave prefix hints', () {
      final result = computeHintsWithQuery(
        ['Bramble', 'Brave'],
        ['Bramble', 'Brave'],
        'br',
      );
      // "Bra" is shared, then "m" vs "v" diverges.
      expect(result['Bramble']!.start, 0);
      expect('Bramble'.substring(0, result['Bramble']!.length), 'Bram');
      expect(result['Brave']!.start, 0);
      expect('Brave'.substring(0, result['Brave']!.length), 'Brav');
    });
  });
}
