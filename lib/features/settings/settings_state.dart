import 'package:flutter/material.dart';
import 'package:last_launcher/features/modules/launcher_module.dart';
import 'package:last_launcher/features/modules/none_module.dart';
import 'package:last_launcher/features/modules/tasks_module.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPrefs {
  const SearchPrefs({
    required this.matchOriginal,
    required this.includeHidden,
    required this.hidePersonalWhenWorkActive,
  });

  final bool matchOriginal;
  final bool includeHidden;
  final bool hidePersonalWhenWorkActive;
}

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
  static const _showHintsKey = 'show_hints';
  static const _showWorkAppDotKey = 'show_work_app_dot';
  static const _showWorkAppDotOnHomeKey = 'show_work_app_dot_on_home';
  static const _hidePersonalWhenWorkActiveKey =
      'hide_personal_when_work_active';
  static const _removeOnCompleteKey = 'remove_on_complete';
  static const _hideStatusBarKey = 'hide_status_bar';
  static const _hidePinnedFromDrawerKey = 'hide_pinned_from_drawer';
  static const _includeHiddenInSearchKey = 'include_hidden_in_search';
  static const _matchOriginalNameKey = 'match_original_name';
  static const _lockedKey = 'locked';
  static const _doubleTapToSleepKey = 'double_tap_to_sleep';
  static const _quickLaunchHintsKey = 'quick_launch_hints';
  static const _extraCharKey = 'extra_char';
  static const _clearCompletedDailyKey = 'clear_completed_daily';
  static const _fontSizeHomeKey = 'font_size_home';
  static const _fontSizeShellKey = 'font_size_shell';
  static const _fontFamilyKey = 'font_family';
  static const _homeAlignmentKey = 'home_alignment';
  final SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoKeyboard = true;
  bool _autoKeyboardTasks = true;
  bool _searchOnly = false;
  bool _autoLaunch = true;
  LauncherModule _leftPanel = const NoneModule();
  bool _showHints = true;
  bool _showWorkAppDot = true;
  bool _showWorkAppDotOnHome = false;
  bool _savedShowWorkAppDotOnHome = false;
  bool _savedShowWorkAppDot = true;
  bool _hidePersonalWhenWorkActive = false;
  bool _removeOnComplete = false;
  bool _hideStatusBar = false;
  bool _hidePinnedFromDrawer = false;
  bool _includeHiddenInSearch = false;
  bool _matchOriginalName = true;
  bool _locked = false;
  bool _doubleTapToSleep = true;
  bool _quickLaunchHints = false;
  bool _extraChar = false;
  bool _savedExtraCharFromAutoLaunch = false;
  bool _savedQuickLaunchHints = false;
  bool _savedQuickLaunchHintsFromAutoLaunch = false;
  bool _clearCompletedDaily = false;
  double _fontSizeHome = 43.0;
  double _fontSizeShell = 30.0;
  String? _fontFamily;
  TextAlign _homeAlignment = TextAlign.center;
  ThemeMode get themeMode => _themeMode;
  bool get autoKeyboard => _autoKeyboard;
  bool get autoKeyboardTasks => _autoKeyboardTasks;
  bool get searchOnly => _searchOnly;
  bool get autoLaunch => _autoLaunch;
  LauncherModule get leftPanel => _leftPanel;
  bool get tasksEnabled => _leftPanel is TasksModule;
  bool get showHints => _showHints;
  bool get showWorkAppDot => _showWorkAppDot;
  bool get showWorkAppDotOnHome => _showWorkAppDotOnHome;
  bool get hidePersonalWhenWorkActive => _hidePersonalWhenWorkActive;
  bool get removeOnComplete => _removeOnComplete;
  bool get hideStatusBar => _hideStatusBar;
  bool get hidePinnedFromDrawer => _hidePinnedFromDrawer;
  bool get includeHiddenInSearch => _includeHiddenInSearch;
  bool get matchOriginalName => _matchOriginalName;
  bool get locked => _locked;
  bool get doubleTapToSleep => _doubleTapToSleep;
  bool get quickLaunchHints => _quickLaunchHints;
  bool get extraChar => _extraChar;
  bool get clearCompletedDaily => _clearCompletedDaily;
  double get fontSizeHome => _fontSizeHome;
  double get fontSizeShell => _fontSizeShell;
  String? get fontFamily => _fontFamily;
  TextAlign get homeAlignment => _homeAlignment;
  SearchPrefs get searchPrefs => SearchPrefs(
    matchOriginal: _matchOriginalName,
    includeHidden: _includeHiddenInSearch,
    hidePersonalWhenWorkActive: _hidePersonalWhenWorkActive,
  );

  void _load() {
    final value = _prefs.getString(_themeKey);
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
    if (leftId == null) {
      // Migrate legacy tasks_enabled flag.
      final legacyTasks = _prefs.getBool(_tasksEnabledKey) ?? false;
      _leftPanel = legacyTasks ? TasksModule() : const NoneModule();
    } else {
      _leftPanel = moduleById(leftId);
    }
    _showHints = _prefs.getBool(_showHintsKey) ?? true;
    _showWorkAppDot = _prefs.getBool(_showWorkAppDotKey) ?? true;
    _showWorkAppDotOnHome = _prefs.getBool(_showWorkAppDotOnHomeKey) ?? false;
    _hidePersonalWhenWorkActive =
        _prefs.getBool(_hidePersonalWhenWorkActiveKey) ?? false;
    _removeOnComplete = _prefs.getBool(_removeOnCompleteKey) ?? false;
    _hideStatusBar = _prefs.getBool(_hideStatusBarKey) ?? false;
    _hidePinnedFromDrawer = _prefs.getBool(_hidePinnedFromDrawerKey) ?? false;
    _includeHiddenInSearch = _prefs.getBool(_includeHiddenInSearchKey) ?? false;
    _matchOriginalName = _prefs.getBool(_matchOriginalNameKey) ?? true;
    _locked = _prefs.getBool(_lockedKey) ?? false;
    _doubleTapToSleep = _prefs.getBool(_doubleTapToSleepKey) ?? true;
    _quickLaunchHints = _prefs.getBool(_quickLaunchHintsKey) ?? false;
    _extraChar = _prefs.getBool(_extraCharKey) ?? false;
    _clearCompletedDaily = _prefs.getBool(_clearCompletedDailyKey) ?? false;
    _fontSizeHome = _prefs.getDouble(_fontSizeHomeKey) ?? 43.0;
    _fontSizeShell = _prefs.getDouble(_fontSizeShellKey) ?? 30.0;
    _fontFamily = _prefs.getString(_fontFamilyKey) ?? 'Raleway-Thin';
    _homeAlignment = switch (_prefs.getString(_homeAlignmentKey)) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
  }

  Future<void> setTheme(String value) async {
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
    themeNotifier.value++;
    await _prefs.setString(_themeKey, value);
  }

  String get themeValue {
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
    if (enabled) {
      if (_quickLaunchHints) {
        _savedQuickLaunchHints = true;
        _quickLaunchHints = false;
        await _prefs.setBool(_quickLaunchHintsKey, false);
      }
    } else if (_savedQuickLaunchHints) {
      _quickLaunchHints = true;
      _savedQuickLaunchHints = false;
      await _prefs.setBool(_quickLaunchHintsKey, true);
    }
    notifyListeners();
    await _prefs.setBool(_searchOnlyKey, enabled);
  }

  Future<void> setAutoLaunch(bool enabled) async {
    _autoLaunch = enabled;
    if (!enabled && _quickLaunchHints) {
      _savedQuickLaunchHintsFromAutoLaunch = true;
      _quickLaunchHints = false;
      await _prefs.setBool(_quickLaunchHintsKey, false);
    } else if (enabled && _savedQuickLaunchHintsFromAutoLaunch) {
      _quickLaunchHints = true;
      _savedQuickLaunchHintsFromAutoLaunch = false;
      await _prefs.setBool(_quickLaunchHintsKey, true);
    }
    if (!enabled && _extraChar) {
      _savedExtraCharFromAutoLaunch = true;
      _extraChar = false;
      await _prefs.setBool(_extraCharKey, false);
    } else if (enabled && _savedExtraCharFromAutoLaunch) {
      _extraChar = true;
      _savedExtraCharFromAutoLaunch = false;
      await _prefs.setBool(_extraCharKey, true);
    }
    notifyListeners();
    await _prefs.setBool(_autoLaunchKey, enabled);
  }

  Future<void> setLeftPanel(LauncherModule panel) async {
    _leftPanel = panel;
    notifyListeners();
    await _prefs.setString(_leftPanelKey, panel.id);
  }

  Future<void> setShowHints(bool enabled) async {
    _showHints = enabled;
    notifyListeners();
    await _prefs.setBool(_showHintsKey, enabled);
  }

  Future<void> setShowWorkAppDot(bool enabled) async {
    _showWorkAppDot = enabled;
    if (enabled) {
      _showWorkAppDotOnHome = _savedShowWorkAppDotOnHome;
    } else {
      _savedShowWorkAppDotOnHome = _showWorkAppDotOnHome;
      _showWorkAppDotOnHome = false;
    }
    notifyListeners();
    await _prefs.setBool(_showWorkAppDotKey, enabled);
    await _prefs.setBool(_showWorkAppDotOnHomeKey, _showWorkAppDotOnHome);
  }

  Future<void> setShowWorkAppDotOnHome(bool enabled) async {
    _showWorkAppDotOnHome = enabled;
    notifyListeners();
    await _prefs.setBool(_showWorkAppDotOnHomeKey, enabled);
  }

  Future<void> setHidePersonalWhenWorkActive(bool enabled) async {
    _hidePersonalWhenWorkActive = enabled;
    if (enabled) {
      _savedShowWorkAppDot = _showWorkAppDot;
      _savedShowWorkAppDotOnHome = _showWorkAppDotOnHome;
      _showWorkAppDot = false;
      _showWorkAppDotOnHome = false;
    } else {
      _showWorkAppDot = _savedShowWorkAppDot;
      _showWorkAppDotOnHome = _savedShowWorkAppDotOnHome;
    }
    notifyListeners();
    await _prefs.setBool(_hidePersonalWhenWorkActiveKey, enabled);
    await _prefs.setBool(_showWorkAppDotKey, _showWorkAppDot);
    await _prefs.setBool(_showWorkAppDotOnHomeKey, _showWorkAppDotOnHome);
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

  Future<void> setExtraChar(bool enabled) async {
    _extraChar = enabled;
    notifyListeners();
    await _prefs.setBool(_extraCharKey, enabled);
  }

  Future<void> setClearCompletedDaily(bool enabled) async {
    _clearCompletedDaily = enabled;
    notifyListeners();
    await _prefs.setBool(_clearCompletedDailyKey, enabled);
  }

  Future<void> setFontSizeHome(double value) async {
    _fontSizeHome = value;
    notifyListeners();
    await _prefs.setDouble(_fontSizeHomeKey, value);
  }

  Future<void> setFontSizeShell(double value) async {
    _fontSizeShell = value;
    notifyListeners();
    await _prefs.setDouble(_fontSizeShellKey, value);
  }

  Future<void> setFontFamily(String? value) async {
    _fontFamily = value;
    notifyListeners();
    themeNotifier.value++;
    if (value == null) {
      await _prefs.remove(_fontFamilyKey);
    } else {
      await _prefs.setString(_fontFamilyKey, value);
    }
  }

  Future<void> setHomeAlignment(TextAlign value) async {
    _homeAlignment = value;
    notifyListeners();
    await _prefs.setString(_homeAlignmentKey, value.name);
  }
}
