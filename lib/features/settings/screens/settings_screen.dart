import 'package:flutter/material.dart';
import 'package:last_launcher/features/app_drawer/app_list_state.dart';
import 'package:last_launcher/features/home/home_state.dart';
//import 'package:last_launcher/features/settings/screens/about_screen.dart';
//import 'package:last_launcher/features/settings/screens/hidden_apps_screen.dart';
import 'package:last_launcher/features/settings/screens/task_settings_screen.dart';
import 'package:last_launcher/features/settings/settings_state.dart';
import 'package:last_launcher/l10n/app_localizations.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
//import 'package:last_launcher/shared/widgets/app_label.dart';
import 'package:last_launcher/shared/widgets/fade_overflow.dart';

//import 'package:package_info_plus/package_info_plus.dart';
//import 'package:url_launcher/url_launcher.dart';

//const _store = String.fromEnvironment('STORE', defaultValue: 'playstore');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settingsState,
    required this.appListState,
    required this.homeState,
    required this.appChannel,
    super.key,
  });

  final SettingsState settingsState;
  final AppListState appListState;
  final HomeState homeState;
  final AppChannel appChannel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isDefaultLauncher = true;
  //double _fontSize = AppLabel.defaultFontSize; //38.0; // Initial font size

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDefault();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDefault();
  }

  Future<void> _refreshDefault() async {
    final value = await widget.appChannel.isDefaultLauncher();
    if (mounted) setState(() => _isDefaultLauncher = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = widget.settingsState;
    //final appListState = widget.appListState;
    //final homeState = widget.homeState;
    final appChannel = widget.appChannel;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: settingsState,
        builder: (context, _) {
          return FadeOverflow(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SectionHeader(title: l10n.sectionAppearance),

                // Slider(
                //   value: _fontSize,
                //   min: 12.0,
                //   max: 48.0,
                //   divisions: 100,
                //   label: _fontSize.round().toString(),
                //   onChanged: (double value) {
                //     setState(() {
                //       _fontSize = value; // Update state to rebuild UI
                //     });
                //   },
                // ),
                _ThemeListTile(
                  themeValue: settingsState.themeValue,
                  onChanged: settingsState.setTheme,
                ),
                _FontFamilyListTile(
                  fontFamily: settingsState.fontFamily,
                  onChanged: settingsState.setFontFamily,
                ),
                _HomeAlignmentListTile(
                  alignment: settingsState.homeAlignment,
                  onChanged: settingsState.setHomeAlignment,
                ),
                if (settingsState.tasksEnabled) ...[
                  _SectionHeader(title: l10n.sectionModules),
                  ListTile(
                    title: Text(l10n.sectionTasks),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (_, _, _) =>
                              TaskSettingsScreen(settingsState: settingsState),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                  ),
                ],
                _FontSizeListTile(
                  title: l10n.fontSizeHome,
                  subtitle: l10n.fontSizeHomeSubtitle,
                  value: settingsState.fontSizeHome,
                  onChanged: settingsState.setFontSizeHome,
                ),
                _FontSizeListTile(
                  title: l10n.fontSizeShell,
                  subtitle: l10n.fontSizeShellSubtitle,
                  value: settingsState.fontSizeShell,
                  onChanged: settingsState.setFontSizeShell,
                ),
                //_SectionHeader(title: l10n.sectionHome),
                if (!_isDefaultLauncher)
                  ListTile(
                    title: Text(l10n.setAsDefault),
                    subtitle: Text(l10n.setAsDefaultSubtitle),
                    onTap: appChannel.requestDefaultLauncher,
                  ),
                SwitchListTile(
                  title: Text(l10n.hideStatusBar),
                  subtitle: Text(l10n.hideStatusBarSubtitle),
                  value: settingsState.hideStatusBar,
                  onChanged: settingsState.setHideStatusBar,
                ),
                // SwitchListTile(
                //   title: Text(l10n.showHints),
                //   subtitle: Text(l10n.showHintsSubtitle),
                //   value: settingsState.showHints,
                //   onChanged: settingsState.setShowHints,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.lockLayout),
                //   subtitle: Text(l10n.lockLayoutSubtitle),
                //   value: settingsState.locked,
                //   onChanged: settingsState.setLocked,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.doubleTapToSleep),
                //   subtitle: Text(l10n.doubleTapToSleepSubtitle),
                //   value: settingsState.doubleTapToSleep,
                //   onChanged: settingsState.setDoubleTapToSleep,
                // ),
                // _PanelListTile(
                //   title: l10n.leftOfHome,
                //   current: settingsState.leftPanel,
                //   onChanged: settingsState.setLeftPanel,
                // ),
                // _SectionHeader(title: l10n.sectionAppDrawer),
                // ListenableBuilder(
                //   listenable: Listenable.merge([appListState, homeState]),
                //   builder: (context, _) {
                //     String compoundKey(String pkg, bool isWork) =>
                //         '$pkg|$isWork';
                //     final hiddenPackages = <String>{
                //       ...appListState.hiddenApps.map(
                //         (a) => compoundKey(a.packageName, a.isWorkApp),
                //       ),
                //       if (settingsState.hidePinnedFromDrawer)
                //         ...homeState.pinnedApps.map(
                //           (a) => compoundKey(a.packageName, a.isWorkApp),
                //         ),
                //     };
                //     final hasWorkApps = appListState.workPackages.isNotEmpty;
                //     final hidePersonal =
                //         settingsState.hidePersonalWhenWorkActive && hasWorkApps;
                //     final count = hidePersonal
                //         ? hiddenPackages
                //               .where((k) => k.endsWith('|true'))
                //               .length
                //         : hasWorkApps
                //         ? hiddenPackages.length
                //         : hiddenPackages
                //               .where((k) => !k.endsWith('|true'))
                //               .length;
                //     return Column(
                //       mainAxisSize: MainAxisSize.min,
                //       children: [
                //         ListTile(
                //           leading: const Icon(Icons.visibility_off_outlined),
                //           title: Text(l10n.hiddenApps),
                //           subtitle: Text(
                //             count == 0
                //                 ? l10n.hiddenAppsNone
                //                 : l10n.hiddenAppsCount(count),
                //           ),
                //           onTap: () {
                //             Navigator.of(context).push(
                //               PageRouteBuilder<void>(
                //                 pageBuilder: (_, _, _) => HiddenAppsScreen(
                //                   appListState: appListState,
                //                   homeState: homeState,
                //                   settingsState: settingsState,
                //                   onLaunch: appChannel.launchApp,
                //                   onOpenAppInfo: appChannel.openAppInfo,
                //                 ),
                //                 transitionDuration: Duration.zero,
                //                 reverseTransitionDuration: Duration.zero,
                //               ),
                //             );
                //           },
                //         ),
                //         SwitchListTile(
                //           title: Text(l10n.hidePinnedApps),
                //           subtitle: Text(l10n.hidePinnedAppsSubtitle),
                //           value: settingsState.hidePinnedFromDrawer,
                //           onChanged: settingsState.setHidePinnedFromDrawer,
                //         ),
                //       ],
                //     );
                //   },
                // ),
                // _SectionHeader(title: l10n.sectionSearch),
                // SwitchListTile(
                //   title: Text(l10n.includeHiddenInSearch),
                //   subtitle: Text(l10n.includeHiddenInSearchSubtitle),
                //   value: settingsState.includeHiddenInSearch,
                //   onChanged: (value) {
                //     settingsState.setIncludeHiddenInSearch(value);
                //     appListState.applyPrefs(settingsState.searchPrefs);
                //   },
                // ),
                // SwitchListTile(
                //   title: Text(l10n.matchOriginalName),
                //   subtitle: Text(l10n.matchOriginalNameSubtitle),
                //   value: settingsState.matchOriginalName,
                //   onChanged: (value) {
                //     settingsState.setMatchOriginalName(value);
                //     appListState.applyPrefs(settingsState.searchPrefs);
                //   },
                // ),
                // SwitchListTile(
                //   title: Text(l10n.searchOnlyMode),
                //   subtitle: Text(l10n.searchOnlyModeSubtitle),
                //   value: searchOnly,
                //   onChanged: settingsState.setSearchOnly,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.autoShowKeyboard),
                //   subtitle: Text(l10n.autoShowKeyboardAppsSubtitle),
                //   value: searchOnly || settingsState.autoKeyboard,
                //   onChanged: searchOnly ? null : settingsState.setAutoKeyboard,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.autoLaunchOnMatch),
                //   subtitle: Text(l10n.autoLaunchOnMatchSubtitle),
                //   value: searchOnly || settingsState.autoLaunch,
                //   onChanged: searchOnly ? null : settingsState.setAutoLaunch,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.extraChar),
                //   subtitle: Text(l10n.extraCharSubtitle),
                //   value:
                //       !searchOnly &&
                //       settingsState.autoLaunch &&
                //       settingsState.extraChar,
                //   onChanged: searchOnly || !settingsState.autoLaunch
                //       ? null
                //       : settingsState.setExtraChar,
                // ),
                // SwitchListTile(
                //   title: Text(l10n.quickLaunchHints),
                //   subtitle: Text(l10n.quickLaunchHintsSubtitle),
                //   value:
                //       !searchOnly &&
                //       settingsState.autoLaunch &&
                //       settingsState.quickLaunchHints,
                //   onChanged: searchOnly || !settingsState.autoLaunch
                //       ? null
                //       : settingsState.setQuickLaunchHints,
                // ),
                // if (appListState.hasWorkProfile) ...[
                //   _SectionHeader(title: l10n.sectionWork),
                //   SwitchListTile(
                //     title: Text(l10n.hidePersonalWhenWorkActive),
                //     subtitle: Text(l10n.hidePersonalWhenWorkActiveSubtitle),
                //     value: settingsState.hidePersonalWhenWorkActive,
                //     onChanged: (value) {
                //       settingsState.setHidePersonalWhenWorkActive(value);
                //       appListState.applyPrefs(settingsState.searchPrefs);
                //     },
                //   ),
                //   SwitchListTile(
                //     title: Text(l10n.showWorkAppDot),
                //     subtitle: Text(l10n.showWorkAppDotSubtitle),
                //     value: settingsState.showWorkAppDot,
                //     onChanged: settingsState.hidePersonalWhenWorkActive
                //         ? null
                //         : settingsState.setShowWorkAppDot,
                //   ),
                //   SwitchListTile(
                //     title: Text(l10n.showWorkAppDotOnHome),
                //     subtitle: Text(l10n.showWorkAppDotOnHomeSubtitle),
                //     value: settingsState.showWorkAppDotOnHome,
                //     onChanged:
                //         settingsState.hidePersonalWhenWorkActive ||
                //             !settingsState.showWorkAppDot
                //         ? null
                //         : settingsState.setShowWorkAppDotOnHome,
                //   ),
                // ],
                // _SectionHeader(title: l10n.sectionSupport),
                // if (_store == 'playstore')
                //   ListTile(
                //     leading: const Icon(Icons.star_outline),
                //     title: Text(l10n.rateApp),
                //     subtitle: Text(l10n.rateAppSubtitle),
                //     onTap: () => launchUrl(
                //       Uri.parse(
                //         'https://play.google.com/store/apps/details?id=nl.bw20.last_launcher',
                //       ),
                //       mode: LaunchMode.externalApplication,
                //     ),
                //   ),
                // if (_store == 'fdroid')
                //   ListTile(
                //     leading: const Icon(Icons.favorite_outline),
                //     title: Text(l10n.donate),
                //     subtitle: Text(l10n.donateSubtitle),
                //     onTap: () => launchUrl(
                //       Uri.parse('https://liberapay.com/BW20'),
                //       mode: LaunchMode.externalApplication,
                //     ),
                //   ),
                // ListTile(
                //   leading: const Icon(Icons.mail_outline),
                //   title: Text(l10n.sendFeedback),
                //   subtitle: Text(l10n.sendFeedbackSubtitle),
                //   onTap: _launchFeedback,
                // ),
                // ListTile(
                //   leading: const Icon(Icons.help_outline),
                //   title: Text(l10n.help),
                //   subtitle: Text(l10n.helpSubtitle),
                //   onTap: () => launchUrl(
                //     Uri.parse('https://codeberg.org/BW20/last-launcher'),
                //     mode: LaunchMode.externalApplication,
                //   ),
                // ),
                // _SectionHeader(title: l10n.sectionAbout),
                // ListTile(
                //   leading: const Icon(Icons.info_outline),
                //   title: Text(l10n.sectionAbout),
                //   subtitle: Text(l10n.aboutSubtitle),
                //   onTap: () {
                //     Navigator.of(context).push(
                //       PageRouteBuilder<void>(
                //         pageBuilder: (_, _, _) => const AboutScreen(),
                //         transitionDuration: Duration.zero,
                //         reverseTransitionDuration: Duration.zero,
                //       ),
                //     );
                //   },
                // ),
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // Future<void> _launchFeedback() async {
  //   final info = await PackageInfo.fromPlatform();
  //   final subject = Uri.encodeComponent(
  //     'Last Launcher feedback (v${info.version})',
  //   );
  //   await launchUrl(
  //     Uri.parse('mailto:jorrit@bw20.nl?subject=$subject'),
  //     mode: LaunchMode.externalApplication,
  //   );
  // }
}

class _ThemeListTile extends StatelessWidget {
  const _ThemeListTile({required this.themeValue, required this.onChanged});

  final String themeValue;
  final ValueChanged<String> onChanged;

  static const _options = ['system', 'light', 'dark'];

  static String _label(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      'system' => l10n.themeSystem,
      'light' => l10n.themeLight,
      'dark' => l10n.themeDark,
      _ => l10n.themeSystem,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(AppLocalizations.of(context)!.themeTitle),
      subtitle: Text(_label(context, themeValue)),
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(AppLocalizations.of(context)!.themeTitle),
            children: [
              RadioGroup<String>(
                groupValue: themeValue,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _options)
                      RadioListTile<String>(
                        value: option,
                        title: Text(_label(context, option)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}

class _HomeAlignmentListTile extends StatelessWidget {
  const _HomeAlignmentListTile({
    required this.alignment,
    required this.onChanged,
  });

  final TextAlign alignment;
  final ValueChanged<TextAlign> onChanged;

  static const _options = [TextAlign.left, TextAlign.center, TextAlign.right];

  static String _label(BuildContext context, TextAlign value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      TextAlign.left => l10n.alignmentLeft,
      TextAlign.right => l10n.alignmentRight,
      _ => l10n.alignmentCenter,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.format_align_center_outlined),
      title: Text(AppLocalizations.of(context)!.homeAlignmentTitle),
      subtitle: Text(_label(context, alignment)),
      onTap: () async {
        final result = await showDialog<TextAlign>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(AppLocalizations.of(context)!.homeAlignmentTitle),
            children: [
              RadioGroup<TextAlign>(
                groupValue: alignment,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _options)
                      RadioListTile<TextAlign>(
                        value: option,
                        title: Text(_label(context, option)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}

class _FontFamilyListTile extends StatelessWidget {
  const _FontFamilyListTile({
    required this.fontFamily,
    required this.onChanged,
  });

  final String? fontFamily;
  final ValueChanged<String?> onChanged;

  static const _options = [
    'RobotoMonoMedium',
    'RobotoMonoLight',
    'RobotoMonoThin',
    'JetBrainsMono',
    'Raleway-Thin',
    'Laconic',
    'Outfit',
  ];

  static String _label(BuildContext context, String? value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      'RobotoMonoMedium' => l10n.fontRobotoMonoMedium,
      'RobotoMonoLight' => l10n.fontRobotoMonoLight,
      'RobotoMonoThin' => l10n.fontRobotoMonoThin,
      'JetBrainsMono' => l10n.fontFamilyMono,
      'Raleway-Thin' => l10n.fontFamilyRaleway,
      'Laconic' => l10n.fontFamilyLaconic,
      'Outfit' => l10n.fontFamilyOutfit,
      _ => l10n.fontRobotoMonoMedium,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.font_download_outlined),
      title: Text(AppLocalizations.of(context)!.fontFamilyTitle),
      subtitle: Text(_label(context, fontFamily)),
      onTap: () async {
        final result = await showDialog<String?>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(AppLocalizations.of(context)!.fontFamilyTitle),
            children: [
              RadioGroup<String?>(
                groupValue: fontFamily,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _options)
                      RadioListTile<String?>(
                        value: option,
                        title: Text(_label(context, option)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        onChanged(result);
      },
    );
  }
}

class _FontSizeListTile extends StatelessWidget {
  const _FontSizeListTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(title: Text(title), subtitle: Text(subtitle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Slider(
            value: value,
            min: 20,
            max: 60,
            divisions: 40,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
