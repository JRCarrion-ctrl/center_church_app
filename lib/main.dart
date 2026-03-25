// file: lib/main.dart

import 'dart:async';

import 'package:ccf_app/app_router.dart';
import 'package:ccf_app/core/hasura_client.dart';
import 'package:ccf_app/core/theme.dart';
import 'package:ccf_app/features/splash/splash_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✨ ADDED: Needed for kIsWeb and defaultTargetPlatform
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'policy_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:media_kit/media_kit.dart';
import 'features/groups/group_service.dart';
import 'dart:io' show Platform; // ✨ ADDED: Only import dart:io where necessary

import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  MediaKit.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✨ WRAPPED: Only run OneSignal setup on native mobile
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("a75771e7-9bd5-4497-adf3-18b7c8901bcb");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const CCFAppBoot(),
    ),
  );
}

Future<void> requestTrackingAuthorization() async {
  // ✨ CHANGED: Use defaultTargetPlatform instead of Platform.isIOS to avoid dart:io
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;

    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 500)); 

      status = await AppTrackingTransparency.requestTrackingAuthorization();
      debugPrint('ATT permission status: $status');
    }
  }
}

Future<void> requestPushPermission() async {
  // ✨ WRAPPED: Skip permission handler on web
  if (!kIsWeb) {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
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

  @override
  void initState() {
    super.initState();
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
    // ✨ WRAPPED: Skip on web
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) return;

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
      if (initialUri.host == 'reset') {
        if (mounted) _router.go('/reset-password');
      }
    }
  }

  Future<void> _initializeApp() async {
    await _requestPushPermissionOnce();
    await requestTrackingAuthorization();
    appState = AppState();
    
    // 1. Create the router
    _router = createRouter(appState);

    // 2. ✨ WRAPPED: Handle Notification Clicks only on mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        
        if (data != null && data['route'] != null) {
          String route = data['route'];

          if (route.startsWith('ccfapp://')) {
            route = route.replaceFirst('ccfapp://', '');
          }
          if (!route.startsWith('/')) {
            route = '/$route';
          }

          debugPrint("OneSignal Deep Link: Navigating to $route");
          
          _router.go(route);
        }
      });
    }

    await _handleIncomingLinks();
    
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
          if (!state.isInitialized || !state.termsAccepted) {
            
            Widget initialWidget;
            if (!state.termsAccepted) {
              initialWidget = const PolicyAcceptanceScreen(
                privacyPolicyUrl: 'https://privacy-policy.ccfapp.com/', 
                termsAndConditionsUrl: 'https://terms-and-conditions.ccfapp.com/',
              );
            } else {
              initialWidget = const SplashScreen();
            }
            return MaterialApp(home: initialWidget);
          }
          
          final nextClient = state.isAuthenticated ? state.client : buildPublicHasuraClient();
          if (!identical(_clientNotifier.value, nextClient)) {
            _clientNotifier.value = nextClient;
          }

          const pageTransitionsTheme = PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          );
          
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(state.fontScale),
            ),
            child: GraphQLProvider(
              client: _clientNotifier,
              child: MultiProvider(
                providers: [
                  ProxyProvider<AppState, GroupService>(
                    update: (context, state, previous) => GroupService(_clientNotifier.value),
                  ),
                ],
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: ccfLightTheme.copyWith(
                    pageTransitionsTheme: pageTransitionsTheme,
                  ),
                  darkTheme: ccfDarkTheme.copyWith(
                    pageTransitionsTheme: pageTransitionsTheme,
                  ),
                  themeMode: state.themeMode,
                  routerConfig: _router,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}