import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';

/// Navigation state shared by the shell and its read-only detail routes.
///
/// The controller belongs to the app rather than a feature page. Starting or
/// ending an authenticated session replaces the root navigator, so routes and
/// visited tab state cannot carry over to another account.
class WorkspaceNavigationController extends ChangeNotifier {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  _WorkspaceRouteObserver _observer = _WorkspaceRouteObserver();
  Object? _sessionIdentity;
  int _sessionGeneration = 0;
  int _selectedIndex = 0;
  bool _changingDestination = false;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  NavigatorObserver get observer => _observer;
  int get selectedIndex => _selectedIndex;
  int get sessionGeneration => _sessionGeneration;
  bool get isAuthenticated => _sessionIdentity != null;

  void updateSession(Object? identity) {
    if (identity == _sessionIdentity) return;
    _sessionIdentity = identity;
    _sessionGeneration++;
    _selectedIndex = 0;
    _changingDestination = false;
    _navigatorKey = GlobalKey<NavigatorState>();
    _observer = _WorkspaceRouteObserver();
    notifyListeners();
  }

  /// Selects a tab from the root shell, where there are no detail routes to pop.
  void selectRootTab(int index) {
    RangeError.checkValidIndex(index, _destinations);
    if (!isAuthenticated || _selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  /// Returns to the shell before changing tabs, respecting every route guard.
  ///
  /// [Navigator.popUntil] deliberately is not used: it skips the unsaved-change
  /// checks made by PopScope. If an editor opens a discard dialog or rejects a
  /// pop, navigation stops and the requested destination stays unchanged.
  Future<bool> selectTab(int index) async {
    RangeError.checkValidIndex(index, _destinations);
    final navigator = _navigatorKey.currentState;
    if (!isAuthenticated || _changingDestination || navigator == null) {
      return false;
    }
    _changingDestination = true;
    final generation = _sessionGeneration;
    final observer = _observer;
    try {
      while (generation == _sessionGeneration && isAuthenticated) {
        final route = observer.top;
        if (route == null || route.isFirst) break;
        await navigator.maybePop();
        // maybePop also returns true when PopScope consumes a blocked pop.
        // The route itself must have left the navigator before continuing.
        if (route.isActive) return false;
      }
      if (generation != _sessionGeneration || !isAuthenticated) return false;
      selectRootTab(index);
      return true;
    } finally {
      if (generation == _sessionGeneration) _changingDestination = false;
    }
  }
}

class _WorkspaceRouteObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  Route<dynamic>? get top => _routes.lastOrNull;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index < 0) return;
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
  }
}

/// Place above MaterialApp's root navigator using its builder.
class WorkspaceNavigationScope
    extends InheritedNotifier<WorkspaceNavigationController> {
  const WorkspaceNavigationScope({
    required WorkspaceNavigationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WorkspaceNavigationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceNavigationScope>()
      ?.notifier;
}

const _destinations = <({IconData icon, IconData selectedIcon, String label})>[
  (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  (
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: 'Discover',
  ),
  (
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    label: 'Applications',
  ),
  (icon: Icons.school_outlined, selectedIcon: Icons.school, label: 'Academics'),
  (
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Coach',
  ),
];

/// Reuses the shell's five destinations on read-only detail screens.
///
/// Use `bottomNavigationBar: const WorkspaceBottomBar()` on detail Scaffolds.
/// Editors should omit it, or set [enabled] to false, to leave room for their
/// save actions. Even if accidentally included on a guarded editor, changing
/// tabs will respect its PopScope. Without an authenticated app scope the detail
/// bar is hidden, so independently presented screens do not expose dead links.
class WorkspaceBottomBar extends StatelessWidget {
  const WorkspaceBottomBar({
    this.selectedIndex,
    this.onDestinationSelected,
    this.enabled = true,
    super.key,
  });

  /// The root shell supplies these to retain support for standalone hosts.
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceNavigationScope.maybeOf(context);
    if (!enabled ||
        (selectedIndex == null && !(controller?.isAuthenticated ?? false))) {
      return const SizedBox.shrink();
    }
    return NavigationBar(
      selectedIndex: selectedIndex ?? controller!.selectedIndex,
      onDestinationSelected:
          onDestinationSelected ?? (index) => controller!.selectTab(index),
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: AppStrings.tr(context, destination.label),
          ),
      ],
    );
  }
}
