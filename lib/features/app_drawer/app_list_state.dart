import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
import 'package:last_launcher/shared/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppListState extends ChangeNotifier {
  AppListState(this._channel, this._prefs) {
    _loadCustomLabels();
    _loadHiddenApps();
  }

  static const _labelsKey = 'custom_labels';
  static const _hiddenKey = 'hidden_apps';

  final AppChannel _channel;
  final SharedPreferences _prefs;
  List<AppInfo> _allApps = [];
  String _query = '';
  bool _loading = false;
  final Map<String, String> _customLabels = {};
  final Set<String> _hiddenApps = {};

  List<AppInfo> get allApps => List.unmodifiable(_allApps);
  String get query => _query;

  List<AppInfo> get hiddenApps =>
      _allApps.where((a) => _hiddenApps.contains(a.packageName)).toList();

  bool isHidden(String packageName) => _hiddenApps.contains(packageName);

  List<AppInfo> search(
    String query, {
    bool includeHidden = false,
    bool matchOriginal = true,
  }) {
    final source = includeHidden
        ? _allApps
        : _allApps.where((a) => !_hiddenApps.contains(a.packageName));
    if (query.isEmpty) return source.toList();
    final needle = _foldForSearch(query);

    final displayStart = <AppInfo>[];
    final originalStart = <AppInfo>[];
    final displayContain = <AppInfo>[];
    final originalContain = <AppInfo>[];

    for (final app in source) {
      final display = _foldForSearch(displayLabel(app));
      final original = _foldForSearch(app.label);
      final renamed = display != original;
      final checkOriginal = matchOriginal && renamed;

      if (display.startsWith(needle)) {
        displayStart.add(app);
      } else if (checkOriginal && original.startsWith(needle)) {
        originalStart.add(app);
      } else if (display.contains(needle)) {
        displayContain.add(app);
      } else if (checkOriginal && original.contains(needle)) {
        originalContain.add(app);
      }
    }

    return [
      ...displayStart,
      ...originalStart,
      ...displayContain,
      ...originalContain,
    ];
  }

  Future<void> loadApps() async {
    if (_loading) return;
    _loading = true;
    try {
      _allApps = await _channel.getInstalledApps();
      _sortApps();
      _pruneOrphanedState();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load installed apps: $e');
    } finally {
      _loading = false;
    }
  }

  /// Drop entries from [_customLabels] and [_hiddenApps] for packages that are
  /// no longer installed. Saves and notifies if anything changed. Skipped when
  /// [_allApps] is empty (e.g. failed channel call), so a transient failure
  /// can't wipe valid state.
  void _pruneOrphanedState() {
    if (_allApps.isEmpty) return;
    final installed = {for (final a in _allApps) a.packageName};
    var changed = false;
    final droppedLabels =
        _customLabels.keys.where((k) => !installed.contains(k)).toList();
    if (droppedLabels.isNotEmpty) {
      for (final k in droppedLabels) {
        _customLabels.remove(k);
      }
      changed = true;
    }
    final droppedHidden =
        _hiddenApps.where((p) => !installed.contains(p)).toList();
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
  Set<String> get installedPackages =>
      {for (final a in _allApps) a.packageName};

  void filter(String query) {
    _query = query;
    notifyListeners();
  }

  void clearFilter() {
    _query = '';
    notifyListeners();
  }

  void setCustomLabel(String packageName, String label) {
    if (label.isEmpty) {
      _customLabels.remove(packageName);
    } else {
      _customLabels[packageName] = label;
    }
    _sortApps();
    notifyListeners();
    _saveCustomLabels();
  }

  void hideApp(String packageName) {
    _hiddenApps.add(packageName);
    notifyListeners();
    _saveHiddenApps();
  }

  void unhideApp(String packageName) {
    _hiddenApps.remove(packageName);
    notifyListeners();
    _saveHiddenApps();
  }

  String displayLabelFor(String packageName, String fallback) {
    return _customLabels[packageName] ?? fallback;
  }

  String displayLabel(AppInfo app) {
    return displayLabelFor(app.packageName, app.label);
  }

  void _sortApps() {
    _allApps.sort(
      (a, b) =>
          _foldForSearch(displayLabel(a)).compareTo(
            _foldForSearch(displayLabel(b)),
          ),
    );
  }

  /// Lowercase + Latin-diacritic-folded form for case- and accent-insensitive
  /// matching and sorting. Non-Latin scripts (CJK, Arabic, Hindi, etc.) pass
  /// through unchanged.
  static String _foldForSearch(String s) {
    final lower = s.toLowerCase();
    if (lower.codeUnits.every((c) => c < 0x00C0)) return lower;
    final buf = StringBuffer();
    for (final r in lower.runes) {
      buf.write(_diacriticFold[r] ?? String.fromCharCode(r));
    }
    return buf.toString();
  }

  static const Map<int, String> _diacriticFold = {
    // a
    0x00E0: 'a', 0x00E1: 'a', 0x00E2: 'a', 0x00E3: 'a', 0x00E4: 'a',
    0x00E5: 'a', 0x0101: 'a', 0x0103: 'a', 0x0105: 'a',
    // ae
    0x00E6: 'ae',
    // c
    0x00E7: 'c', 0x0107: 'c', 0x010D: 'c',
    // d
    0x010F: 'd', 0x0111: 'd',
    // e
    0x00E8: 'e', 0x00E9: 'e', 0x00EA: 'e', 0x00EB: 'e', 0x0113: 'e',
    0x0117: 'e', 0x0119: 'e', 0x011B: 'e',
    // g
    0x011F: 'g', 0x0123: 'g',
    // i
    0x00EC: 'i', 0x00ED: 'i', 0x00EE: 'i', 0x00EF: 'i', 0x012B: 'i',
    0x012F: 'i', 0x0131: 'i',
    // l
    0x013A: 'l', 0x013E: 'l', 0x0142: 'l',
    // n
    0x00F1: 'n', 0x0144: 'n', 0x0148: 'n',
    // o
    0x00F0: 'd', 0x00F2: 'o', 0x00F3: 'o', 0x00F4: 'o', 0x00F5: 'o',
    0x00F6: 'o', 0x00F8: 'o', 0x014D: 'o', 0x0151: 'o',
    // oe
    0x0153: 'oe',
    // r
    0x0155: 'r', 0x0159: 'r',
    // s
    0x015B: 's', 0x015F: 's', 0x0161: 's',
    // t
    0x0163: 't', 0x0165: 't',
    // u
    0x00F9: 'u', 0x00FA: 'u', 0x00FB: 'u', 0x00FC: 'u', 0x016B: 'u',
    0x016F: 'u', 0x0171: 'u', 0x0173: 'u',
    // y
    0x00FD: 'y', 0x00FF: 'y',
    // z
    0x017A: 'z', 0x017C: 'z', 0x017E: 'z',
    // ss / sharp s
    0x00DF: 'ss',
    // þ
    0x00FE: 'th',
  };

  void _loadCustomLabels() {
    final json = _prefs.getString(_labelsKey);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _customLabels.addAll(map.cast<String, String>());
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
      _hiddenApps.addAll(list.cast<String>());
    } on FormatException {
      debugPrint('Corrupt hidden apps JSON, resetting');
      _prefs.remove(_hiddenKey);
    }
  }

  Future<void> _saveHiddenApps() async {
    await _prefs.setString(_hiddenKey, jsonEncode(_hiddenApps.toList()));
  }
}
