import 'package:flutter/material.dart';
import 'package:last_launcher/features/app_drawer/app_list_state.dart';
import 'package:last_launcher/features/app_drawer/widgets/app_drawer_sheet.dart';
import 'package:last_launcher/features/home/home_state.dart';
import 'package:last_launcher/features/modules/launcher_module.dart';
import 'package:last_launcher/features/modules/none_module.dart';
import 'package:last_launcher/features/home/screens/home_screen.dart';
import 'package:last_launcher/features/settings/screens/settings_screen.dart';
import 'package:last_launcher/features/settings/settings_state.dart';
import 'package:last_launcher/features/modules/tasks/task_state.dart';
import 'package:last_launcher/shared/data/app_channel.dart';
import 'package:last_launcher/l10n/app_localizations.dart';

const _dragStartThreshold = 20.0;
const _swipeVelocityThreshold = 300.0;
const _pageAnimDuration = Duration(milliseconds: 100);

class LauncherShell extends StatefulWidget {
  const LauncherShell({
    required this.appChannel,
    required this.homeState,
    required this.appListState,
    required this.settingsState,
    required this.taskState,
    super.key,
  });

  final AppChannel appChannel;
  final HomeState homeState;
  final AppListState appListState;
  final SettingsState settingsState;
  final TaskState taskState;

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _homeKey = GlobalKey<HomeScreenState>();

  // Page (horizontal: -1 = left panel, 0 = home, 1 = app drawer).
  double _pageFraction = 0;
  bool get _onHomePage => _pageFraction.abs() < 0.5;
  late final AnimationController _pageAnim;
  double _pageAnimFrom = 0;
  double _pageAnimTo = 0;

  // Pointer tracking.
  int? _activePointer;
  Offset? _pointerStart;
  DateTime? _pointerStartTime;
  bool _isDraggingPage = false;
  double _dragStartFraction = 0;

  // Double-tap tracking (outside gesture arena, zero delay).
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  // Whether the app list is scrolled to the top.
  final _listIsAtTop = ValueNotifier<bool>(true);

  // Whether a reorder drag or list scroll is in progress.
  bool _isReorderingTasks = false;
  bool _isReorderingHome = false;

  late final VoidCallback _onOpenSettingsHandler;

