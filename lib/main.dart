// file: lib/main.dart

import 'dart:async';

import 'package:ccf_app/app_router.dart';
import 'package:ccf_app/core/hasura_client.dart';
import 'package:ccf_app/core/theme.dart';
import 'package:ccf_app/features/splash/splash_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'policy_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:media_kit/media_kit.dart';
import 'features/groups/group_service.dart';

import 'app_state.dart';

final bool isMobileDevice = !kIsWeb && 
    (defaultTargetPlatform == TargetPlatform.iOS || 
     defaultTargetPlatform == TargetPlatform.android);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  MediaKit.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✨ WRAPPED: Only run OneSignal setup on native mobile
  if (isMobileDevice) {
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
  if (isMobileDevice) {
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

  Future<void> _handleIncomingLinks() async {
    _appLinks = AppLinks();

    // Helper function to process URIs for both cold starts and live streams
    void processUri(Uri uri) {
      // 1. Password Reset (Custom Scheme: ccfapp://reset)
      if (uri.host == 'reset') {
        if (mounted) _router.go('/reset-password');
        return;
      }

      // 2. Group Invites (Universal Link: https://ccfrederick.app/join/:token)
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'join') {
        // uri.path will be something like "/join/your-token-uuid"
        if (mounted) _router.go(uri.path);
        return;
      }

      // 3. Group Invites (Custom Scheme fallback: ccfapp://join/:token)
      if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
        final token = uri.pathSegments.first;
        if (mounted) _router.go('/join/$token');
        return;
      }
    }

    // Live link handling (App is already open in the background)
    _linkSub = _appLinks!.uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;
      processUri(uri);
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });

    // Cold start link (App is launched entirely from the link)
    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null) {
      processUri(initialUri);
    }
  }

  Future<void> _initializeApp() async {
    appState = AppState();
    
    // 1. Create the router
    _router = createRouter(appState);

    // 2. ✨ WRAPPED: Handle Notification Clicks only on mobile
    if (isMobileDevice) {
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