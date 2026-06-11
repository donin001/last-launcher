import 'package:last_launcher/shared/data/fold_for_search.dart';

class SubstringHint {
  const SubstringHint({required this.start, required this.length});

  final int start;
  final int length;
}

/// Reverse index: every folded substring of name → set of app indices that
/// contain it. Built once, queried for uniqueness checks.
class SubstringIndex {
  final Map<String, Set<int>> _foldedToIndices;

  SubstringIndex._(this._foldedToIndices);

  factory SubstringIndex.build(
    List<String> foldedDisplay,
    List<String> foldedOriginal,
  ) {
    final subToIndices = <String, Set<int>>{};
    for (int i = 0; i < foldedDisplay.length; i++) {
      for (final f in {foldedDisplay[i], foldedOriginal[i]}) {
        final seen = <String>{};
        for (int end = 1; end <= f.length; end++) {
          for (int start = 0; start < end; start++) {
            final sub = f.substring(start, end);
            if (seen.add(sub)) {
              subToIndices.putIfAbsent(sub, () => <int>{});
              subToIndices[sub]!.add(i);
            }
          }
        }
      }
    }
    return SubstringIndex._(subToIndices);
  }

  /// Whether [foldedSub] matches exactly one index within [pool], and that
  /// index is [index].
  bool isUniqueTo(String foldedSub, int index, Set<int> pool) {
    final all = _foldedToIndices[foldedSub];
    if (all == null) return false;
    final inPool = all.intersection(pool);
    return inPool.length == 1 && inPool.contains(index);
  }
}

/// Returns the shortest unique substring of each display label that would
/// produce exactly one search match (considering both display and original
/// names, diacritic-insensitive). Returns null for labels with no such
/// substring (e.g. duplicates or names that share all substrings with others).
///
/// Optional parameters let callers constrain which substrings are valid
/// ([hintFilter]), which apps get hints ([scope]), and which apps the hint
/// must be unique against ([uniquenessPool]). When an [index] is provided,
/// it is reused instead of building a new one (avoids redundant work).
Map<String, SubstringHint?> computeHints(
  List<String> displayLabels,
  List<String> originalLabels, {
  SubstringIndex? index,
  bool Function(String foldedSubstring)? hintFilter,
  Set<int>? scope,
  Set<int>? uniquenessPool,
  bool allowNonAlpha = false,
}) {
  final allIndices = {for (int i = 0; i < displayLabels.length; i++) i};
  final targets = scope ?? allIndices;
  final pool = uniquenessPool ?? allIndices;

  if (displayLabels.length < 2) {
    SubstringHint? singleHint(String label) {
      final folded = foldForSearch(label);
      for (int i = 0; i < folded.length; i++) {
        if (RegExp(r'[a-z]').hasMatch(folded[i])) {
          return SubstringHint(start: i, length: 1);
        }
      }
      return null;
    }

    return {
      for (final i in targets) displayLabels[i]: singleHint(displayLabels[i]),
    };
  }

  final idx =
      index ??
      SubstringIndex.build(
        displayLabels.map(foldForSearch).toList(),
        originalLabels.map(foldForSearch).toList(),
      );

  final result = <String, SubstringHint?>{};
  for (final i in targets) {
    final label = displayLabels[i];
    SubstringHint? best;
    for (int len = 1; len <= label.length && best == null; len++) {
      for (int start = 0; start + len <= label.length; start++) {
        final sub = label.substring(start, start + len);
        final foldedSub = foldForSearch(sub);
        if (hintFilter != null && !hintFilter(foldedSub)) continue;
        if (!allowNonAlpha && RegExp(r'[^a-z]').hasMatch(foldedSub)) continue;
        if (idx.isUniqueTo(foldedSub, i, pool)) {
          best = SubstringHint(start: start, length: len);
          break;
        }
      }
    }
    result[label] = best;
  }
  return result;
}

/// Like [computeHints] but shows prefix completions when the query matches
/// the start of the app name. When the query is empty or no app display starts
/// with the query, falls back to [computeHints].
///
/// Example: "camera" and "cameo" with query "c" gives "camer" (camera) and
/// "cameo" (cameo) instead of "er" / "eo".
Map<String, SubstringHint?> computeHintsWithQuery(
  List<String> displayLabels,
  List<String> originalLabels,
  String query,
) {
  if (displayLabels.length < 2 || query.isEmpty) {
    return computeHints(displayLabels, originalLabels);
  }

  final foldedQuery = foldForSearch(query);
  final foldedDisplay = displayLabels.map(foldForSearch).toList();
  final foldedOriginal = originalLabels.map(foldForSearch).toList();
  final index = SubstringIndex.build(foldedDisplay, foldedOriginal);

  // Which apps match the query via search semantics.
  final allMatching = <int>{};
  final startMatching = <int>{};
  for (int i = 0; i < foldedDisplay.length; i++) {
    if (foldedDisplay[i].contains(foldedQuery) ||
        foldedOriginal[i].contains(foldedQuery)) {
      allMatching.add(i);
      if (foldedDisplay[i].startsWith(foldedQuery)) {
        startMatching.add(i);
      }
    }
  }

  if (allMatching.length < 2) {
    return computeHints(displayLabels, originalLabels);
  }

  // Non-starting matches get hints that START at the query position, so
  // "Blog" with query "g" shows "g" at position 3 (not "og" starting
  // before it).
  final nonStart = allMatching.difference(startMatching);
  final remaining = computeHints(
    displayLabels,
    originalLabels,
    index: index,
    hintFilter: (f) => f.startsWith(foldedQuery),
    scope: nonStart,
    uniquenessPool: allMatching,
    allowNonAlpha: true,
  );

  // Apps that start with the query get contextual prefix hints.
  final prefixHints = computeHints(
    displayLabels,
    originalLabels,
    index: index,
    hintFilter: (f) =>
        f.startsWith(foldedQuery) && f.length > foldedQuery.length,
    scope: startMatching,
    uniquenessPool: startMatching,
    allowNonAlpha: true,
  );
  remaining.addAll(prefixHints);
  return remaining;
}
