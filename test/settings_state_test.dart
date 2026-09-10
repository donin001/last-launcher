import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_launcher/features/modules/none_module.dart';
import 'package:last_launcher/features/modules/tasks_module.dart';
import 'package:last_launcher/features/settings/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(prefs);
  });

  group('SettingsState defaults', () {
    test('theme defaults to system', () {
      expect(state.themeMode, ThemeMode.system);
      expect(state.themeValue, 'system');
      expect(state.homeAlignment, TextAlign.center);
    });

    test('boolean defaults', () {
      expect(state.autoKeyboard, true);
      expect(state.autoKeyboardTasks, true);
      expect(state.searchOnly, false);
      expect(state.autoLaunch, true);
      expect(state.tasksEnabled, false);
      expect(state.showHints, true);
      expect(state.removeOnComplete, false);
      expect(state.hideStatusBar, false);
    });
  });

  group('SettingsState theme', () {
    test('sets light theme', () async {
      await state.setTheme('light');
      expect(state.themeMode, ThemeMode.light);
      expect(state.themeValue, 'light');
    });

    test('sets dark theme', () async {
      await state.setTheme('dark');
      expect(state.themeMode, ThemeMode.dark);
      expect(state.themeValue, 'dark');
    });

    test('increments themeNotifier', () async {
      final initial = state.themeNotifier.value;
      await state.setTheme('dark');
      expect(state.themeNotifier.value, initial + 1);
    });
  });

  group('SettingsState toggles', () {
    test('setAutoKeyboard', () async {
      await state.setAutoKeyboard(false);
      expect(state.autoKeyboard, false);
    });

    test('setSearchOnly', () async {
      await state.setSearchOnly(true);
      expect(state.searchOnly, true);
    });

    test('setLeftPanel enables tasks', () async {
      await state.setLeftPanel(TasksModule());
      expect(state.leftPanel, isA<TasksModule>());
      expect(state.tasksEnabled, true);
    });

    test('setRemoveOnComplete', () async {
      await state.setRemoveOnComplete(true);
      expect(state.removeOnComplete, true);
    });

    test('setHideStatusBar increments themeNotifier', () async {
      final initial = state.themeNotifier.value;
      await state.setHideStatusBar(true);
      expect(state.hideStatusBar, true);
      expect(state.themeNotifier.value, initial + 1);
    });

    test('setHomeAlignment', () async {
      await state.setHomeAlignment(TextAlign.left);
      expect(state.homeAlignment, TextAlign.left);
    });
  });

  group('SettingsState persistence', () {
    test('persists and restores all settings', () async {
      await state.setTheme('dark');
      await state.setAutoKeyboard(false);
      await state.setSearchOnly(true);
      await state.setLeftPanel(TasksModule());
      await state.setRemoveOnComplete(true);
      await state.setHideStatusBar(true);
      await state.setHomeAlignment(TextAlign.right);

      final prefs = await SharedPreferences.getInstance();
      final restored = SettingsState(prefs);
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.autoKeyboard, false);
      expect(restored.searchOnly, true);
      expect(restored.leftPanel, isA<TasksModule>());
      expect(restored.tasksEnabled, true);
      expect(restored.removeOnComplete, true);
      expect(restored.hideStatusBar, true);
      expect(restored.homeAlignment, TextAlign.right);
    });

    test('migrates legacy tasks_enabled=true flag', () async {
      SharedPreferences.setMockInitialValues({'tasks_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final migrated = SettingsState(prefs);
      expect(migrated.leftPanel, isA<TasksModule>());
      expect(migrated.tasksEnabled, true);
    });

    test('migrates legacy tasks_enabled=false flag', () async {
      SharedPreferences.setMockInitialValues({'tasks_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final migrated = SettingsState(prefs);
      expect(migrated.leftPanel, isA<NoneModule>());
      expect(migrated.tasksEnabled, false);
    });
  });

  group('SettingsState notifications', () {
    test('notifies on every setter', () async {
      var count = 0;
      state.addListener(() => count++);

      await state.setTheme('dark');
      await state.setAutoKeyboard(false);
      await state.setSearchOnly(true);
      await state.setAutoLaunch(false);
      await state.setLeftPanel(TasksModule());
      await state.setShowHints(false);
      await state.setRemoveOnComplete(true);
      await state.setHideStatusBar(true);

      expect(count, 8);
    });
  });
}
