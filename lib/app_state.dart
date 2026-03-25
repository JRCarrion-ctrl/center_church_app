// file: lib/app_state.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✨ ADDED: Needed for kIsWeb
import 'package:logger/logger.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter/services.dart'; 
import 'dart:io' show Platform;

import 'features/auth/oidc_auth.dart';
import 'core/hasura_client.dart';

import 'features/auth/profile.dart';
import 'features/groups/group_service.dart';
import 'features/groups/models/group_model.dart';
import 'shared/user_roles.dart';

final bool isMobileDevice = !kIsWeb && 
    (defaultTargetPlatform == TargetPlatform.iOS || 
     defaultTargetPlatform == TargetPlatform.android);

enum ChurchService { english, spanish, both }

class AppState extends ChangeNotifier {
  // --- Core ---
  final _logger = Logger();
  final _authChangeNotifier = ValueNotifier<int>(0);
  final _authStreamController = StreamController<void>.broadcast();
  static const _termsAcceptedKey = 'terms_accepted';
  bool _termsAccepted = false;
  bool get termsAccepted => _termsAccepted;
  
  // Use a single GraphQLClient and update it.
  GraphQLClient? _client;
  GraphQLClient get client => _client ?? buildPublicHasuraClient();

  GroupService? _groups;
  GroupService get groupService => _groups ??= GroupService(client);

  bool _initialized = false;
  bool _isLoading = true;
  String? _timezone;
  String? _pendingDeepLink;

  // --- UI ---
  int _selectedIndex = 0;
  int _previousTabIndex = 2;
  int _currentTabIndex = 2;
  ThemeMode _themeMode = ThemeMode.system;
  String _languageCode = 'en';
  double _fontScale = 1.0;

  // --- Feature Toggles ---
  bool _showCountdown = true;
  bool _showGroupAnnouncements = true;
  bool _wifiOnlyMediaDownload = true;
  bool get wifiOnlyMediaDownload => _wifiOnlyMediaDownload;

  // --- Profile & Groups ---
  Profile? _profile;
  List<GroupModel> _userGroups = [];
  List<String> _visibleCalendarGroupIds = [];
  bool _calendarGroupsInitialized = false;
  bool get calendarGroupsInitialized => _calendarGroupsInitialized;

  // --- Bilingual Service State ---
  ChurchService _selectedService = ChurchService.both;
  ChurchService get selectedService => _selectedService;

  // Helper to map UI enum to Database tags
  List<String> get databaseServiceFilter {
    return switch (_selectedService) {
      ChurchService.english => ['english'],
      ChurchService.spanish => ['spanish'],
      ChurchService.both => ['english', 'spanish'],
    };
  }

  // --- Getters ---
  // (Getters omitted for brevity, keep your existing ones)
  bool get isInitialized => _initialized && !_isLoading;
  bool get isLoading => _isLoading;
  int get selectedIndex => _selectedIndex;
  int get previousTabIndex => _previousTabIndex;
  int get currentTabIndex => _currentTabIndex;
  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  double get fontScale => _fontScale;
  Profile? get profile => _profile;
  bool get isAuthenticated => _profile != null;
  String? get displayName => _profile?.displayName;
  String? get role => _profile?.role;
  String? get email => _profile?.email;
  UserRole get userRole => UserRoleExtension.fromString(_profile?.role);
  String? get timezone => _timezone;
  bool get showCountdown => _showCountdown;
  bool get showGroupAnnouncements => _showGroupAnnouncements;
  List<GroupModel> get userGroups => _userGroups;
  List<String> get visibleCalendarGroupIds => _visibleCalendarGroupIds;
  ValueNotifier<int> get authChangeNotifier => _authChangeNotifier;

  AppState() {
    _init();
  }

  // --- Boot ---
  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    _setLoading(true);

