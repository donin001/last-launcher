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

  @override
  Future<bool> hasWorkProfile() async => false;
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

    test(
      'preserves work-app hidden entries when work profile is paused',
      () async {
        SharedPreferences.setMockInitialValues({
          'hidden_apps': jsonEncode(['com.work|true', 'com.gone|false']),
        });
        final prefs = await SharedPreferences.getInstance();
        // Only personal apps returned — simulates paused work profile
        final channel = _FakeAppChannel([
          const AppInfo(packageName: 'com.other', label: 'Other'),
        ]);
        final state = AppListState(channel, prefs);

        await state.loadApps();

        expect(state.isHidden('com.work', isWorkApp: true), true);
        expect(state.isHidden('com.gone'), false);
      },
    );

    test(
      'preserves custom labels for work apps when work profile is paused',
      () async {
        SharedPreferences.setMockInitialValues({
          'custom_labels': jsonEncode({
            'com.workapp': 'Work Label',
            'com.personal': 'Personal Label',
          }),
          'hidden_apps': jsonEncode(['com.workapp|true']),
        });
        final prefs = await SharedPreferences.getInstance();
        final channel = _FakeAppChannel([
          const AppInfo(packageName: 'com.personal', label: 'Personal'),
        ]);
        final state = AppListState(channel, prefs);

        await state.loadApps();

        expect(state.displayLabelFor('com.workapp', 'fallback'), 'Work Label');
        expect(
          state.displayLabelFor('com.personal', 'fallback'),
          'Personal Label',
        );
      },
    );

    test('prunes personal hidden entries but keeps work entries', () async {
      SharedPreferences.setMockInitialValues({
        'hidden_apps': jsonEncode(['com.work|true', 'com.gone|false']),
      });
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'com.work', label: 'Work', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);

      await state.loadApps();

      expect(state.isHidden('com.work', isWorkApp: true), true);
      expect(state.isHidden('com.gone'), false);
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

  group('AppListState hints recompute on rename', () {
    test('hints map is keyed by new display label after rename', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'app.a', label: 'Alpha'),
        const AppInfo(packageName: 'app.b', label: 'Beta'),
        const AppInfo(packageName: 'app.c', label: 'Gamma'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      state.setCustomLabel('app.b', 'Bee');

      expect(state.hints.containsKey('Beta'), false);
      expect(state.hints.containsKey('Bee'), true);
    });

    test(
      'renaming an app with no original-name collision updates its hint',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channel = _FakeAppChannel([
          const AppInfo(packageName: 'app.a', label: 'Alpha'),
          const AppInfo(packageName: 'app.b', label: 'Beta'),
          const AppInfo(packageName: 'app.c', label: 'Gamma'),
        ]);
        final state = AppListState(channel, prefs);
        await state.loadApps();

        expect(state.hints['Beta'], isNotNull);
        expect(state.hints['Beta']!.start, 0);
        expect(state.hints['Beta']!.length, 1);

        state.setCustomLabel('app.b', 'Zeta');

        expect(state.hints.containsKey('Beta'), false);
        expect(state.hints.containsKey('Zeta'), true);
        expect(state.hints['Zeta']!.start, 0);
        expect(state.hints['Zeta']!.length, 1);
      },
    );
  });

  group('AppListState.search special chars', () {
    test('finds app when query omits punctuation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'org.fdroid', label: 'F-Droid'),
        const AppInfo(packageName: 'com.other', label: 'Other'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('fdr');
      expect(result.length, 1);
      expect(result.first.packageName, 'org.fdroid');
    });

    test('finds app when query includes punctuation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'org.fdroid', label: 'F-Droid'),
        const AppInfo(packageName: 'com.other', label: 'Other'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('f-d');
      expect(result.length, 1);
      expect(result.first.packageName, 'org.fdroid');
    });

    test('finds app with dots when query omits them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'c.c', label: 'C.C'),
        const AppInfo(packageName: 'd.d', label: 'D.D'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('cc');
      expect(result.length, 1);
      expect(result.first.packageName, 'c.c');
    });

    test('cleaned start ranks above display contain', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'A-A'),
        const AppInfo(packageName: 'a.b', label: 'baa'),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('aa');
      expect(result.length, 2);
      expect(result.first.packageName, 'a.a');
      expect(result.last.packageName, 'a.b');
    });
  });

  group('AppListState.search profile prefix', () {
    test('dot prefix finds only work apps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'Alpha', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'Alpha', isWorkApp: true),
        const AppInfo(packageName: 'a.c', label: 'Beta', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('.alpha');
      expect(result.length, 1);
      expect(result.first.packageName, 'a.b');
    });

    test('space prefix finds only personal apps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'Alpha', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'Alpha', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search(' alpha');
      expect(result.length, 1);
      expect(result.first.packageName, 'a.a');
    });

    test('dot prefix with search term filters work apps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'A', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'A', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('.a');
      expect(result.length, 1);
      expect(result.first.isWorkApp, true);
    });

    test('dot prefix alone shows all work apps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'Alpha', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'Alpha', isWorkApp: true),
        const AppInfo(packageName: 'a.c', label: 'Beta', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('.');
      expect(result.length, 2);
      expect(result.every((a) => a.isWorkApp), true);
    });

    test('space prefix alone shows all personal apps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'Alpha', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'Alpha', isWorkApp: true),
        const AppInfo(packageName: 'a.c', label: 'Beta', isWorkApp: false),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search(' ');
      expect(result.length, 2);
      expect(result.every((a) => !a.isWorkApp), true);
    });

    test('no prefix returns apps from both profiles', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channel = _FakeAppChannel([
        const AppInfo(packageName: 'a.a', label: 'Alpha', isWorkApp: false),
        const AppInfo(packageName: 'a.b', label: 'Alpha', isWorkApp: true),
      ]);
      final state = AppListState(channel, prefs);
      await state.loadApps();

      final result = state.search('alpha');
      expect(result.length, 2);
    });
  });
}
