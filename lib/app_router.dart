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

    // 1. Never redirect these public routes
    if (location.startsWith('/auth') || location == '/landing') return null;

    // 2. Define routes that STRICTLY require authentication
    final isInvite = location.startsWith('/invite/');
    final needsAuth = isInvite || [
      '/more/profile',
      '/more/family',
      '/more/nursery',
      '/more/permissions',
      '/more/directory',
      '/more/study',
      '/calendar/app-event', // Protect deep links to events
      '/group-event',        // Protect deep links to group events
    ].any((p) => location == p || location.startsWith('$p/'));

    // 3. The Intercept: If they need auth but aren't logged in
    if (needsAuth && !appState.isAuthenticated) {
      // Memory Save: Remember where they were trying to go!
      appState.setPendingDeepLink(location);
      return '/auth';
    }

    // 4. The Fulfillment: If they are logged in and hit the root route
    if (appState.isAuthenticated && location == '/') {
      final pendingLink = appState.consumePendingDeepLink();
      if (pendingLink != null) {
        return pendingLink; // Send them to their saved destination!
      }
    }

    return null;
  },

  errorBuilder: (_, _) => const NotFoundPage(),
);
