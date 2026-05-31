import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_launcher/features/app_drawer/app_list_state.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
import 'package:last_launcher/shared/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppChannel extends AppChannel {
  _FakeAppChannel(this.apps);

  List<AppInfo> apps;

  @override
  Future<List<AppInfo>> getInstalledApps() async => apps;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppListState._pruneOrphanedState', () {
    test('drops orphaned custom labels and hidden apps', () async {
      SharedPreferences.setMockInitialValues({
        'custom_labels': jsonEncode({
          'com.kept': 'Kept Label',
          'com.gone': 'Gone Label',
        }),
        'hidden_apps': jsonEncode(['com.kept', 'com.gone']),
      });
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'com.kept', label: 'Kept'),
      ]);
      final state = AppListState(channel, prefs);

      await state.loadApps();

      expect(state.displayLabelFor('com.kept', 'fallback'), 'Kept Label');
      expect(state.displayLabelFor('com.gone', 'fallback'), 'fallback');
      expect(state.isHidden('com.kept'), true);
      expect(state.isHidden('com.gone'), false);
    });

    test('preserves state when channel returns empty list', () async {
      SharedPreferences.setMockInitialValues({
        'custom_labels': jsonEncode({'com.kept': 'Kept Label'}),
        'hidden_apps': jsonEncode(['com.kept']),
      });
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([]);
      final state = AppListState(channel, prefs);

      await state.loadApps();

      expect(state.allApps, isEmpty);
      expect(state.displayLabelFor('com.kept', 'fallback'), 'Kept Label');
      expect(state.isHidden('com.kept'), true);
    });

    test('empty-list load does not persist a wipe', () async {
      SharedPreferences.setMockInitialValues({
        'custom_labels': jsonEncode({'com.kept': 'Kept Label'}),
        'hidden_apps': jsonEncode(['com.kept']),
      });
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([]);
      final state = AppListState(channel, prefs);

      await state.loadApps();

      final restored = AppListState(channel, prefs);
      expect(restored.displayLabelFor('com.kept', 'fallback'), 'Kept Label');
      expect(restored.isHidden('com.kept'), true);
    });
  });

  group('AppListState hints exclude hidden apps', () {
    test('hiding a duplicate-name app unblocks the hint', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'cam.a', label: 'Camera'),
        const AppInfo(packageName: 'cam.b', label: 'Camera'),
        const AppInfo(packageName: 'other', label: 'Other'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      // Both visible — identical labels, no hint.
      expect(state.hints['Camera'], isNull);

      // Hide one Camera app.
      state.hideApp('cam.b');
      expect(state.hints['Camera'], isNotNull);

      // Unhide it — hint is lost again.
      state.unhideApp('cam.b');
      expect(state.hints['Camera'], isNull);
    });
  });
}
