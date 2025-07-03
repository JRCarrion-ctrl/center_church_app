// File: lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_state.dart';
import 'routes/auth_routes.dart';
import 'routes/group_routes.dart';
import 'routes/main_shell_routes.dart';
import 'routes/misc_routes.dart';
import 'core/pages/not_found_page.dart';

GoRouter createRouter(AppState appState) => GoRouter(
  debugLogDiagnostics: true,
  refreshListenable: appState.authChangeNotifier,
  navigatorKey: navigatorKey,
  routes: [
    ...authRoutes,
    ...miscRoutes,
    ...groupRoutes,
    mainShellRoute,
  ],

  redirect: (context, state) {
    final isAtRoot = state.fullPath == '/' || state.fullPath == null;

    if (isAtRoot && !appState.hasSeenLanding) {
      return '/landing';
    }

    return null;
  },

  errorBuilder: (_, _) => const NotFoundPage(),
);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
