import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:last_launcher/features/app_drawer/search.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
import 'package:last_launcher/shared/data/fold_for_search.dart';
import 'package:last_launcher/shared/data/hints.dart';
import 'package:last_launcher/shared/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppListState extends ChangeNotifier {
  AppListState(this._channel, this._prefs) {
    _loadCustomLabels();
    _loadHiddenApps();
    _matchOriginal = _prefs.getBool(_matchOriginalKey) ?? true;
    _includeHiddenInSearch = _prefs.getBool(_includeHiddenInSearchKey) ?? false;
    _hidePersonalWhenWorkActive =
        _prefs.getBool(_hidePersonalWhenWorkActiveKey) ?? false;
  }

  static const _labelsKey = 'custom_labels';
  static const _hiddenKey = 'hidden_apps';
  static const _matchOriginalKey = 'match_original_name';
  static const _includeHiddenInSearchKey = 'include_hidden_in_search';
  static const _hidePersonalWhenWorkActiveKey =
      'hide_personal_when_work_active';

  final AppChannel _channel;
  final SharedPreferences _prefs;
  List<AppInfo> _allApps = [];
  String _query = '';
  bool _loading = false;
  bool _matchOriginal = true;
  bool _includeHiddenInSearch = false;
  bool _hidePersonalWhenWorkActive = false;
  bool _hasWorkProfile = false;
  final Map<String, String> _customLabels = {};
  final Set<String> _hiddenApps = {};
  Map<String, SubstringHint?> _hints = {};

  List<AppInfo> get allApps => List.unmodifiable(_allApps);
  Set<String> get workPackages => {
    for (final a in _allApps)
      if (a.isWorkApp) a.packageName,
  };
  bool get hasWorkApps => _allApps.any((a) => a.isWorkApp);
  bool get hasWorkProfile => _hasWorkProfile;
  bool get profilePrefixEnabled =>
      _hasWorkProfile && !_hidePersonalWhenWorkActive;
  String get query => _query;

  List<AppInfo> get hiddenApps => _allApps
      .where(
        (a) => _hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)),
      )
      .toList();

  Map<String, SubstringHint?> get hints => _hints;

  bool isHidden(String packageName, {bool isWorkApp = false}) =>
      _hiddenApps.contains(_compoundKey(packageName, isWorkApp));

  void setIncludeHiddenInSearch(bool enabled) {
    if (_includeHiddenInSearch == enabled) return;
    _includeHiddenInSearch = enabled;
    _computeHints();
    notifyListeners();
  }

  void setHidePersonalWhenWorkActive(bool enabled) {
    if (_hidePersonalWhenWorkActive == enabled) return;
    _hidePersonalWhenWorkActive = enabled;
    _computeHints();
    notifyListeners();
  }

  List<AppInfo> search(
    String query, {
    bool includeHidden = false,
    bool matchOriginal = true,
  }) {
    var source = includeHidden
        ? _allApps
        : _allApps.where(
            (a) =>
                !_hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)),
          );
    if (_hidePersonalWhenWorkActive && hasWorkApps) {
      source = source.where((a) => a.isWorkApp);
    }
    return searchApps(
      source,
      query,
      matchOriginal: matchOriginal,
      displayLabel: displayLabel,
      allowProfileFilter: profilePrefixEnabled,
    );
  }

  Future<void> loadApps() async {
    if (_loading) return;
    _loading = true;
    try {
      _allApps = await _channel.getInstalledApps();
      _hasWorkProfile = await _channel.hasWorkProfile();
      _sortApps();
      _pruneOrphanedState();
      _computeHints();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load installed apps: $e');
    } finally {
      _loading = false;
    }
  }

  static String _compoundKey(String packageName, bool isWorkApp) =>
      '$packageName|$isWorkApp';

  /// Drop entries from [_customLabels] and [_hiddenApps] for packages that are
  /// no longer installed. Saves and notifies if anything changed. Skipped when
  /// [_allApps] is empty (e.g. failed channel call), so a transient failure
  /// can't wipe valid state.
  ///
  /// Work-app entries (compound keys ending in `|true`) are never pruned
  /// because the work profile can be paused temporarily, making those apps
  /// disappear from the installed list. Pruning them would lose user state
  /// (hidden status, custom labels) across a pause/unpause cycle.
  void _pruneOrphanedState() {
    if (_allApps.isEmpty) return;
    final installedCompound = {
      for (final a in _allApps) _compoundKey(a.packageName, a.isWorkApp),
    };
    var changed = false;
    final workPackages = {
      for (final key in _hiddenApps)
        if (key.endsWith('|true')) key.split('|').first,
    };
    final droppedLabels = _customLabels.keys
        .where(
          (k) =>
              !installedCompound.contains(k) &&
              !k.endsWith('|true') &&
              !workPackages.contains(k.split('|').first),
        )
        .toList();
    if (droppedLabels.isNotEmpty) {
      for (final k in droppedLabels) {
        _customLabels.remove(k);
      }
      changed = true;
    }
    final droppedHidden = _hiddenApps
        .where((p) => !installedCompound.contains(p))
        .where((p) => !p.endsWith('|true'))
        .toList();
    if (droppedHidden.isNotEmpty) {
      _hiddenApps.removeAll(droppedHidden);
      changed = true;
    }
    if (changed) {
      _saveCustomLabels();
      _saveHiddenApps();
    }
  }

  /// Set of package names currently installed.
  Set<String> get installedPackages => {
    for (final a in _allApps) a.packageName,
  };

  void filter(String query) {
    _query = query;
    _computeHints(query: query);
    notifyListeners();
  }

  void clearFilter() {
    _query = '';
    _computeHints();
    notifyListeners();
  }

  void setCustomLabel(
    String packageName,
    String label, {
    bool isWorkApp = false,
  }) {
    final key = _compoundKey(packageName, isWorkApp);
    if (label.isEmpty) {
      _customLabels.remove(key);
    } else {
      _customLabels[key] = label;
    }
    _sortApps();
    _computeHints();
    notifyListeners();
    _saveCustomLabels();
  }

  void hideApp(String packageName, {bool isWorkApp = false}) {
    _hiddenApps.add(_compoundKey(packageName, isWorkApp));
    _computeHints();
    notifyListeners();
    _saveHiddenApps();
  }

  void unhideApp(String packageName, {bool isWorkApp = false}) {
    _hiddenApps.remove(_compoundKey(packageName, isWorkApp));
    _computeHints();
    notifyListeners();
    _saveHiddenApps();
  }

  String displayLabelFor(
    String packageName,
    String fallback, {
    bool isWorkApp = false,
  }) {
    return _customLabels[_compoundKey(packageName, isWorkApp)] ?? fallback;
  }

  String displayLabel(AppInfo app) {
    return displayLabelFor(
      app.packageName,
      app.label,
      isWorkApp: app.isWorkApp,
    );
  }

  void _computeHints({String query = ''}) {
    final visible = _includeHiddenInSearch
        ? _allApps
        : _allApps.where(
            (a) =>
                !_hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)),
          );
    if (query.isNotEmpty) {
      final searchTerm = SearchQuery.parse(
        query,
        allowProfileFilter: profilePrefixEnabled,
      ).searchTerm;
      final displayLabels = visible.map(displayLabel).toList();
      final originals = _matchOriginal
          ? visible.map((a) => a.label).toList()
          : displayLabels;
      _hints = computeHintsWithQuery(displayLabels, originals, searchTerm);
    } else {
      final displayLabels = visible.map(displayLabel).toList();
      final originals = _matchOriginal
          ? visible.map((a) => a.label).toList()
          : displayLabels;
      _hints = computeHints(displayLabels, originals);
    }
  }

  void setMatchOriginalName(bool enabled) {
    if (_matchOriginal == enabled) return;
    _matchOriginal = enabled;
    _computeHints();
    notifyListeners();
  }

  void _sortApps() {
    _allApps.sort((a, b) {
      final cmp = foldForSearch(
        displayLabel(a),
      ).compareTo(foldForSearch(displayLabel(b)));
      if (cmp != 0) return cmp;
      // Same label: personal before work
      if (a.isWorkApp != b.isWorkApp) return a.isWorkApp ? 1 : -1;
      return 0;
    });
  }

  void _loadCustomLabels() {
    final json = _prefs.getString(_labelsKey);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final key = entry.key;
        // Legacy: plain packageName → compound key with false
        final compoundKey = key.contains('|') ? key : '$key|false';
        _customLabels[compoundKey] = entry.value as String;
      }
    } on FormatException {
      debugPrint('Corrupt custom labels JSON, resetting');
      _prefs.remove(_labelsKey);
    }
  }

  Future<void> _saveCustomLabels() async {
    await _prefs.setString(_labelsKey, jsonEncode(_customLabels));
  }

  void _loadHiddenApps() {
    final json = _prefs.getString(_hiddenKey);
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List<dynamic>;
      for (final item in list) {
        if (item is! String) continue;
        // Legacy format: packageName only, assume personal profile
        if (!item.contains('|')) {
          _hiddenApps.add('$item|false');
        } else {
          _hiddenApps.add(item);
        }
      }
    } on FormatException {
      debugPrint('Corrupt hidden apps JSON, resetting');
      _prefs.remove(_hiddenKey);
    }
  }

  Future<void> _saveHiddenApps() async {
    await _prefs.setString(_hiddenKey, jsonEncode(_hiddenApps.toList()));
  }
}
