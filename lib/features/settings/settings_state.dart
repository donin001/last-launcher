import 'package:flutter/material.dart';
import 'package:last_launcher/features/modules/launcher_module.dart';
import 'package:last_launcher/features/modules/none_module.dart';
import 'package:last_launcher/features/modules/tasks_module.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends ChangeNotifier {
  SettingsState(this._prefs) {
    _load();
  }

  /// Incremented when settings that require rebuilding the [MaterialApp]
  /// subtree change (theme mode, status bar visibility). Exists separately
  /// from [notifyListeners] so routine setting changes (e.g. keyboard toggle)
  /// don't rebuild the entire app.
  final themeNotifier = ValueNotifier<int>(0);

  static const _themeKey = 'theme_mode';
  static const _autoKeyboardKey = 'auto_keyboard';
  static const _autoKeyboardTasksKey = 'auto_keyboard_tasks';
  static const _searchOnlyKey = 'search_only';
  static const _autoLaunchKey = 'auto_launch';
  static const _tasksEnabledKey = 'tasks_enabled';
  static const _leftPanelKey = 'left_panel';
  static const _rightPanelKey = 'right_panel';
  static const _showHintsKey = 'show_hints';
  static const _removeOnCompleteKey = 'remove_on_complete';
  static const _hideStatusBarKey = 'hide_status_bar';
  static const _hidePinnedFromDrawerKey = 'hide_pinned_from_drawer';
  static const _includeHiddenInSearchKey = 'include_hidden_in_search';
  static const _matchOriginalNameKey = 'match_original_name';
  static const _lockedKey = 'locked';
  static const _doubleTapToSleepKey = 'double_tap_to_sleep';
  static const _quickLaunchHintsKey = 'quick_launch_hints';
  static const _clearCompletedDailyKey = 'clear_completed_daily';
  final SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _extraTheme = false;
  bool _autoKeyboard = true;
  bool _autoKeyboardTasks = true;
  bool _searchOnly = false;
  bool _autoLaunch = true;
  LauncherModule _leftPanel = const NoneModule();
  LauncherModule _rightPanel = const NoneModule();
  bool _showHints = true;
  bool _removeOnComplete = false;
  bool _hideStatusBar = false;
  bool _hidePinnedFromDrawer = true;
  bool _includeHiddenInSearch = false;
  bool _matchOriginalName = true;
  bool _locked = false;
  bool _doubleTapToSleep = true;
  bool _quickLaunchHints = false;
  bool _clearCompletedDaily = false;
  ThemeMode get themeMode => _extraTheme ? ThemeMode.dark : _themeMode;
  bool get isExtra => _extraTheme;
  bool get autoKeyboard => _autoKeyboard;
  bool get autoKeyboardTasks => _autoKeyboardTasks;
  bool get searchOnly => _searchOnly;
  bool get autoLaunch => _autoLaunch;
  LauncherModule get leftPanel => _leftPanel;
  LauncherModule get rightPanel => _rightPanel;
  bool get tasksEnabled =>
      _leftPanel is TasksModule || _rightPanel is TasksModule;
  bool get showHints => _showHints;
  bool get removeOnComplete => _removeOnComplete;
  bool get hideStatusBar => _hideStatusBar;
  bool get hidePinnedFromDrawer => _hidePinnedFromDrawer;
  bool get includeHiddenInSearch => _includeHiddenInSearch;
  bool get matchOriginalName => _matchOriginalName;
  bool get locked => _locked;
  bool get doubleTapToSleep => _doubleTapToSleep;
  bool get quickLaunchHints => _quickLaunchHints;
  bool get clearCompletedDaily => _clearCompletedDaily;

  void _load() {
    final value = _prefs.getString(_themeKey);
    _extraTheme = value == 'extra';
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _autoKeyboard = _prefs.getBool(_autoKeyboardKey) ?? true;
    _autoKeyboardTasks = _prefs.getBool(_autoKeyboardTasksKey) ?? true;
    _searchOnly = _prefs.getBool(_searchOnlyKey) ?? false;
    _autoLaunch = _prefs.getBool(_autoLaunchKey) ?? true;
    final leftId = _prefs.getString(_leftPanelKey);
    final rightId = _prefs.getString(_rightPanelKey);
    if (leftId == null && rightId == null) {
      // Migrate legacy tasks_enabled flag.
      final legacyTasks = _prefs.getBool(_tasksEnabledKey) ?? false;
      _leftPanel = legacyTasks ? TasksModule() : const NoneModule();
      _rightPanel = const NoneModule();
    } else {
      _leftPanel = moduleById(leftId);
      _rightPanel = moduleById(rightId);
    }
    _showHints = _prefs.getBool(_showHintsKey) ?? true;
    _removeOnComplete = _prefs.getBool(_removeOnCompleteKey) ?? false;
    _hideStatusBar = _prefs.getBool(_hideStatusBarKey) ?? false;
    _hidePinnedFromDrawer = _prefs.getBool(_hidePinnedFromDrawerKey) ?? true;
    _includeHiddenInSearch = _prefs.getBool(_includeHiddenInSearchKey) ?? false;
    _matchOriginalName = _prefs.getBool(_matchOriginalNameKey) ?? true;
    _locked = _prefs.getBool(_lockedKey) ?? false;
    _doubleTapToSleep = _prefs.getBool(_doubleTapToSleepKey) ?? true;
    _quickLaunchHints = _prefs.getBool(_quickLaunchHintsKey) ?? false;
    _clearCompletedDaily = _prefs.getBool(_clearCompletedDailyKey) ?? false;
  }

  Future<void> setTheme(String value) async {
    _extraTheme = value == 'extra';
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'extra' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
    themeNotifier.value++;
    await _prefs.setString(_themeKey, value);
  }

  String get themeValue {
    if (_extraTheme) return 'extra';
    return switch (_themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  Future<void> setAutoKeyboard(bool enabled) async {
    _autoKeyboard = enabled;
    notifyListeners();
    await _prefs.setBool(_autoKeyboardKey, enabled);
  }

  Future<void> setAutoKeyboardTasks(bool enabled) async {
    _autoKeyboardTasks = enabled;
    notifyListeners();
    await _prefs.setBool(_autoKeyboardTasksKey, enabled);
  }

  Future<void> setSearchOnly(bool enabled) async {
    _searchOnly = enabled;
    if (enabled && _quickLaunchHints) {
      _quickLaunchHints = false;
      await _prefs.setBool(_quickLaunchHintsKey, false);
    }
    notifyListeners();
    await _prefs.setBool(_searchOnlyKey, enabled);
  }

  Future<void> setAutoLaunch(bool enabled) async {
    _autoLaunch = enabled;
    if (!enabled && _quickLaunchHints) {
      _quickLaunchHints = false;
      await _prefs.setBool(_quickLaunchHintsKey, false);
    }
    notifyListeners();
    await _prefs.setBool(_autoLaunchKey, enabled);
  }

  Future<void> setLeftPanel(LauncherModule panel) async {
    _leftPanel = panel;
    if (panel is! NoneModule && _rightPanel.id == panel.id) {
      _rightPanel = const NoneModule();
      await _prefs.setString(_rightPanelKey, _rightPanel.id);
    }
    notifyListeners();
    await _prefs.setString(_leftPanelKey, panel.id);
  }

  Future<void> setRightPanel(LauncherModule panel) async {
    _rightPanel = panel;
    if (panel is! NoneModule && _leftPanel.id == panel.id) {
      _leftPanel = const NoneModule();
      await _prefs.setString(_leftPanelKey, _leftPanel.id);
    }
    notifyListeners();
    await _prefs.setString(_rightPanelKey, panel.id);
  }

  Future<void> setShowHints(bool enabled) async {
    _showHints = enabled;
    notifyListeners();
    await _prefs.setBool(_showHintsKey, enabled);
  }

  Future<void> setRemoveOnComplete(bool enabled) async {
    _removeOnComplete = enabled;
    notifyListeners();
    await _prefs.setBool(_removeOnCompleteKey, enabled);
  }

  Future<void> setHideStatusBar(bool enabled) async {
    _hideStatusBar = enabled;
    notifyListeners();
    themeNotifier.value++;
    await _prefs.setBool(_hideStatusBarKey, enabled);
  }

  Future<void> setHidePinnedFromDrawer(bool enabled) async {
    _hidePinnedFromDrawer = enabled;
    notifyListeners();
    await _prefs.setBool(_hidePinnedFromDrawerKey, enabled);
  }

  Future<void> setIncludeHiddenInSearch(bool enabled) async {
    _includeHiddenInSearch = enabled;
    notifyListeners();
    await _prefs.setBool(_includeHiddenInSearchKey, enabled);
  }

  Future<void> setMatchOriginalName(bool enabled) async {
    _matchOriginalName = enabled;
    notifyListeners();
    await _prefs.setBool(_matchOriginalNameKey, enabled);
  }

  Future<void> setLocked(bool enabled) async {
    _locked = enabled;
    notifyListeners();
    await _prefs.setBool(_lockedKey, enabled);
  }

  Future<void> setDoubleTapToSleep(bool enabled) async {
    _doubleTapToSleep = enabled;
    notifyListeners();
    await _prefs.setBool(_doubleTapToSleepKey, enabled);
  }

  Future<void> setQuickLaunchHints(bool enabled) async {
    _quickLaunchHints = enabled;
    notifyListeners();
    await _prefs.setBool(_quickLaunchHintsKey, enabled);
  }

  Future<void> setClearCompletedDaily(bool enabled) async {
    _clearCompletedDaily = enabled;
    notifyListeners();
    await _prefs.setBool(_clearCompletedDailyKey, enabled);
  }
}
