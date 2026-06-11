import 'package:last_launcher/shared/data/fold_for_search.dart';

final _stripPunct = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final _stripPunctExceptSpace = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

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
  final cleanQuery = foldedQuery.replaceAll(_stripPunctExceptSpace, '');
  final foldedDisplay = displayLabels.map(foldForSearch).toList();
  final foldedOriginal = originalLabels.map(foldForSearch).toList();
  final index = SubstringIndex.build(foldedDisplay, foldedOriginal);
  final cleanedDisplayAll = foldedDisplay
      .map((s) => s.replaceAll(_stripPunct, ''))
      .toList();
  final cleanedOriginalAll = foldedOriginal
      .map((s) => s.replaceAll(_stripPunct, ''))
      .toList();

  // Which apps match the query via search semantics (standard + clean).
  // Standard: folded (spaces/punctuation preserved). Clean: non-letter/non-digit
  // stripped, matching searchApps' clean matchers.
  final allMatching = <int>{};
  final standardMatching = <int>{};
  final startMatching = <int>{};
  for (int i = 0; i < foldedDisplay.length; i++) {
    final stdMatch =
        foldedDisplay[i].contains(foldedQuery) ||
        foldedOriginal[i].contains(foldedQuery);
    if (stdMatch) {
      allMatching.add(i);
      standardMatching.add(i);
      if (foldedDisplay[i].startsWith(foldedQuery)) {
        startMatching.add(i);
      }
    } else if (cleanQuery.length >= 2) {
      final dc = foldedDisplay[i].replaceAll(_stripPunct, '');
      final oc = foldedOriginal[i].replaceAll(_stripPunct, '');
      if (dc.contains(cleanQuery) || oc.contains(cleanQuery)) {
        allMatching.add(i);
      }
    }
  }

  if (allMatching.length < 2) {
    return computeHints(displayLabels, originalLabels);
  }

  // Non-starting standard matches get hints that START at the query position.
  final nonStartStandard = standardMatching.difference(startMatching);
  final remaining = computeHints(
    displayLabels,
    originalLabels,
    index: index,
    hintFilter: (f) =>
        f.startsWith(foldedQuery) && f.length > foldedQuery.length,
    scope: nonStartStandard,
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

  // Clean-only matches: find the hint by mapping the clean match position
  // back to the original label, then find the shortest unique substring
  // anchored there.
  final cleanOnly = allMatching.difference(standardMatching);
  for (final i in cleanOnly) {
    final hint = _cleanMatchHint(
      displayLabels[i],
      cleanQuery,
      index,
      i,
      allMatching,
      cleanedDisplayAll,
      cleanedOriginalAll,
    );
    remaining[displayLabels[i]] = hint;
  }

  // Verify clean-form uniqueness for all hints. A hint's folded form may be
  // unique in the SubstringIndex, but its clean form could match another app
  // via clean logic (e.g. folded "a st" is unique but clean "ast" matches
  // Pocket Casts). Extend hints whose clean forms conflict.
  final labelToIndex = {
    for (int i = 0; i < displayLabels.length; i++) displayLabels[i]: i,
  };
  for (final label in remaining.keys.toList()) {
    final hint = remaining[label];
    if (hint == null) continue;

    final appIndex = labelToIndex[label]!;
    final origPool = startMatching.contains(appIndex)
        ? startMatching
        : allMatching;

    bool found = false;
    for (
      int len = hint.length;
      hint.start + len <= label.length && !found;
      len++
    ) {
      if (len > hint.length) {
        final foldedSub = foldForSearch(
          label.substring(hint.start, hint.start + len),
        );
        if (!index.isUniqueTo(foldedSub, appIndex, origPool)) continue;
      }

      final sub = label.substring(hint.start, hint.start + len);
      final foldedSub = foldForSearch(sub);
      final cleanSub = foldedSub.replaceAll(_stripPunct, '');
      bool conflicts = false;
      for (final other in allMatching) {
        if (other == appIndex) continue;
        if (cleanedDisplayAll[other].contains(cleanSub) ||
            cleanedOriginalAll[other].contains(cleanSub)) {
          conflicts = true;
          break;
        }
      }

      if (!conflicts) {
        if (len != hint.length) {
          remaining[label] = SubstringHint(start: hint.start, length: len);
        }
        found = true;
      }
    }
    if (!found) {
      remaining[label] = null;
    }
  }

  return remaining;
}

/// For an app that matched via clean-only logic (the folded display doesn't
/// contain the folded query but the cleaned display contains the cleaned
/// query), find the shortest unique substring of the original label that is
/// anchored at the match position.
///
/// Verifies uniqueness against both folded (SubstringIndex) and clean forms
/// (other apps' cleaned names) — a hint like "a st" may be unique in the
/// folded index (no other app has "a "), but its clean form "ast" could
/// match another app via clean matching.
SubstringHint? _cleanMatchHint(
  String label,
  String cleanQuery,
  SubstringIndex index,
  int appIndex,
  Set<int> pool,
  List<String> cleanedDisplay,
  List<String> cleanedOriginal,
) {
  final folded = foldForSearch(label);
  // Positions in folded that are kept after stripping non-letter/non-digit.
  final kept = <int>[];
  for (int i = 0; i < folded.length; i++) {
    if (!_stripPunct.hasMatch(folded[i])) {
      kept.add(i);
    }
  }
  final cleaned = String.fromCharCodes(kept.map(folded.codeUnitAt));
  final cleanPos = cleaned.indexOf(cleanQuery);
  if (cleanPos == -1) return null;

  final origStart = kept[cleanPos];
  final minLen = kept[cleanPos + cleanQuery.length - 1] - origStart + 1;

  // Require at least one char beyond the match span (like non-start
  // standard hints use f.length > foldedQuery.length).
  for (int len = minLen + 1; origStart + len <= label.length; len++) {
    final sub = label.substring(origStart, origStart + len);
    final foldedSub = foldForSearch(sub);
    if (!index.isUniqueTo(foldedSub, appIndex, pool)) continue;

    // Also check clean-form uniqueness: the clean form of the hint substring
    // might match another app via clean logic even though the folded form is
    // unique (e.g. folded "a st" is unique to Aurora Store but clean "ast"
    // also matches Pocket Casts). Extend the hint until its clean form is
    // also unique.
    final cleanHint = foldedSub.replaceAll(_stripPunct, '');
    if (cleanHint.isEmpty) continue;
    bool conflicts = false;
    for (final other in pool) {
      if (other == appIndex) continue;
      if (cleanedDisplay[other].contains(cleanHint) ||
          cleanedOriginal[other].contains(cleanHint)) {
        conflicts = true;
        break;
      }
    }
    if (conflicts) continue;

    return SubstringHint(start: origStart, length: len);
  }
  return null;
}
