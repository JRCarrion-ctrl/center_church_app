// File: lib/shared/page_refresh.dart
//
// Keeps pages fresh without anyone pulling to refresh. A page that mixes in
// [AutoRefresh] reloads when:
//   * the user comes back to it from another screen (any route pops),
//   * the user taps its bottom-nav tab again,
//   * the app comes back to the foreground.
// Opening a tab already builds a fresh page, which loads in initState.
import 'package:flutter/widgets.dart';

class PageRefresh extends ChangeNotifier {
  PageRefresh._() {
    _lifecycle = AppLifecycleListener(onResume: ping);
  }

  static final PageRefresh instance = PageRefresh._();

  // ignore: unused_field
  late final AppLifecycleListener _lifecycle;

  /// Asks every visible [AutoRefresh] page to reload.
  void ping() {
    // Wait a frame so a popped route is fully gone and no build is running.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

/// Add to the root navigator's observers: returning to a screen refreshes it.
class PageRefreshObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Dialogs, menus and sheets popping shouldn't reload the page under them.
    if (route is PageRoute) PageRefresh.instance.ping();
  }
}

mixin AutoRefresh<T extends StatefulWidget> on State<T> {
  DateTime _lastAutoRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  /// Reload the page's data. Called on return, tab re-tap and app resume.
  Future<void> onAutoRefresh();

  @override
  void initState() {
    super.initState();
    PageRefresh.instance.addListener(_handlePing);
  }

  @override
  void dispose() {
    PageRefresh.instance.removeListener(_handlePing);
    super.dispose();
  }

  void _handlePing() {
    if (!mounted) return;
    // Skip pages that are in the tree but not on screen (under another route).
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final now = DateTime.now();
    if (now.difference(_lastAutoRefresh) < const Duration(seconds: 1)) return;
    _lastAutoRefresh = now;
    onAutoRefresh();
  }

}
