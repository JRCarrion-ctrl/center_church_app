// File: lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_state.dart';
import 'routes/auth_routes.dart';
import 'routes/group_routes.dart';
import 'routes/main_shell_routes.dart';
import 'routes/misc_routes.dart';
import 'core/pages/not_found_page.dart';
import 'routes/router_observer.dart';

GoRouter createRouter(AppState appState) => GoRouter(
  debugLogDiagnostics: true,
  refreshListenable: appState.authChangeNotifier,
  navigatorKey: navigatorKey,
  initialLocation: '/landing',
  observers: [routeObserver],
  routes: [
    ...authRoutes,
    ...miscRoutes,
    ...groupRoutes,
    mainShellRoute,
  ],

  redirect: (context, state) {
    debugPrint('🔁 REDIRECT from ${state.fullPath}, seenLanding: ${appState.hasSeenLanding}');
    final path = state.uri.toString();

    // Only redirect FROM "/" → "/landing" if landing hasn't been seen
    if (path == '/' && !appState.hasSeenLanding) {
      return '/landing';
    }

    // Only redirect FROM "/landing" → "/" if landing has been seen
    if (path == '/landing' && appState.hasSeenLanding) {
      return '/';
    }

    // ✅ Do NOT redirect anything else (e.g. /calendar, /groups, etc)
    return null;
  },

  errorBuilder: (_, _) => const NotFoundPage(),
);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
