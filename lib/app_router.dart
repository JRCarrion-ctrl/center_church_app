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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AppState appState) => GoRouter(
  debugLogDiagnostics: true,
  refreshListenable: appState.authChangeNotifier,
  navigatorKey: navigatorKey,

  // Start on Home; /landing stays as a normal, manual page (no auto-redirects)
  initialLocation: '/landing',

  observers: [routeObserver],
  routes: [
    ...authRoutes,       // should include /auth
    ...miscRoutes,       // can still include /landing, just not auto-redirected
    ...groupRoutes,
    mainShellRoute,      // your 5-tab shell
  ],

  redirect: (context, state) {
    final location = state.uri.toString();

    // Never redirect these
    if (location == '/auth' || location == '/landing') return null;

    // Routes that require auth (adjust as needed)
    final needsAuth = [
      '/more/profile',
      '/more/family',
      '/more/nursery',
      '/more/permissions',
      '/more/directory',
      '/more/study',
    ].any((p) => location == p || location.startsWith('$p/'));

    if (needsAuth && !appState.isAuthenticated) {
      final from = Uri.encodeComponent(state.uri.toString());
      return '/auth?from=$from';
    }

    return null;
  },

  errorBuilder: (_, _) => const NotFoundPage(),
);
