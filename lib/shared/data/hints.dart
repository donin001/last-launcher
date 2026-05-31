class SubstringHint {
  const SubstringHint({required this.start, required this.length});

  final int start;
  final int length;
}

/// Returns the shortest unique substring of each display label that would
/// produce exactly one search match (considering both display and original
/// names, diacritic-insensitive). Returns null for labels with no such
/// substring (e.g. duplicates or names that share all substrings with others).
Map<String, SubstringHint?> computeHints(
  List<String> displayLabels,
  List<String> originalLabels,
) {
  if (displayLabels.length < 2) {
    return {for (final l in displayLabels) l: null};
  }

  final foldedDisplay = displayLabels.map(_fold).toList();
  final foldedOriginal = originalLabels.map(_fold).toList();

  // Build folded substring -> set of app indices that contain it in either
  // display or original name. This mirrors search matching: an app matches
  // a query if foldedDisplay.contains(query) || foldedOriginal.contains(query).
  final subToIndices = <String, Set<int>>{};
  for (int i = 0; i < foldedDisplay.length; i++) {
    for (final f in {foldedDisplay[i], foldedOriginal[i]}) {
      final seen = <String>{};
      for (int end = 1; end <= f.length; end++) {
        for (int start = 0; start < end; start++) {
          final sub = f.substring(start, end);
          if (seen.add(sub)) {
            subToIndices.putIfAbsent(sub, () => {});
            subToIndices[sub]!.add(i);
          }
        }
      }
    }
  }

  // Phase 2: for each display label, find the shortest substring that matches
  // exactly one app via search semantics.
  final result = <String, SubstringHint?>{};
  for (int i = 0; i < displayLabels.length; i++) {
    final label = displayLabels[i];
    SubstringHint? best;
    for (int len = 1; len <= label.length && best == null; len++) {
      for (int start = 0; start + len <= label.length; start++) {
        final sub = label.substring(start, start + len);
        final foldedSub = _fold(sub);
        final indices = subToIndices[foldedSub];
        if (indices != null && indices.length == 1 && indices.contains(i)) {
          best = SubstringHint(start: start, length: len);
          break;
        }
      }
    }
    result[label] = best;
  }

  return result;
}

/// Diacritic-fold (e.g. é → e, ß → ss). Covers the same range as
/// AppListState._foldForSearch (kept in sync).
String _fold(String s) {
  final lower = s.toLowerCase();
  if (lower.codeUnits.every((c) => c < 0x00C0)) return lower;
  final buf = StringBuffer();
  for (final r in lower.runes) {
    buf.write(_diacriticFold[r] ?? String.fromCharCode(r));
  }
  return buf.toString();
}

const _diacriticFold = <int, String>{
  0x00E0: 'a',
  0x00E1: 'a',
  0x00E2: 'a',
  0x00E3: 'a',
  0x00E4: 'a',
  0x00E5: 'a',
  0x0101: 'a',
  0x0103: 'a',
  0x0105: 'a',
  0x00E6: 'ae',
  0x00E7: 'c',
  0x0107: 'c',
  0x010D: 'c',
  0x010F: 'd',
  0x0111: 'd',
  0x00E8: 'e',
  0x00E9: 'e',
  0x00EA: 'e',
  0x00EB: 'e',
  0x0113: 'e',
  0x0117: 'e',
  0x0119: 'e',
  0x011B: 'e',
  0x011F: 'g',
  0x0123: 'g',
  0x00EC: 'i',
  0x00ED: 'i',
  0x00EE: 'i',
  0x00EF: 'i',
  0x012B: 'i',
  0x012F: 'i',
  0x0131: 'i',
  0x013A: 'l',
  0x013E: 'l',
  0x0142: 'l',
  0x00F1: 'n',
  0x0144: 'n',
  0x0148: 'n',
  0x00F0: 'd',
  0x00F2: 'o',
  0x00F3: 'o',
  0x00F4: 'o',
  0x00F5: 'o',
  0x00F6: 'o',
  0x00F8: 'o',
  0x014D: 'o',
  0x0151: 'o',
  0x0153: 'oe',
  0x0155: 'r',
  0x0159: 'r',
  0x015B: 's',
  0x015F: 's',
  0x0161: 's',
  0x0163: 't',
  0x0165: 't',
  0x00F9: 'u',
  0x00FA: 'u',
  0x00FB: 'u',
  0x00FC: 'u',
  0x016B: 'u',
  0x016F: 'u',
  0x0171: 'u',
  0x0173: 'u',
  0x00FD: 'y',
  0x00FF: 'y',
  0x017A: 'z',
  0x017C: 'z',
  0x017E: 'z',
  0x00DF: 'ss',
  0x00FE: 'th',
};