  @override
  void initState() {
    super.initState();
    _onOpenSettingsHandler = _openSettings;
    WidgetsBinding.instance.addObserver(this);
    _pageAnim = AnimationController(vsync: this, duration: _pageAnimDuration)
      ..addListener(() {
        final t = Curves.easeOut.transform(_pageAnim.value);
        setState(() {
          _pageFraction = _pageAnimFrom + (_pageAnimTo - _pageAnimFrom) * t;
        });
      });
    widget.appChannel.onOpenSettings = _onOpenSettingsHandler;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await widget.appChannel.consumePendingOpenSettings()) {
        if (mounted) _openSettings();
      }
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => SettingsScreen(
          settingsState: widget.settingsState,
          appListState: widget.appListState,
          homeState: widget.homeState,
          appChannel: widget.appChannel,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _resetToHome();
    }
  }

  void _resetToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    });
    _pageAnim.stop();
    setState(() {
      _pageFraction = 0;
      _pageAnimTo = 0;
    });
    _isReorderingHome = false;
    _isReorderingTasks = false;
    widget.appListState.clearFilter();
    widget.settingsState.leftPanel.dismissActions();
  }

  @override
  void dispose() {
    if (widget.appChannel.onOpenSettings == _onOpenSettingsHandler) {
      widget.appChannel.onOpenSettings = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _pageAnim.dispose();
    _listIsAtTop.dispose();
    super.dispose();
  }

  // --- Page animation ---

  void _animatePageTo(double target) {
    _pageAnimFrom = _pageFraction;
    _pageAnimTo = target;
    _pageAnim.forward(from: 0);
  }

  void _launchApp(String packageName, {bool isWorkApp = false}) {
    widget.appChannel.launchApp(packageName, isWorkApp: isWorkApp);
    _closeDrawer();
  }

  void _openAppInfo(String packageName) {
    widget.appChannel.openAppInfo(packageName);
    _closeDrawer();
  }

  void _closeDrawer() {
    if (_pageFraction > 0.5) {
      _animatePageTo(0);
    }
    widget.appListState.clearFilter();
  }

  // --- Pointer handling ---

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _pageAnim.stop();
    _pointerStart = event.position;
    _pointerStartTime = DateTime.now();
    _isDraggingPage = false;

    // Double-tap detection (outside gesture arena, no tap delay).
    if (widget.settingsState.doubleTapToSleep &&
        _onHomePage &&
        !_isReorderingHome &&
        !_isReorderingTasks) {
      final now = DateTime.now();
      final samePosition =
          _lastTapPosition != null &&
          (event.position - _lastTapPosition!).distance < 40;
      if (_lastTapTime != null &&
          samePosition &&
          now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
        _lastTapTime = null;
        _lastTapPosition = null;
        _handleDoubleTap();
        return;
      }
      _lastTapTime = now;
      _lastTapPosition = event.position;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final start = _pointerStart;
    if (start == null) return;

    final dy = start.dy - event.position.dy; // positive = upward
    final dx = start.dx - event.position.dx; // positive = left
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (!_isDraggingPage) {
      if (absDx < _dragStartThreshold && absDy < _dragStartThreshold) return;

      if (absDx > absDy && !_isReorderingTasks && !_isReorderingHome) {
        // Horizontal drag — page navigation.
        final hasLeft = widget.settingsState.leftPanel is! NoneModule;
        final lowerBound = hasLeft ? -1.0 : 0.0;
        const upperBound = 1.0;
        if (dx > 0 && _pageFraction >= upperBound) return;
        if (dx < 0 && _pageFraction <= lowerBound) return;
        _isDraggingPage = true;
        _cancelDoubleTap();
        _dragStartFraction = _pageFraction;
      } else if (absDy > absDx) {
        // Vertical drag.
        if (!_onHomePage || _isReorderingHome) return;
        if (dy < 0) {
          // Downward drag — expand quick settings.
          widget.appChannel.expandQuickSettings();
          _cancelDoubleTap();
          _resetPointer();
          return;
        }
      } else {
        return;
      }
    }

    if (_isDraggingPage) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final threshold = dx >= 0 ? _dragStartThreshold : -_dragStartThreshold;
      final delta = (dx - threshold) / screenWidth;
      final hasLeft = widget.settingsState.leftPanel is! NoneModule;
      final fraction = (_dragStartFraction + delta).clamp(
        hasLeft ? -1.0 : 0.0,
        1.0,
      );
      setState(() => _pageFraction = fraction);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    final start = _pointerStart;
    final startTime = _pointerStartTime;
    _resetPointer();

    if (_isDraggingPage) {
      _isDraggingPage = false;
      final vx = _velocity(start?.dx, event.position.dx, startTime);
      final delta = _pageFraction - _dragStartFraction;
      final hasLeft = widget.settingsState.leftPanel is! NoneModule;
      final lower = hasLeft ? -1.0 : 0.0;
      const upper = 1.0;
      double target = _dragStartFraction;
      if (delta > 0.05 || vx > _swipeVelocityThreshold) {
        // Forward (toward right): snap to next slot.
        target = (_dragStartFraction + 1).clamp(lower, upper);
      } else if (delta < -0.05 || vx < -_swipeVelocityThreshold) {
        // Backward (toward left): snap to previous slot.
        target = (_dragStartFraction - 1).clamp(lower, upper);
      }
      _animatePageTo(target);
      return;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    if (_isDraggingPage) {
      _isDraggingPage = false;
      _animatePageTo(_dragStartFraction);
    }
    _cancelDoubleTap();
    _resetPointer();
  }

  /// Single-axis velocity in px/s (positive = start→end direction).
  double _velocity(double? startV, double endV, DateTime? startTime) {
    if (startV == null || startTime == null) return 0;
    final micros = DateTime.now().difference(startTime).inMicroseconds;
    if (micros < 1000) return 0;
    return (startV - endV) / (micros / 1000000);
  }

  void _resetPointer() {
    _activePointer = null;
    _pointerStart = null;
    _pointerStartTime = null;
  }

  void _cancelDoubleTap() {
    _lastTapTime = null;
    _lastTapPosition = null;
  }

  Future<void> _handleDoubleTap() async {
    final alreadyEnabled = await widget.appChannel
        .isAccessibilityServiceEnabled();
    if (alreadyEnabled) {
      await widget.appChannel.lockScreen();
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.doubleTapToSleepDialogTitle),
        content: Text(l10n.doubleTapToSleepDialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.renameDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionEnable),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appChannel.openAccessibilitySettings();
    }
  }

  Widget _buildPanel(
    LauncherModule panel, {
    required bool isVisible,
    required bool isLeftSide,
  }) {
    return panel.build(
      context,
      LauncherModuleProps(
        taskState: widget.taskState,
        settingsState: widget.settingsState,
        isVisible: isVisible,
        scrollLocked: _isDraggingPage,
        swipeRight: isLeftSide,
        onReorderStart: () => _isReorderingTasks = true,
        onReorderEnd: () => _isReorderingTasks = false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final pageOffset = -screenWidth * (1 + _pageFraction);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.settingsState.hideStatusBar) {
          widget.appChannel.setFullscreen(true);
        }
        if (widget.settingsState.leftPanel.dismissActions()) return;
        if (!_onHomePage) {
          _animatePageTo(0);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Pages: [Left, Home, Drawer] sliding horizontally.
              Positioned(
                left: pageOffset,
                top: 0,
                bottom: 0,
                width: screenWidth * 3,
                child: Row(
                  children: [
                    SizedBox(
                      width: screenWidth,
                      height: screenHeight,
                      child: _buildPanel(
                        widget.settingsState.leftPanel,
                        isVisible: _pageFraction < -0.5,
                        isLeftSide: true,
                      ),
                    ),
                    SizedBox(
                      width: screenWidth,
                      height: screenHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onLongPress: _openSettings,
                        child: HomeScreen(
                          key: _homeKey,
                          homeState: widget.homeState,
                          appListState: widget.appListState,
                          settingsState: widget.settingsState,
                          onLaunch: _launchApp,
                          onReorderStart: () => _isReorderingHome = true,
                          onReorderEnd: () => _isReorderingHome = false,
                          isActive: _onHomePage,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: screenWidth,
                      height: screenHeight,
                      child: AppDrawerSheet(
                        appListState: widget.appListState,
                        homeState: widget.homeState,
                        settingsState: widget.settingsState,
                        isOpen: _pageFraction > 0.5,
                        isAtTop: _listIsAtTop,
                        onLaunch: _launchApp,
                        onOpenAppInfo: _openAppInfo,
                        onCloseDrawer: _closeDrawer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
