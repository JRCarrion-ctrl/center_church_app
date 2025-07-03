// File: lib/routes/auth_routes.dart
import 'package:go_router/go_router.dart';
import '../features/auth/auth_page.dart';
import '../transitions/transitions.dart';

final List<GoRoute> authRoutes = [
  GoRoute(
    path: '/auth',
    pageBuilder: (_, _) => buildSlidePage(
      const AuthPage(),
      direction: SlideDirection.left,
    ),
  ),
];
