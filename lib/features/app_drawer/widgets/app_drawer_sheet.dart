import 'package:flutter/material.dart';
import 'package:last_launcher/l10n/app_localizations.dart';
import 'package:last_launcher/features/app_drawer/app_list_state.dart';
import 'package:last_launcher/features/app_drawer/search.dart';
import 'package:last_launcher/shared/widgets/app_label.dart';
import 'package:last_launcher/shared/widgets/fade_overflow.dart';
import 'package:last_launcher/shared/widgets/action_row.dart';
import 'package:last_launcher/shared/widgets/rename_dialog.dart';
import 'package:last_launcher/shared/widgets/search_field.dart';
import 'package:last_launcher/features/home/home_state.dart';
import 'package:last_launcher/features/settings/settings_state.dart';
import 'package:last_launcher/shared/data/fold_for_search.dart';
import 'package:last_launcher/shared/data/hints.dart';
import 'package:last_launcher/shared/data/models.dart';

class _SortEntry {
  final AppInfo app;
  final String folded;
  final bool startsWith;
  final bool contains;
  final SubstringHint? hint;

  _SortEntry({
    required this.app,
    required this.folded,
    required this.startsWith,
    required this.contains,
    required this.hint,
  });
}

class AppDrawerSheet extends StatefulWidget {
  const AppDrawerSheet({
    required this.appListState,
    required this.homeState,
    required this.settingsState,
    required this.isOpen,
    required this.onLaunch,
    required this.onOpenAppInfo,
    required this.onCloseDrawer,
    required this.isAtTop,
    super.key,
  });

  final AppListState appListState;
  final HomeState homeState;
  final SettingsState settingsState;
  final bool isOpen;
  final void Function(String packageName, {bool isWorkApp}) onLaunch;
  final void Function(String packageName) onOpenAppInfo;
  final VoidCallback onCloseDrawer;
  final ValueNotifier<bool> isAtTop;

  @override
  State<AppDrawerSheet> createState() => _AppDrawerSheetState();
}