    try {
      await Future.wait([
        _loadPrefs(),
        _loadCachedProfile(),
        loadTimezone(),
      ]);

      await restoreSession();

    } catch (e, st) {
      _logger.e('App state initialization failed', error: e, stackTrace: st);
    } finally {
      _setLoading(false);
    }
  }
  
  // --- Helpers ---
  Future<void> loadTimezone() async {
    try {
      _timezone = DateFormat('zzz').format(DateTime.now());
    } catch (e, st) {
      _logger.e('Failed to get timezone', error: e, stackTrace: st);
      _timezone = 'UTC';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiOnlyMediaDownload = prefs.getBool('wifiOnlyMediaDownload') ?? true;
    _languageCode = prefs.getString('language_code') ?? 'en';
    final storedTheme = prefs.getString('theme_mode');
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == storedTheme,
      orElse: () => ThemeMode.system,
    );
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    _showCountdown = prefs.getBool('showCountdown') ?? true;
    _showGroupAnnouncements = prefs.getBool('showGroupAnnouncements') ?? true;
    _visibleCalendarGroupIds = prefs.getStringList('visibleCalendarGroupIds') ?? [];
    _calendarGroupsInitialized = prefs.getBool('calendarGroupsInitialized') ?? false;
    final storedService = prefs.getString('selected_service') ?? 'spanish';
    _selectedService = ChurchService.values.firstWhere(
      (e) => e.name == storedService,
      orElse: () => ChurchService.spanish,
    );
  }

  // --- Logic to Update Service ---
  Future<void> updateServiceFilter(ChurchService service) async {
    if (_selectedService == service) return;
    
    _selectedService = service;
    notifyListeners();

    // 1. Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_service', service.name);

    // 2. Sync to Hasura Profile (if authenticated)
    if (isAuthenticated && _profile?.id != null) {
      await _syncLanguagesToProfile();
    }
  }

  Future<void> _syncLanguagesToProfile() async {
    const mUpdateLangs = r'''
      mutation UpdateUserLanguages($id: String!, $langs: [String!]!) {
        update_profiles_by_pk(
          pk_columns: {id: $id}, 
          _set: {preferred_languages: $langs}
        ) { 
          id 
        }
      }
    ''';

    try {
      final res = await client.mutate(MutationOptions(
        document: gql(mUpdateLangs),
        variables: {
          'id': _profile!.id,
          // Now that the types match, passing the Dart List works perfectly
          'langs': databaseServiceFilter, 
        },
      ));

      if (res.hasException) {
        _logger.e('Hasura Mutation Error: ${res.exception.toString()}');
      } else {
        _logger.i('Successfully synced language preferences to Hasura');
      }
    } catch (e) {
      _logger.e('Failed to sync language preferences', error: e);
    }
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_displayName');
    final role = prefs.getString('profile_role');
    if (name != null && role != null) {
      _profile = Profile(id: 'cached', displayName: name, role: role);
    }
  }

  Future<void> _setClient(GraphQLClient? newClient) async {
    _client = newClient;
    _groups = null; 
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _termsAccepted = prefs.getBool(_termsAcceptedKey) ?? false;
    _logger.i('Starting restoreSession');
    try {
      await OidcAuth.refreshIfNeeded();
      final access = await OidcAuth.readAccessToken();
      final idTok  = await OidcAuth.readIdToken();

      if (access == null || access.isEmpty) {
        await _clearSessionData();
        return;
      }

      final claims = JwtDecoder.decode(access);
      final hasuraClaims = claims['hasura_claims'] as Map<String, dynamic>?;

      if (hasuraClaims == null) {
          throw Exception("JWT is missing nested 'hasura_claims' object.");
      }

      final userId = (hasuraClaims['x-hasura-user-id'] as String?) ?? (claims['sub'] as String?);
      final defaultRole = (hasuraClaims['x-hasura-default-role'] as String?) ?? 'member';
      final email = (hasuraClaims['x-hasura-user-email'] as String?);
      if (userId == null || userId.isEmpty) {
        throw Exception('JWT missing x-hasura-user-id / sub');
      }

      String? displayName;
      if (idTok != null && idTok.isNotEmpty) {
        try {
          final idc = JwtDecoder.decode(idTok);
          displayName = (idc['name'] as String?) ?? (idc['given_name'] as String?);
        } catch (e) {
          _logger.w('Failed to decode ID token: $e');
        }
      }

      final tempClient = await makeHasuraClient();

      const mUpsert = r'''
        mutation UpsertProfile($id: String!, $display: String!, $email: String!) {
          insert_profiles_one(
            object: { 
            id: $id
            display_name: $display 
            email: $email
          }
            on_conflict: { constraint: profiles_pkey, update_columns: [] }
          ) { id }
        }
      ''';
      await tempClient.mutate(MutationOptions(
        document: gql(mUpsert),
        variables: {'id': userId, 'display': displayName ?? 'New User', 'email': email},
      ));

      const qMe = r'''
        query Me($id: String!) {
          profiles_by_pk(id: $id) { id display_name role email }
        }
      ''';
      final me = await tempClient.query(QueryOptions(
        document: gql(qMe),
        variables: {'id': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (me.hasException || me.data?['profiles_by_pk'] == null) {
        _logger.e('[auth] Me query failed: ${me.exception}');
        await _clearSessionData();
        return;
      }
      
      final m = me.data!['profiles_by_pk'] as Map<String, dynamic>;
      final prof = Profile(
        id: m['id'] as String,
        displayName: (m['display_name'] as String?) ?? (displayName ?? 'User'),
        role: (m['role'] as String?) ?? defaultRole,
        email: m['email'] as String?,
      );

      _setProfile(prof);
      await _cacheProfile(prof);
      await _setClient(tempClient);

      await loadUserGroups();
      await updateOneSignalUser();
      
    } catch (e, st) {
      _logger.e('Failed to restore Zitadel session', error: e, stackTrace: st);
      await _clearSessionData();
    } finally {
      _notifyAuthChanged();
    }
    notifyListeners();
  }

  Future<void> acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsAcceptedKey, true);
    _termsAccepted = true;
    notifyListeners();
  }

  Future<void> _clearSessionData() async {
    await OidcAuth.signOut();
    _setProfile(null);
    await _cacheProfile(null);
    await _setClient(null);
    await updateOneSignalUser();
  }

  Future<void> signInWithZitadel() async {
    _logger.i('Starting signInWithZitadel');
    _setLoading(true);

    try {
      await OidcAuth.signIn().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Sign-in failed to complete within the time limit.');
        },
      );

      await restoreSession();

    } on PlatformException catch (e, st) {
      _logger.e('Platform Auth Error: $e', error: e, stackTrace: st);
      
      if (e.code == 'null_intent' || (e.message?.contains('Null intent received') ?? false)) {
         throw Exception('Login Failed: Intent data was lost during redirect. Check Android deep-linking and MainActivity.kt.');
      }
      rethrow; 
      
    } catch (e, st) {
      _logger.e('Zitadel sign-in process failed or was cancelled', error: e, stackTrace: st);
      
      if (e.toString().contains('User cancelled flow')) {
          throw Exception('Sign-in was canceled by the user.');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> signOut() async {
    _logger.i('Starting signOut');
    _setLoading(true);
    await _clearSessionData();
    _setLoading(false);
  }

  void _setProfile(Profile? profile) {
    if (_profile != profile) {
      _profile = profile;
      notifyListeners();
    }
  }

  Future<void> _cacheProfile(Profile? profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile == null) {
      await prefs.remove('profile_displayName');
      await prefs.remove('profile_role');
    } else {
      await prefs.setString('profile_displayName', profile.displayName);
      await prefs.setString('profile_role', profile.role);
    }
  }

  Future<void> loadUserGroups() async {
    final userId = _profile?.id;
    if (userId == null || userId.isEmpty) {
      _userGroups = [];
      notifyListeners();
      return;
    }
    try {
      final groups = await groupService.getUserGroups(userId);
      _userGroups = groups;
      notifyListeners();
    } catch (e, st) {
      _logger.e('Failed to load user groups', error: e, stackTrace: st);
      _userGroups = [];
      notifyListeners();
    }
  }

  void setVisibleCalendarGroupIds(List<String> groupIds) async {
    _visibleCalendarGroupIds = groupIds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visibleCalendarGroupIds', groupIds);
    notifyListeners();
  }
  void markCalendarGroupsInitialized() async {
    _calendarGroupsInitialized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendarGroupsInitialized', true);
    // no notifyListeners needed — this is a silent internal flag
  }

  // --- OneSignal ---
  Future<void> updateOneSignalUser() async {
    _logger.i('Starting updateOneSignalUser');
    try {
      final loginId = _profile?.id;
      if (loginId == null || loginId.isEmpty) {
        // ✨ WRAPPED: Skip OneSignal logout on web
        if (isMobileDevice) {
          await OneSignal.logout();
        }
        _logger.i('OneSignal logged out');
        return;
      }

      // ✨ WRAPPED: Skip OneSignal login and token gathering on web
      String? pushToken;
      if (isMobileDevice) {
        await OneSignal.login(loginId);
        pushToken = OneSignal.User.pushSubscription.id;
      }
      
      // 1. Hasura Upsert: Always sync the device token (pushToken will be null on web, which is fine)
      const mUpsertEndpoint = r'''
        mutation UpsertEndpoint($userId: String!, $token: String, $seen: timestamptz!) {
          insert_notification_endpoints_one(
            object: {
              user_id: $userId,
              provider: "onesignal",
              external_id: $userId,
              push_token: $token,
              last_seen: $seen
            },
            on_conflict: {
              constraint: notification_endpoints_pkey,
              update_columns: [push_token, last_seen, external_id]
            }
          ) { user_id provider push_token }
        }
      ''';

      await client.mutate(MutationOptions(
        document: gql(mUpsertEndpoint),
        variables: {
          'userId': loginId,
          'token': pushToken, // This safely passes null on web
          'seen': DateTime.now().toUtc().toIso8601String(),
        },
      ));
      _logger.i('OneSignal endpoint updated in Hasura');

      // ✨ WRAPPED: Skip OneSignal tags on web
      if (isMobileDevice) {
        final role = _profile?.role;
        if (role != null && role.isNotEmpty) {
          await OneSignal.User.addTags({'role': role});
        }
      }
    } catch (e, st) {
      _logger.e('Failed to update OneSignal user', error: e, stackTrace: st);
    }
  }

  // --- UI prefs ---
  void setIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void updateTabIndex(int index) {
    if (index != _currentTabIndex) {
      _previousTabIndex = _currentTabIndex;
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  void setPendingDeepLink(String link) {
    _pendingDeepLink = link;
  }
  String? consumePendingDeepLink() {
    final link = _pendingDeepLink;
    _pendingDeepLink = null;
    return link;
  }

  void setLanguageCode(BuildContext context, String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    if (!context.mounted) return;
    await context.setLocale(Locale(code));
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  void setFontScale(double scale) async {
    _fontScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', scale);
    notifyListeners();
  }

  void setShowCountdown(bool value) async {
    _showCountdown = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showCountdown', value);
    notifyListeners();
  }

  void setShowGroupAnnouncements(bool value) async {
    _showGroupAnnouncements = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showGroupAnnouncements', value);
    notifyListeners();
  }

  void setWifiOnlyMediaDownload(bool value) async {
    _wifiOnlyMediaDownload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifiOnlyMediaDownload', value);
    notifyListeners();
  }

  void resetAppState() {
    _themeMode = ThemeMode.system;
    _languageCode = 'en';
    _showCountdown = true;
    _showGroupAnnouncements = true;
    _fontScale = 1.0;
    notifyListeners();
  }

  // --- Loading ---
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _notifyAuthChanged() => _authChangeNotifier.value++;

  @override
  void dispose() {
    _authStreamController.close();
    super.dispose();
  }
}