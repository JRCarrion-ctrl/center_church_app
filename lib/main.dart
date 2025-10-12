// file: lib/main.dart
import 'dart:async';

import 'package:ccf_app/app_router.dart';
import 'package:ccf_app/core/hasura_client.dart';
import 'package:ccf_app/core/theme.dart';
import 'package:ccf_app/features/splash/splash_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // OneSignal init (ID set after session restore)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("a75771e7-9bd5-4497-adf3-18b7c8901bcb");

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const CCFAppBoot(),
    ),
  );
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
  late final ValueNotifier<GraphQLClient> _clientNotifier;
  AppLinks? _appLinks;
  StreamSubscription<Uri?>? _linkSub;
  bool _handledInitialLogin = false;

  @override
  void initState() {
    super.initState();
    // Initialize the ValueNotifier with a public client first.
    _clientNotifier = ValueNotifier<GraphQLClient>(buildPublicHasuraClient());
    _initializeApp();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _clientNotifier.dispose();
    super.dispose();
  }

  Future<void> _requestPushPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('notification_prompted') ?? false;
    if (!hasPrompted) {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('Push permission accepted: $accepted');
      await prefs.setBool('notification_prompted', true);
    }
  }

  Future<void> _handleIncomingLinks() async {
    _appLinks = AppLinks();

    // Live link handling
    _linkSub = _appLinks!.uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;

      switch (uri.host) {
        case 'login-callback':
          await appState.restoreSession();
          await appState.updateOneSignalUser();
          if (mounted) _router.go('/');
          break;
        case 'reset':
          if (mounted) _router.go('/reset-password');
          break;
        default:
          break;
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });

    // Cold start link
    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null) {
      if (initialUri.host == 'login-callback' && !_handledInitialLogin) {
        _handledInitialLogin = true;
        await appState.restoreSession();
        if (mounted) _router.go('/');
      } else if (initialUri.host == 'reset') {
        if (mounted) _router.go('/reset-password');
      }
    }
  }

  Future<void> _initializeApp() async {
    await _requestPushPermissionOnce();
    appState = AppState();
    await appState.restoreSession();
    final loginId = appState.profile?.id;
    if (loginId != null) {
      OneSignal.login(loginId);
    } else {
      OneSignal.logout();
    }
    
    _router = createRouter(appState);
    await _handleIncomingLinks();
    
    // Set the initial client based on the restored session.
    // This connects the main.dart client notifier to the client in app_state.
    _clientNotifier.value = appState.isAuthenticated ? appState.client : buildPublicHasuraClient();

    if (mounted) setState(() => _ready = true);
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
          
          // Update the client notifier when the state changes
          final nextClient = state.isAuthenticated ? state.client : buildPublicHasuraClient();
          if (!identical(_clientNotifier.value, nextClient)) {
            _clientNotifier.value = nextClient;
          }
          
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(state.fontScale),
            ),
            // Use the official GraphQLProvider from graphql_flutter
            child: GraphQLProvider(
              client: _clientNotifier,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: ccfLightTheme,
                darkTheme: ccfDarkTheme,
                themeMode: state.themeMode,
                routerConfig: _router,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
              ),
            ),
          );
        },
      ),
    );
  }
}