class _AppDrawerSheetState extends State<AppDrawerSheet>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  String? _activeAppKey;
  String? _activeFolderId;
  String? _expandedFolderId;
  String? _prevMatchKey;
  SubstringHint? _stableHint;
  String _appKey(AppInfo app) => '${app.packageName}|${app.isWorkApp}';

  late final Listenable _mergedState = Listenable.merge([
    widget.appListState,
    widget.settingsState,
    widget.homeState,
  ]);

  bool get _searchOnly => widget.settingsState.searchOnly;
  bool get _autoKeyboard => _searchOnly || widget.settingsState.autoKeyboard;
  bool get _autoLaunch => _searchOnly || widget.settingsState.autoLaunch;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    if (widget.isOpen) _handleOpened();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!widget.isOpen || !_autoKeyboard) return;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
    _focusNode.unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !widget.isOpen) return;
      _requestKeyboardReliably();
    });
  }

  @override
  void didUpdateWidget(AppDrawerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _handleOpened();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _focusNode.unfocus();
      _textController.clear();
      _activeAppKey = null;
      _activeFolderId = null;
      _expandedFolderId = null;
      _prevMatchKey = null;
      _stableHint = null;
    }
  }

  void _handleOpened() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    widget.isAtTop.value = true;
    _activeFolderId = null;
    _expandedFolderId = null;
    if (_autoKeyboard) {
      _requestKeyboardReliably();
    }
  }

  void _requestKeyboardReliably() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || !_focusNode.hasFocus) return;
        final insets = MediaQuery.viewInsetsOf(context);
        if (insets.bottom == 0) {
          _focusNode.unfocus();
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _focusNode.requestFocus();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _withWorkDot(Widget child, AppInfo app, double opacity, {Key? key}) {
    if (!app.isWorkApp || !widget.settingsState.showWorkAppDot) {
      return KeyedSubtree(key: key, child: child);
    }
    final dotColor = Theme.of(
      context,
    ).textTheme.titleLarge?.color?.withAlpha((0.6 * 255).round());
    return Stack(
      key: key,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -5,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Icon(Icons.circle, size: 10, color: dotColor),
            ),
          ),
        ),
      ],
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_activeAppKey != null) setState(() => _activeAppKey = null);
    widget.isAtTop.value = _scrollController.offset <= 0;
    if (_scrollController.offset > 20 && _focusNode.hasFocus) {
      _focusNode.unfocus();
    } else if (_scrollController.offset <= 0 &&
        !_focusNode.hasFocus &&
        _autoKeyboard) {
      _focusNode.requestFocus();
    }
  }

  void _onOverscroll(OverscrollNotification notification) {
    if (notification.overscroll > 0 && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  List<AppInfo> get _visibleApps {
    final query = widget.appListState.query;
    final searching = query.isNotEmpty;
    final expandSearch =
        searching && widget.settingsState.includeHiddenInSearch;
    final base = widget.appListState.search(
      query,
      includeHidden: expandSearch,
      matchOriginal: widget.settingsState.matchOriginalName,
    );
    if (expandSearch || !widget.settingsState.hidePinnedFromDrawer) {
      return base;
    }
    return base
        .where(
          (a) =>
              !widget.homeState.isPinned(a.packageName, isWorkApp: a.isWorkApp),
        )
        .toList();
  }

  SubstringHint? _queryMatchHint(AppInfo app, String query) {
    final searchTerm = SearchQuery.parse(
      query,
      allowProfileFilter: widget.appListState.profilePrefixEnabled,
    ).searchTerm;
    if (searchTerm.isEmpty) return null;
    final foldedTerm = foldForSearch(searchTerm);
    final label = widget.appListState.displayLabelForSearch(app, query);
    final foldedLabel = foldForSearch(label);
    final start =
        (!foldedLabel.startsWith(foldedTerm) &&
            foldedLabel.contains(foldedTerm))
        ? foldedLabel.indexOf(foldedTerm)
        : 0;
    return SubstringHint(start: start, length: foldedTerm.length);
  }

  void _onSearchChanged(String query) {
    widget.appListState.filter(query);
    final visible = _visibleApps;
    if (_autoLaunch && query.isNotEmpty && visible.length == 1) {
      if (!widget.settingsState.extraChar) {
        widget.onLaunch(
          visible.first.packageName,
          isWorkApp: visible.first.isWorkApp,
        );
      } else if (_prevMatchKey == _appKey(visible.first)) {
        widget.onLaunch(
          visible.first.packageName,
          isWorkApp: visible.first.isWorkApp,
        );
      } else {
        _prevMatchKey = _appKey(visible.first);
        _stableHint = _queryMatchHint(visible.first, query);
      }
    } else {
      _prevMatchKey = null;
      _stableHint = null;
    }
  }

  void _onSubmit() {
    if (widget.appListState.query.isEmpty) return;
    final visible = _visibleApps;
    if (visible.isNotEmpty) {
      final query = widget.appListState.query;
      final searchTerm = SearchQuery.parse(
        query,
        allowProfileFilter: widget.appListState.profilePrefixEnabled,
      ).searchTerm;
      final sortByHint =
          searchTerm.isNotEmpty && widget.settingsState.quickLaunchHints;
      final sorted = _sortedApps(
        visible,
        query,
        searchTerm,
        widget.appListState.hints,
        sortByHint,
      );
      widget.onLaunch(
        sorted.first.packageName,
        isWorkApp: sorted.first.isWorkApp,
      );
    } else {
      widget.onCloseDrawer();
    }
  }

  List<ActionItem> _appActions(BuildContext context, AppInfo app) {
    final l10n = AppLocalizations.of(context)!;
    final isPinned = widget.homeState.isPinned(
      app.packageName,
      isWorkApp: app.isWorkApp,
    );
    final isHidden = widget.appListState.isHidden(
      app.packageName,
      isWorkApp: app.isWorkApp,
    );
    return [
      ActionItem(
        icon: Icons.edit,
        label: l10n.actionRename,
        onTap: () async {
          final newLabel = await showRenameDialog(
            context: context,
            currentLabel: widget.appListState.displayLabel(app),
            originalLabel: app.label,
          );
          if (newLabel != null) {
            widget.appListState.setCustomLabel(
              app.packageName,
              newLabel,
              isWorkApp: app.isWorkApp,
            );
          }
        },
      ),
      if (!isPinned && !widget.settingsState.locked)
        ActionItem(
          icon: Icons.add_circle_outline,
          label: widget.homeState.isFull ? l10n.actionPinFull : l10n.actionPin,
          onTap: widget.homeState.isFull
              ? () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.homeScreenFull)));
                }
              : () {
                  widget.homeState.addApp(
                    PinnedApp(
                      packageName: app.packageName,
                      label: app.label,
                      isWorkApp: app.isWorkApp,
                    ),
                  );
                  widget.onCloseDrawer();
                },
        ),
      if (!isHidden)
        ActionItem(
          icon: Icons.visibility_off,
          label: l10n.actionHide,
          onTap: () => widget.appListState.hideApp(
            app.packageName,
            isWorkApp: app.isWorkApp,
          ),
        ),
      ActionItem(
        icon: Icons.info_outline,
        label: l10n.actionAppInfo,
        onTap: () => widget.onOpenAppInfo(app.packageName),
      ),
      if (_expandedFolderId == null)
        ActionItem(
          icon: Icons.create_new_folder_outlined,
          label: l10n.actionAddToFolder,
          onTap: () => _showAddToFolderDialog(app),
        ),
      if (_expandedFolderId != null)
        ActionItem(
          icon: Icons.folder_delete_outlined,
          label: l10n.actionRemoveFromFolder,
          onTap: () => widget.appListState.removeAppFromFolder(
            _expandedFolderId!,
            app.packageName,
            app.isWorkApp,
          ),
        ),
    ];
  }

  List<ActionItem> _folderActions(BuildContext context, AppFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    return [
      ActionItem(
        icon: Icons.edit,
        label: l10n.actionRename,
        onTap: () => _renameFolder(folder),
      ),
      ActionItem(
        icon: Icons.add_circle_outline,
        label: l10n.actionAddToFolder,
        onTap: () => _showAddAppToFolderDialog(folder),
      ),
      ActionItem(
        icon: Icons.delete_outline,
        label: l10n.actionDeleteFolder,
        onTap: () => widget.appListState.deleteFolder(folder.id),
      ),
    ];
  }

  Future<void> _showAddToFolderDialog(AppInfo app) async {
    final folders = widget.appListState.folders;
    final l10n = AppLocalizations.of(context)!;

    final folder = await showDialog<AppFolder>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.actionAddToFolder),
        children: [
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f),
              child: Text(f.name),
            ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              final name = await showRenameDialog(
                context: context,
                currentLabel: '',
                originalLabel: '',
                title: l10n.actionCreateFolder,
              );
              if (name != null && name.isNotEmpty) {
                await widget.appListState.createFolder(name);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.add, size: 20),
                const SizedBox(width: 12),
                Text(l10n.actionCreateFolder),
              ],
            ),
          ),
        ],
      ),
    );

    if (folder != null) {
      await widget.appListState.addAppToFolder(folder.id, app);
    }
  }

  Future<void> _showAddAppToFolderDialog(AppFolder folder) async {
    final l10n = AppLocalizations.of(context)!;
    final apps = widget.appListState.allApps.where((a) => !widget.appListState.isHidden(a.packageName, isWorkApp: a.isWorkApp)).toList();
    final inFolders = {
      for (final f in widget.appListState.folders)
        for (final a in f.apps) '${a.packageName}|${a.isWorkApp}'
    };
    final available = apps.where((a) => !inFolders.contains('${a.packageName}|${a.isWorkApp}')).toList();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectAppsTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, index) {
                final app = available[index];
                return ListTile(
                  title: Text(widget.appListState.displayLabel(app)),
                  onTap: () {
                    widget.appListState.addAppToFolder(folder.id, app);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameFolder(AppFolder folder) async {
    final l10n = AppLocalizations.of(context)!;
    final newName = await showRenameDialog(
      context: context,
      currentLabel: folder.name,
      originalLabel: folder.name,
      title: l10n.renameFolderDialogTitle,
    );
    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      await widget.appListState.renameFolder(folder.id, newName);
    }
  }

  List<AppInfo> _sortedApps(
    List<AppInfo> apps,
    String query,
    String searchTerm,
    Map<String, SubstringHint?> hints,
    bool sortByHint,
  ) {
    if (apps.isEmpty) return apps;
    final needle = searchTerm.isNotEmpty ? foldForSearch(searchTerm) : '';
    final entries = apps.map((app) {
      final label = widget.appListState.displayLabelForSearch(app, query);
      final folded = foldForSearch(label);
      bool startsWith = false;
      bool contains = false;
      if (searchTerm.isNotEmpty) {
        startsWith = folded.startsWith(needle);
        contains = !startsWith && folded.contains(needle);
      }
      return _SortEntry(
        app: app,
        folded: folded,
        startsWith: startsWith,
        contains: contains,
        hint: hints[_appKey(app)],
      );
    }).toList();

    entries.sort((a, b) {
      if (sortByHint) {
        if (a.hint == null && b.hint != null) return 1;
        if (a.hint != null && b.hint == null) return -1;
        if (a.hint != null && a.hint!.length != b.hint!.length) {
          return a.hint!.length.compareTo(b.hint!.length);
        }
      }
      if (searchTerm.isNotEmpty) {
        if (a.startsWith != b.startsWith) return a.startsWith ? -1 : 1;
        if (!sortByHint) {
          if (a.contains != b.contains) return a.contains ? -1 : 1;
        }
      }
      return a.folded.compareTo(b.folded);
    });

    return entries.map((e) => e.app).toList();
  }

  SubstringHint? _displayHint({
    required AppInfo app,
    required String searchLabel,
    required SubstringHint? hint,
  }) {
    if (_stableHint != null &&
        _prevMatchKey == _appKey(app) &&
        widget.settingsState.extraChar) {
      return SubstringHint(
        start: _stableHint!.start,
        length:
            (_stableHint!.start + _stableHint!.length + 1).clamp(
              0,
              searchLabel.length,
            ) -
            _stableHint!.start,
      );
    }
    if (hint != null && widget.settingsState.extraChar) {
      return SubstringHint(
        start: hint.start,
        length:
            (hint.start + hint.length + 1).clamp(0, searchLabel.length) -
            hint.start,
      );
    }
    return hint;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Material(
        color: colorScheme.surface,
        child: ListenableBuilder(
          listenable: _mergedState,
          builder: (context, _) {
            final query = widget.appListState.query;
            final apps = _visibleApps;
            final searchTerm = SearchQuery.parse(
              query,
              allowProfileFilter: widget.appListState.profilePrefixEnabled,
            ).searchTerm;
            final sortByHint = query.isNotEmpty &&
                searchTerm.isNotEmpty &&
                widget.settingsState.quickLaunchHints;
            final sorted = _sortedApps(
              apps,
              query,
              searchTerm,
              widget.appListState.hints,
              sortByHint,
            );

            final folders = query.isEmpty ? widget.appListState.folders : <AppFolder>[];

            return NotificationListener<OverscrollNotification>(
              onNotification: (notification) {
                _onOverscroll(notification);
                return false;
              },
              child: FadeOverflow(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).top + 8,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AppSearchField(
                        controller: _textController,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        onSubmit: _onSubmit,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    if (_searchOnly)
                      SliverFillRemaining(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragEnd: (details) {
                            if (details.velocity.pixelsPerSecond.dy > 100) {
                              widget.onCloseDrawer();
                            }
                          },
                        ),
                      )
                    else if (sorted.isEmpty && folders.isEmpty && query.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            top: 8 + AppLabel.verticalPadding,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.noResults,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: widget.settingsState.fontSizeShell,
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(130),
                                ),
                          ),
                        ),
                      )
                    else if (query.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final app = sorted[index];
                            final itemKey = 'search|${app.packageName}|${app.isWorkApp}';
                            return _buildAppItem(context, app, query, key: ValueKey(itemKey));
                          },
                          childCount: sorted.length,
                        ),
                      )
                    else
                      _buildDraggableList(apps, folders, query),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDraggableList(List<AppInfo> apps, List<AppFolder> folders, String query) {
    final items = widget.appListState.getOrderedTopLevel(apps);
    final flattened = <dynamic>[];
    for (final item in items) {
      flattened.add(item);
      if (item is AppFolder && _expandedFolderId == item.id) {
        final folderApps = item.apps
            .map((p) => AppInfo(packageName: p.packageName, label: p.label, isWorkApp: p.isWorkApp))
            .toList();
        folderApps.sort((a, b) => widget.appListState
            .displayLabel(a)
            .toLowerCase()
            .compareTo(widget.appListState.displayLabel(b).toLowerCase()));
        flattened.addAll(folderApps);
      }
    }

    return SliverReorderableList(
      itemCount: flattened.length,
      itemBuilder: (context, index) {
        final item = flattened[index];
        if (item is AppFolder) {
          return _buildFolderItem(context, item, index);
        }
        final app = item as AppInfo;
        final isIndented = _expandedFolderId != null &&
            folders.any((f) =>
                f.id == _expandedFolderId &&
                f.apps.any((a) => a.packageName == app.packageName && a.isWorkApp == app.isWorkApp));

        final itemKey = isIndented ? 'folder|$_expandedFolderId|${app.packageName}|${app.isWorkApp}' : 'top|${app.packageName}|${app.isWorkApp}';
        return _buildAppItem(context, app, query, index: index, indented: isIndented, key: ValueKey(itemKey));
      },
      onReorderItem: (oldIndex, newIndex) {
        if (_expandedFolderId != null) return;
        widget.appListState.reorderTopLevel(oldIndex, newIndex);
      },
      proxyDecorator: dragProxyDecorator,
    );
  }

  Widget _buildFolderItem(BuildContext context, AppFolder folder, int index) {
    Widget content;
    if (_activeFolderId == folder.id) {
      content = ActionRow(
        key: ValueKey('active|${folder.id}'),
        label: folder.name,
        actions: _folderActions(context, folder),
        onClose: () => setState(() => _activeFolderId = null),
        fontSize: widget.settingsState.fontSizeShell,
        leading: dragHandle(context, index),
      );
    } else {
      content = AppLabel(
        key: ValueKey('inactive|${folder.id}'),
        label: folder.name,
        onTap: () => setState(() {
          _expandedFolderId = _expandedFolderId == folder.id ? null : folder.id;
        }),
        onLongPress: () => setState(() => _activeFolderId = folder.id),
        fontSize: widget.settingsState.fontSizeShell,
        leading: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Icon(
              _expandedFolderId == folder.id ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 22,
            ),
          ),
        ),
      );
    }

    return DragTarget<AppInfo>(
      key: ValueKey('target|${folder.id}'),
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => widget.appListState.addAppToFolder(folder.id, details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          key: ValueKey('container|${folder.id}'),
          color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withAlpha(30) : null,
          child: content,
        );
      },
    );
  }

  Widget _buildAppItem(BuildContext context, AppInfo app, String query, {int? index, bool indented = false, Key? key}) {
    final dimmed = widget.appListState.isHidden(
          app.packageName,
          isWorkApp: app.isWorkApp,
        ) ||
        (widget.settingsState.hidePinnedFromDrawer &&
            widget.homeState.isPinned(
              app.packageName,
              isWorkApp: app.isWorkApp,
            ));
    final showHint = widget.settingsState.quickLaunchHints;
    final searchLabel = widget.appListState.displayLabelForSearch(app, query);
    final hint = showHint ? widget.appListState.hints[_appKey(app)] : null;
    final displayHint = _displayHint(
      app: app,
      searchLabel: searchLabel,
      hint: hint,
    );
    final opacity = showHint && (dimmed || hint == null) ? 0.6 : 1.0;
    final keyString = _appKey(app);

    Widget item;
    if (_activeAppKey == keyString) {
      item = _withWorkDot(
        ActionRow(
          key: ValueKey('row|$keyString'),
          label: searchLabel,
          actions: _appActions(context, app),
          onClose: () => setState(() => _activeAppKey = null),
          opacity: opacity,
          fontSize: widget.settingsState.fontSizeShell,
          leading: index != null ? dragHandle(context, index) : null,
        ),
        app,
        opacity,
        key: ValueKey('dot|$keyString'),
      );

      item = Draggable<AppInfo>(
        key: ValueKey('drag|$keyString'),
        data: app,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.8,
            child: AppLabel(label: searchLabel, fontSize: widget.settingsState.fontSizeShell),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: item),
        child: item,
      );
    } else {
      item = _withWorkDot(
        AppLabel(
          key: ValueKey('label|$keyString'),
          label: searchLabel,
          hint: displayHint,
          hintAlphaOnly: !RegExp(r'[^a-zA-Z]').hasMatch(query),
          onTap: () => widget.onLaunch(
            app.packageName,
            isWorkApp: app.isWorkApp,
          ),
          onLongPress: () => setState(() => _activeAppKey = keyString),
          opacity: opacity,
          fontSize: widget.settingsState.fontSizeShell,
        ),
        app,
        opacity,
        key: ValueKey('dot|$keyString'),
      );
    }

    if (indented) {
      return Padding(
        key: key,
        padding: const EdgeInsets.only(left: 32.0),
        child: item,
      );
    }
    return KeyedSubtree(key: key, child: item);
  }
}
