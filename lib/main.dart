// File: lib/main.dart
import 'package:ccf_app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

import 'app_state.dart';
import 'features/splash/splash_screen.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("a75771e7-9bd5-4497-adf3-18b7c8901bcb");

  runApp(const CCFAppBoot());
}

Future<void> requestPushPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class CCFAppBoot extends StatefulWidget {
  const CCFAppBoot({super.key});

  @override
  State<CCFAppBoot> createState() => _CCFAppBootState();
}

class _CCFAppBootState extends State<CCFAppBoot> {
  bool _ready = false;
  late final AppState appState;
  late final GoRouter _router;
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _requestPushPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('notification_prompted') ?? false;

    if (!hasPrompted) {
      // Request OS-level push permission (important for iOS)
      final accepted = await OneSignal.Notifications.requestPermission(true);

      // (Optional) You can log or react to whether the user accepted:
      debugPrint('Push permission accepted: $accepted');

      await prefs.setBool('notification_prompted', true);
    }
  }

  Future<void> _handleIncomingLinks() async {
    _appLinks = AppLinks();

    // Handle links while app is running
    _appLinks!.uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;

      if (uri.host == 'login-callback') {
        final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
        final session = response.session;
        OneSignal.login(session.user.id);
        await appState.restoreSession();
        _router.go('/');
      } else if (uri.host == 'reset') {
        _router.go('/reset-password'); // 👈 Route to your new password screen
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });

    // Handle cold-start deep link
    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null) {
      if (initialUri.host == 'login-callback') {
        final response = await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
        final session = response.session;
        OneSignal.login(session.user.id);
        await appState.restoreSession();
        _router.go('/');
      } else if (initialUri.host == 'reset') {
        _router.go('/reset-password'); // 👈 Same here
      }
    }
  }

  Future<void> _initializeApp() async {
    await Supabase.initialize(
      url: 'https://vhzcbqgehlpemdkvmzvy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoemNicWdlaGxwZW1ka3ZtenZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4ODY3NjgsImV4cCI6MjA2NjQ2Mjc2OH0.rPIiZ3RHcG3b3zTF-9TwB0fu-puByMXTeN5yRe5M0H0',
    );

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      OneSignal.login(userId);
    } else {
      OneSignal.logout();
    }

    await _requestPushPermissionOnce();

    appState = AppState();
    await appState.loadTimezone();
    _router = createRouter(appState);

    await _handleIncomingLinks();

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: SplashScreen());
    }

    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.isInitialized) {
            return const MaterialApp(home: SplashScreen());
          }

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(state.fontScale),
            ),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: ccfLightTheme,
              darkTheme: ccfDarkTheme,
              themeMode: state.themeMode,
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
} 