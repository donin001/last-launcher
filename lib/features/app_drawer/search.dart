import 'package:last_launcher/shared/data/fold_for_search.dart';
import 'package:last_launcher/shared/data/models.dart';

final _stripPunct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

// --- Query parsing ---

class SearchQuery {
  final String raw;
  final String searchTerm;
  final bool? requireWorkApp;

  String get needle => foldForSearch(searchTerm);
  String get needleClean => needle.replaceAll(_stripPunct, '');

  SearchQuery._(this.raw, this.searchTerm, this.requireWorkApp);

  factory SearchQuery.parse(String query) {
    if (query.startsWith('.')) {
      return SearchQuery._(query, query.substring(1), true);
    } else if (query.startsWith(' ')) {
      return SearchQuery._(query, query.substring(1), false);
    }
    return SearchQuery._(query, query, null);
  }
}

// --- Match tiers (also serve as rank priority) ---

enum MatchTier { displayStart, originalStart, displayContain, originalContain }

// --- Per-app precomputed context (avoids redundant folding/cleaning) ---

class AppSearchContext {
  final String display;
  final String original;
  final bool checkOriginal;
  final String displayClean;
  final String originalClean;

  AppSearchContext._(
    this.display,
    this.original,
    this.checkOriginal,
    this.displayClean,
    this.originalClean,
  );

  factory AppSearchContext(
    AppInfo app,
    bool matchOriginal,
    String Function(AppInfo) labelOf,
  ) {
    final d = foldForSearch(labelOf(app));
    final o = foldForSearch(app.label);
    return AppSearchContext._(
      d,
      o,
      matchOriginal && d != o,
      d.replaceAll(_stripPunct, ''),
      o.replaceAll(_stripPunct, ''),
    );
  }
}

// --- Matcher interface ---

abstract class SearchMatcher {
  const SearchMatcher();
  MatchTier get tier;
  bool matches(AppSearchContext ctx, SearchQuery query);
}

// --- Concrete matchers ---

class DisplayStartsWith extends SearchMatcher {
  const DisplayStartsWith();
  @override
  MatchTier get tier => MatchTier.displayStart;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      ctx.display.startsWith(query.needle);
}

class OriginalStartsWith extends SearchMatcher {
  const OriginalStartsWith();
  @override
  MatchTier get tier => MatchTier.originalStart;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      ctx.checkOriginal && ctx.original.startsWith(query.needle);
}

class DisplayCleanStartsWith extends SearchMatcher {
  const DisplayCleanStartsWith();
  @override
  MatchTier get tier => MatchTier.displayStart;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      query.needleClean.length >= 2 &&
      ctx.displayClean.startsWith(query.needleClean);
}

class OriginalCleanStartsWith extends SearchMatcher {
  const OriginalCleanStartsWith();
  @override
  MatchTier get tier => MatchTier.originalStart;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      query.needleClean.length >= 2 &&
      ctx.checkOriginal &&
      ctx.originalClean.startsWith(query.needleClean);
}

class DisplayContains extends SearchMatcher {
  const DisplayContains();
  @override
  MatchTier get tier => MatchTier.displayContain;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      ctx.display.contains(query.needle);
}

class OriginalContains extends SearchMatcher {
  const OriginalContains();
  @override
  MatchTier get tier => MatchTier.originalContain;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      ctx.checkOriginal && ctx.original.contains(query.needle);
}

class DisplayCleanContains extends SearchMatcher {
  const DisplayCleanContains();
  @override
  MatchTier get tier => MatchTier.displayContain;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      query.needleClean.length >= 2 &&
      ctx.displayClean.contains(query.needleClean);
}

class OriginalCleanContains extends SearchMatcher {
  const OriginalCleanContains();
  @override
  MatchTier get tier => MatchTier.originalContain;
  @override
  bool matches(AppSearchContext ctx, SearchQuery query) =>
      query.needleClean.length >= 2 &&
      ctx.checkOriginal &&
      ctx.originalClean.contains(query.needleClean);
}

// --- Priority-ordered matcher pipeline ---

const _matchers = <SearchMatcher>[
  DisplayStartsWith(),
  OriginalStartsWith(),
  DisplayCleanStartsWith(),
  OriginalCleanStartsWith(),
  DisplayContains(),
  OriginalContains(),
  DisplayCleanContains(),
  OriginalCleanContains(),
];

// --- Public entry point ---

List<AppInfo> searchApps(
  Iterable<AppInfo> source,
  String query, {
  bool matchOriginal = true,
  String Function(AppInfo) displayLabel = _defaultDisplayLabel,
}) {
  if (query.isEmpty) return source.toList();

  final parsed = SearchQuery.parse(query);

  final filtered = parsed.requireWorkApp == null
      ? source
      : source.where((a) => a.isWorkApp == parsed.requireWorkApp);

  final buckets = <MatchTier, List<AppInfo>>{
    for (final tier in MatchTier.values) tier: <AppInfo>[],
  };

  for (final app in filtered) {
    final ctx = AppSearchContext(app, matchOriginal, displayLabel);
    for (final matcher in _matchers) {
      if (matcher.matches(ctx, parsed)) {
        buckets[matcher.tier]!.add(app);
        break;
      }
    }
  }

  return [
    ...buckets[MatchTier.displayStart]!,
    ...buckets[MatchTier.originalStart]!,
    ...buckets[MatchTier.displayContain]!,
    ...buckets[MatchTier.originalContain]!,
  ];
}

String _defaultDisplayLabel(AppInfo app) => app.label;
