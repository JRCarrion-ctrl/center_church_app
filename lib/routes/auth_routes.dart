// File: lib/routes/auth_routes.dart
import 'package:ccf_app/features/auth/reset_password.dart';
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
  GoRoute(
    path: '/reset-password',
    builder: (context, state) => const ResetPasswordPage(),
  ),
];
