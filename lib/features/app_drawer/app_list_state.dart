import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:last_launcher/features/app_drawer/search.dart';
import 'package:last_launcher/features/settings/settings_state.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
import 'package:last_launcher/shared/data/fold_for_search.dart';
import 'package:last_launcher/shared/data/hints.dart';
import 'package:last_launcher/shared/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppListState extends ChangeNotifier {
  AppListState(this._channel, this._prefs) {
    _loadCustomLabels();
    _loadHiddenApps();
    _loadFolders();
    _searchPrefs = SearchPrefs(
      matchOriginal: _prefs.getBool(_matchOriginalKey) ?? true,
      includeHidden: _prefs.getBool(_includeHiddenInSearchKey) ?? false,
      hidePersonalWhenWorkActive:
          _prefs.getBool(_hidePersonalWhenWorkActiveKey) ?? false,
    );
  }

  static const _labelsKey = 'custom_labels';
  static const _hiddenKey = 'hidden_apps';
  static const _matchOriginalKey = 'match_original_name';
  static const _includeHiddenInSearchKey = 'include_hidden_in_search';
  static const _hidePersonalWhenWorkActiveKey =
      'hide_personal_when_work_active';
  static const _foldersKey = 'app_folders';
  static const _topLevelOrderKey = 'top_level_order';

  final AppChannel _channel;
  final SharedPreferences _prefs;
  List<AppInfo> _allApps = [];
  String _query = '';
  bool _loading = false;
  late SearchPrefs _searchPrefs;
  bool _hasWorkProfile = false;
  final Map<String, String> _customLabels = {};
  final Set<String> _hiddenApps = {};
  List<AppFolder> _folders = [];
  List<String> _topLevelOrder = [];
  Map<String, SubstringHint?> _hints = {};

  List<AppInfo> get allApps => List.unmodifiable(_allApps);
  Set<String> get workPackages => {
    for (final a in _allApps)
      if (a.isWorkApp) a.packageName,
  };
  bool get hasWorkApps => _allApps.any((a) => a.isWorkApp);
  bool get hasWorkProfile => _hasWorkProfile;
  bool get profilePrefixEnabled =>
      _hasWorkProfile && !_searchPrefs.hidePersonalWhenWorkActive;
  String get query => _query;

  List<AppFolder> get folders => List.unmodifiable(_folders);

  Set<String> get _appsInFolders => {
    for (final folder in _folders)
      for (final app in folder.apps) _compoundKey(app.packageName, app.isWorkApp),
  };

  List<AppInfo> get hiddenApps => _allApps
      .where(
        (a) => _hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)),
      )
      .toList();

  Map<String, SubstringHint?> get hints => _hints;

  bool isHidden(String packageName, {bool isWorkApp = false}) =>
      _hiddenApps.contains(_compoundKey(packageName, isWorkApp));

  void applyPrefs(SearchPrefs prefs) {
    _searchPrefs = prefs;
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
                !_hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)) &&
                (_query.isNotEmpty ||
                    !_appsInFolders.contains(
                      _compoundKey(a.packageName, a.isWorkApp),
                    )),
          );
    if (_searchPrefs.hidePersonalWhenWorkActive && hasWorkApps) {
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
      _loadTopLevelOrder();
      _syncTopLevelOrder();
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
    _pruneFolders();
  }

  void _pruneFolders() {
    if (_allApps.isEmpty) return;
    final installedCompound = {
      for (final a in _allApps) _compoundKey(a.packageName, a.isWorkApp),
    };
    var changed = false;
    for (var i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      final before = folder.apps.length;
      final filteredApps =
          folder.apps
              .where((a) => installedCompound.contains(_compoundKey(a.packageName, a.isWorkApp)))
              .toList();
      if (filteredApps.length != before) {
        _folders[i] = folder.copyWith(apps: filteredApps);
        changed = true;
      }
    }
    // Optional: remove empty folders? Let's keep them for now as user might want to fill them.
    if (changed) {
      _saveFolders();
      notifyListeners();
    }
  }

  /// Set of package names currently installed.
  Set<String> get installedPackages => {
    for (final a in _allApps) a.packageName,
  };

  void filter(String query) {
    _query = query;
    _computeHints();
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

  void _syncTopLevelOrder() {
    final currentKeys = <String>{};
    for (final f in _folders) {
      currentKeys.add(f.id);
    }
    for (final a in _allApps) {
      final key = _compoundKey(a.packageName, a.isWorkApp);
      if (!_appsInFolders.contains(key) && !_hiddenApps.contains(key)) {
        currentKeys.add(key);
      }
    }

    // Remove orphaned keys.
    _topLevelOrder.removeWhere((k) => !currentKeys.contains(k));

    // Add new keys at the end.
    for (final key in currentKeys) {
      if (!_topLevelOrder.contains(key)) {
        _topLevelOrder.add(key);
      }
    }
    _saveTopLevelOrder();
  }

  Future<void> reorderTopLevel(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final key = _topLevelOrder.removeAt(oldIndex);
    _topLevelOrder.insert(newIndex, key);

    _computeHints();
    notifyListeners();
    await _saveTopLevelOrder();
  }

  List<dynamic> getOrderedTopLevel(List<AppInfo> visibleApps) {
    if (_topLevelOrder.isEmpty && (visibleApps.isNotEmpty || _folders.isNotEmpty)) {
      _syncTopLevelOrder();
    }
    final appMap = {
      for (final a in visibleApps) _compoundKey(a.packageName, a.isWorkApp): a
    };
    final folderMap = {for (final f in _folders) f.id: f};

    final result = <dynamic>[];
    for (final key in _topLevelOrder) {
      if (folderMap.containsKey(key)) {
        result.add(folderMap[key]);
      } else if (appMap.containsKey(key)) {
        result.add(appMap[key]);
      }
    }
    return result;
  }

  Future<void> createFolder(String name) async {
    final folder = AppFolder(id: const Uuid().v4(), name: name, apps: []);
    _folders.add(folder);
    _topLevelOrder.add(folder.id);
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;
    _folders[index] = _folders[index].copyWith(name: newName);
    notifyListeners();
    await _saveFolders();
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    _topLevelOrder.remove(folderId);
    _syncTopLevelOrder(); // Apps from folder will return to list, need to be in order
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
  }

  Future<void> combineAppsIntoNewFolder(AppInfo appA, AppInfo appB, String folderName) async {
    final folderId = const Uuid().v4();
    final folder = AppFolder(
      id: folderId,
      name: folderName,
      apps: [
        PinnedApp(packageName: appB.packageName, label: appB.label, isWorkApp: appB.isWorkApp),
        PinnedApp(packageName: appA.packageName, label: appA.label, isWorkApp: appA.isWorkApp),
      ],
    );
    
    _removeAppFromAllFolders(appA.packageName, appA.isWorkApp);
    _removeAppFromAllFolders(appB.packageName, appB.isWorkApp);
    
    final keyA = _compoundKey(appA.packageName, appA.isWorkApp);
    final keyB = _compoundKey(appB.packageName, appB.isWorkApp);
    
    // Find where B was to insert the folder there
    final indexB = _topLevelOrder.indexOf(keyB);
    _topLevelOrder.remove(keyA);
    _topLevelOrder.remove(keyB);
    
    _folders.add(folder);
    if (indexB != -1) {
      _topLevelOrder.insert(indexB, folderId);
    } else {
      _topLevelOrder.add(folderId);
    }
    
    _computeHints();
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
  }

  Future<void> reorderInFolder(String folderId, int oldIndex, int newIndex) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;
    
    final folder = _folders[index];
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    
    final apps = List<PinnedApp>.from(folder.apps);
    final app = apps.removeAt(oldIndex);
    apps.insert(newIndex, app);
    
    _folders[index] = folder.copyWith(apps: apps);
    notifyListeners();
    await _saveFolders();
  }

  Future<void> addAppToFolder(String folderId, AppInfo app) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;
    
    // Remove from existing folders first to avoid duplicates
    _removeAppFromAllFolders(app.packageName, app.isWorkApp);
    
    final folder = _folders[index];
    final pinned = PinnedApp(
      packageName: app.packageName,
      label: app.label,
      isWorkApp: app.isWorkApp,
    );
    
    _folders[index] = folder.copyWith(apps: [...folder.apps, pinned]);
    _topLevelOrder.remove(_compoundKey(app.packageName, app.isWorkApp));
    _computeHints();
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
  }

  Future<void> moveAppToTopLevel(AppInfo app) async {
    _removeAppFromAllFolders(app.packageName, app.isWorkApp);
    _syncTopLevelOrder();
    _computeHints();
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
  }

  void _removeAppFromAllFolders(String packageName, bool isWorkApp) {
    for (var i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      final before = folder.apps.length;
      final newApps = folder.apps
          .where((a) => a.packageName != packageName || a.isWorkApp != isWorkApp)
          .toList();
      if (newApps.length != before) {
        _folders[i] = folder.copyWith(apps: newApps);
      }
    }
  }

  Future<void> removeAppFromFolder(
    String folderId,
    String packageName,
    bool isWorkApp,
  ) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;
    final folder = _folders[index];
    final newApps =
        folder.apps
            .where((a) => a.packageName != packageName || a.isWorkApp != isWorkApp)
            .toList();
    _folders[index] = folder.copyWith(apps: newApps);
    _syncTopLevelOrder();
    _computeHints();
    notifyListeners();
    await _saveFolders();
    await _saveTopLevelOrder();
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

  String displayLabelForSearch(AppInfo app, String query) {
    if (!_searchPrefs.matchOriginal || query.isEmpty) return displayLabel(app);
    final label = displayLabel(app);
    if (label == app.label) return label;

    final foldedQuery = foldForSearch(query);
    final foldedLabel = foldForSearch(label);
    if (foldedLabel.startsWith(foldedQuery)) return label;

    final foldedOriginal = foldForSearch(app.label);
    if (foldedOriginal.startsWith(foldedQuery)) return app.label;

    final alphaNum = RegExp(r'[^\p{L}\p{N}]', unicode: true);
    final cleanQuery = foldedQuery.replaceAll(alphaNum, '');
    final cleanOriginal = cleanQuery.length >= 2
        ? foldedOriginal.replaceAll(alphaNum, '')
        : null;
    if (cleanQuery.length >= 2) {
      if (cleanOriginal!.startsWith(cleanQuery) &&
          !foldedLabel.replaceAll(alphaNum, '').startsWith(cleanQuery)) {
        return app.label;
      }
    }

    // Query matches via original-name contains but not display-name contains.
    if (foldedOriginal.contains(foldedQuery) &&
        !foldedLabel.contains(foldedQuery)) {
      return app.label;
    }
    if (cleanQuery.length >= 2) {
      final cleanLabel = foldedLabel.replaceAll(alphaNum, '');
      if (cleanOriginal!.contains(cleanQuery) &&
          !cleanLabel.contains(cleanQuery)) {
        return app.label;
      }
    }

    return label;
  }

  void _computeHints() {
    Iterable<AppInfo> visible = _searchPrefs.includeHidden
        ? _allApps
        : _allApps.where(
            (a) =>
                !_hiddenApps.contains(_compoundKey(a.packageName, a.isWorkApp)) &&
                (_query.isNotEmpty ||
                    !_appsInFolders.contains(
                      _compoundKey(a.packageName, a.isWorkApp),
                    )),
          );
    if (_searchPrefs.hidePersonalWhenWorkActive && hasWorkApps) {
      visible = visible.where((a) => a.isWorkApp);
    }
    if (_query.isNotEmpty) {
      final searchTerm = SearchQuery.parse(
        _query,
        allowProfileFilter: profilePrefixEnabled,
      ).searchTerm;
      final matching = search(
        _query,
        includeHidden: _searchPrefs.includeHidden,
        matchOriginal: _searchPrefs.matchOriginal,
      );
      final displayLabels = matching
          .map((a) => displayLabelForSearch(a, _query))
          .toList();
      final originals = _searchPrefs.matchOriginal
          ? matching.map((a) => a.label).toList()
          : displayLabels;
      final hintList = computeHintsWithQuery(
        displayLabels,
        originals,
        searchTerm,
      );
      _hints = {
        for (var i = 0; i < matching.length; i++)
          _compoundKey(matching[i].packageName, matching[i].isWorkApp):
              hintList[i],
      };
    } else {
      final visibleList = visible.toList();
      final displayLabels = visibleList.map(displayLabel).toList();
      final originals = _searchPrefs.matchOriginal
          ? visibleList.map((a) => a.label).toList()
          : displayLabels;
      final hintList = computeHints(displayLabels, originals);
      _hints = {
        for (var i = 0; i < visibleList.length; i++)
          _compoundKey(visibleList[i].packageName, visibleList[i].isWorkApp):
              hintList[i],
      };
    }
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

  void _loadFolders() {
    final json = _prefs.getString(_foldersKey);
    if (json == null) return;
    try {
      _folders = AppFolder.decodeList(json);
    } on FormatException {
      debugPrint('Corrupt folders JSON, resetting');
      _prefs.remove(_foldersKey);
    }
  }

  Future<void> _saveFolders() async {
    await _prefs.setString(_foldersKey, AppFolder.encodeList(_folders));
  }

  void _loadTopLevelOrder() {
    final list = _prefs.getStringList(_topLevelOrderKey);
    if (list != null) {
      _topLevelOrder = list;
    }
  }

  Future<void> _saveTopLevelOrder() async {
    await _prefs.setStringList(_topLevelOrderKey, _topLevelOrder);
  }
}
