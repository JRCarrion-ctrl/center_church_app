// lib/routes/auth_routes.dart
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/auth/auth_page.dart';
import '../transitions/transitions.dart';
import '../app_state.dart';

final List<GoRoute> authRoutes = [
  GoRoute(
    path: '/auth',
    name: 'auth',
    pageBuilder: (context, state) => buildSlidePage(
      const AuthPage(),
      direction: SlideDirection.right,
    ),
    redirect: (context, state) {
      final app = context.read<AppState>();
      return app.isAuthenticated ? '/' : null;
    },
  ),
];
