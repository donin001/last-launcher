import 'package:flutter_test/flutter_test.dart';
import 'package:last_launcher/shared/data/hints.dart';

void main() {
  group('computeHints', () {
    test('returns first alpha char for single app', () {
      final result = computeHints(['Only'], ['Only']);
      expect(result[0]!.start, 0);
      expect(result[0]!.length, 1);
    });

    test('returns empty list for empty list', () {
      final result = computeHints([], []);
      expect(result, isEmpty);
    });

    test('shortest unique character in simple case', () {
      final result = computeHints(['Foo', 'Bar'], ['Foo', 'Bar']);
      expect(result[0]!.start, 0);
      expect(result[0]!.length, 1);
      expect(result[1]!.start, 0);
      expect(result[1]!.length, 1);
    });

    test('unique hint survives original name collision', () {
      // "The Yeti" has 'Y' unique in display, but "Yodel" (original of "Tap")
      // also contains 'y', so 'Y' should not be the hint.
      final result = computeHints(['The Yeti', 'Tap'], ['The Yeti', 'Yodel']);
      final hint = result[0]!;
      final ch = 'The Yeti'.substring(hint.start, hint.start + hint.length);
      // Should not be 'Y' — that matches "Yodel" via original name
      expect(ch, isNot('Y'));
      // Typing the hint should match only "The Yeti" in search
      expect(ch, 'h'); // 'h' only in "The Yeti"
    });

    test('null for duplicate display labels', () {
      final result = computeHints(['Chat', 'Chat'], ['Notify', 'Remind']);
      expect(result[0], isNull);
    });

    test('first-char collision falls back to later chars', () {
      final result = computeHints(['Bramble', 'Brave'], ['Bramble', 'Brave']);
      final hint = result[0]!;
      final ch = 'Bramble'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'm'); // 'm' is the first unique char by position
    });

    test('original name collision prevents hint across renamed apps', () {
      final result = computeHints(['Same', 'Same'], ['Anything', 'Other']);
      expect(result[0], isNull);
    });

    test('hint is from display label, not original', () {
      final result = computeHints(['Zephyr', 'Ardent'], ['A', 'B']);
      final hint = result[0]!;
      final ch = 'Zephyr'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'Z');
    });

    test('hint skips non-alphabetical characters when no query', () {
      final result = computeHints(
        ['App (Beta)', 'App Alpha'],
        ['App (Beta)', 'App Alpha'],
      );
      final hint = result[0]!;
      final ch = 'App (Beta)'.substring(hint.start, hint.start + hint.length);
      expect(ch, contains(RegExp(r'^[a-zA-Z]+$')));
      expect(ch, 'B');
    });

    test('non-alpha fallback rejects clean-form collisions', () {
      // "second hand" and "secondhand clothes" share all alpha substrings
      // and their non-alpha hints ("d h") collapse to clean form "dh" which
      // also appears in the other app. No hint should be possible.
      final result = computeHints(
        ['second hand', 'secondhand clothes', 'Lemon'],
        ['second hand', 'secondhand clothes', 'Lemon'],
      );
      expect(result[0], isNull);
      expect(result[1], isNotNull);
      expect(result[2], isNotNull);
    });

    test('allows non-alphabetical characters in hints with query', () {
      // With a query, hints can include any character the user typed.
      // "Proton Drive" vs "Proton Mail" with query "pro": the shortest unique
      // prefix within the start-matching group is "Proton D" / "Proton M".
      final result = computeHintsWithQuery(
        ['Proton Drive', 'Proton Mail'],
        ['Proton Drive', 'Proton Mail'],
        'pro',
      );
      final hint0 = result[0]!;
      expect(
        'Proton Drive'.substring(hint0.start, hint0.start + hint0.length),
        'Proton D',
      );
      final hint1 = result[1]!;
      expect(
        'Proton Mail'.substring(hint1.start, hint1.start + hint1.length),
        'Proton M',
      );
    });
  });

  group('computeHintsWithQuery', () {
    test('falls back to computeHints for empty query', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        '',
      );
      expect(result[0]!.start, 4);
      expect(result[0]!.length, 1);
      expect(result[1]!.start, 4);
      expect(result[1]!.length, 1);
    });

    test('prefix completion for query matching start', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'c',
      );
      expect(result[0]!.start, 0);
      expect(result[0]!.length, 5);
      expect(result[1]!.start, 0);
      expect(result[1]!.length, 5);
    });

    test('prefix completion for longer query', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'ca',
      );
      expect(result[0]!.start, 0);
      expect(result[1]!.start, 0);
    });

    test('single result containing query gets hint at match position', () {
      // "youtube" contains "tube" at position 3 — hint should anchor there.
      final result = computeHintsWithQuery(['YouTube'], ['YouTube'], 'tube');
      expect(result[0]!.start, 3);
      expect(result[0]!.length, 4);
    });

    test('single result with no query overlap returns null hint', () {
      // "Only" has no overlap with 'c'; null is correct (unreachable in practice).
      final result = computeHintsWithQuery(['Only'], ['Only'], 'c');
      expect(result[0], isNull);
    });

    test('null for duplicate labels with query', () {
      final result = computeHintsWithQuery(
        ['Chat', 'Chat'],
        ['Notify', 'Remind'],
        'c',
      );
      expect(result[0], isNull);
    });

    test('prefix hint does not collide with original name Yodel', () {
      final result = computeHintsWithQuery(
        ['The Yeti', 'Tap'],
        ['The Yeti', 'Yodel'],
        't',
      );
      // 'th' is unique: 'tap' doesn't start with 'th'
      final hint = result[0]!;
      final ch = 'The Yeti'.substring(hint.start, hint.start + hint.length);
      expect(ch, 'Th');
    });

    test('non-starting matches get unique continuation hint', () {
      final result = computeHintsWithQuery(
        ['Camera', 'Cameo'],
        ['Camera', 'Cameo'],
        'am',
      );
      // Both contain "am" at position 1, but hints diverge for uniqueness.
      expect(result[0]!.start, 1);
      expect(result[0]!.length, 4);
      expect(result[1]!.start, 1);
      expect(result[1]!.length, 4);
      expect('Camera'.substring(1, 5), 'amer');
      expect('Cameo'.substring(1, 5), 'ameo');
    });

    test('one prefix candidate, one non-prefix candidate', () {
      // "Phone" starts with "ph", "Alphabet" contains "ph".
      final result = computeHintsWithQuery(
        ['Phone', 'Alphabet'],
        ['Phone', 'Alphabet'],
        'ph',
      );
      // "Phone" gets a prefix hint starting at 0.
      expect(result[0]!.start, 0);
      expect(result[0]!.length, 3); // 'Pho' is first unique in {Phone}
      // "Alphabet" contains "ph" at position 2 — hint starts there.
      expect(result[1]!.start, 2);
      expect(result[1]!.length, 3);
      expect(
        'Alphabet'.substring(
          result[1]!.start,
          result[1]!.start + result[1]!.length,
        ),
        'pha',
      );
    });

    test('Bramble vs Brave prefix hints', () {
      final result = computeHintsWithQuery(
        ['Bramble', 'Brave'],
        ['Bramble', 'Brave'],
        'br',
      );
      // "Bra" is shared, then "m" vs "v" diverges.
      expect(result[0]!.start, 0);
      expect('Bramble'.substring(0, result[0]!.length), 'Bram');
      expect(result[1]!.start, 0);
      expect('Brave'.substring(0, result[1]!.length), 'Brav');
    });

    test('non-start continuation with space in query', () {
      // Query 'd ' contains a space. Both apps contain 'd ' somewhere.
      final result = computeHintsWithQuery(
        ['second hand', 'secondhand clothes'],
        ['second hand', 'secondhand clothes'],
        'd ',
      );
      final hint0 = result[0]!;
      expect(
        'second hand'.substring(hint0.start, hint0.start + hint0.length),
        'd h',
      );
      final hint1 = result[1]!;
      expect(
        'secondhand clothes'.substring(hint1.start, hint1.start + hint1.length),
        'd c',
      );
    });

    test(
      'clean-form collision prevents non-start hint from looking like start-matching prefix',
      () {
        // 'identity wallet' starts with 'i'. 'bi-dr' contains 'i' at pos 1.
        // The non-start hint 'i-d' would clean to 'id', which is a prefix of
        // start-matching 'identity wallet' (cleaned 'identitywallet').
        // So 'bi-dr' should get 'i-dr', not 'i-d'.
        final result = computeHintsWithQuery(
          ['identity wallet', 'bi-dr'],
          ['identity wallet', 'bi-dr'],
          'i',
        );
        final hint0 = result[0]!;
        expect(
          'identity wallet'.substring(hint0.start, hint0.start + hint0.length),
          'ide',
        );
        final hint1 = result[1]!;
        expect(
          'bi-dr'.substring(hint1.start, hint1.start + hint1.length),
          'i-dr',
        );
      },
    );

    test('clean match hint uses position-mapped continuation', () {
      // Query "th" matches "Albert Heijn" only via clean logic (space
      // stripped). The hint should be anchored at the clean match position.
      final result = computeHintsWithQuery(
        ['Albert Heijn', 'Other'],
        ['Albert Heijn', 'Other'],
        'th',
      );
      // "Other" (standard non-start): "th" at position 1, 1-char continuation.
      expect(result[1]!.start, 1);
      expect(result[1]!.length, 3);
      expect('Other'.substring(1, 4), 'the');
      // "Albert Heijn" (clean-only): clean match at position 5 in cleaned form
      // maps back to folded position 5. Minimum span is 3 ("t H"), plus 1
      // continuation = 4 chars ("t He").
      expect(result[0]!.start, 5);
      expect(result[0]!.length, 4);
      expect('Albert Heijn'.substring(5, 9), 't He');
    });
  });
}
