// File: lib/app_state.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_timezone_latest/flutter_native_timezone_latest.dart';
import 'package:logger/logger.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/profile.dart';
import 'features/auth/profile_service.dart';
import 'features/groups/group_service.dart';
import 'features/groups/models/group_model.dart';
import 'shared/user_roles.dart';

class AppState extends ChangeNotifier {
  // Core State
  final _logger = Logger();
  final _authChangeNotifier = ValueNotifier<int>(0);
  final _authStreamController = StreamController<void>.broadcast();

  bool _initialized = false;
  bool _isLoading = true;
  bool _hasSeenLanding = false;
  String? _timezone;

  // UI State
  int _selectedIndex = 0;
  int _previousTabIndex = 2;
  int _currentTabIndex = 2;
  ThemeMode _themeMode = ThemeMode.system;
  String _languageCode = 'en';
  double _fontScale = 1.0;

  // Feature Toggles
  bool _showCountdown = true;
  bool _showGroupAnnouncements = true;
  bool _wifiOnlyMediaDownload = true;
  bool get wifiOnlyMediaDownload => _wifiOnlyMediaDownload;

  // Profile & Group Data
  Profile? _profile;
  List<GroupModel> _userGroups = [];
  List<String> _visibleCalendarGroupIds = [];

  // Getters
  bool get isInitialized => _initialized && !_isLoading;
  bool get isLoading => _isLoading;
  bool get hasSeenLanding => _hasSeenLanding;
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

  void _init() async {
    if (_initialized) return;
    _initialized = true;
    _setLoading(true);

    await Future.wait([
      _loadTheme(),
      _loadAnnouncementSettings(),
      _loadCachedProfile(),
      _loadLanguage(),
      _loadFontScale(),
      _loadVisibleCalendarGroupIds(),
      _loadWifiOnlyMediaDownload(),
    ]);

    Supabase.instance.client.auth.onAuthStateChange.listen((_) => restoreSession());
    await restoreSession();
    _setLoading(false);
  }

  // Initialization Helpers
  Future<void> loadTimezone() async {
    try {
      _timezone = await FlutterNativeTimezoneLatest.getLocalTimezone();
    } catch (e, stackTrace) {
      _logger.e('Failed to get timezone', error: e, stackTrace: stackTrace);
      _timezone = 'UTC';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadWifiOnlyMediaDownload() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiOnlyMediaDownload = prefs.getBool('wifiOnlyMediaDownload') ?? true;
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language_code') ?? 'en';
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
  }

  Future<void> _loadAnnouncementSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showCountdown = prefs.getBool('showCountdown') ?? true;
    _showGroupAnnouncements = prefs.getBool('showGroupAnnouncements') ?? true;
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_displayName');
    final role = prefs.getString('profile_role');
    if (name != null && role != null) {
      _profile = Profile(id: 'cached', displayName: name, role: role);
    }
  }

  Future<void> _loadVisibleCalendarGroupIds() async {
    final prefs = await SharedPreferences.getInstance();
    _visibleCalendarGroupIds = prefs.getStringList('visibleCalendarGroupIds') ?? [];
  }

  // Session
  Future<void> restoreSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await ProfileService().getProfile(user.id);
        _setProfile(profile);
        await _cacheProfile(profile);
        await loadUserGroups();
        OneSignal.login(user.id);
      } else {
        _setProfile(null);
        await _cacheProfile(null);
        OneSignal.logout();
      }
    } catch (e) {
      debugPrint('Failed to restore session: $e');
      _setProfile(null);
    }
  }

  // Profile
  void setProfile(Profile? profile) {
    _setProfile(profile);
    _cacheProfile(profile);
    _notifyAuthChanged();
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

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _setProfile(null);
    await _cacheProfile(null);
    _notifyAuthChanged();
  }

  void _notifyAuthChanged() => _authChangeNotifier.value++;

  // UI Actions
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

  void markLandingSeen() {
    _hasSeenLanding = true;
    notifyListeners();
  }

  Future<void> resetLandingSeen() async {
    _hasSeenLanding = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenLanding', false);
    notifyListeners();
  }

  void setLanguageCode(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
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

  void setUserGroups(List<GroupModel> groups) {
    _userGroups = groups;
    notifyListeners();
  }

  Future<void> loadUserGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final groups = await GroupService().getUserGroups(userId);
      setUserGroups(groups);
    }
  }

  void setVisibleCalendarGroupIds(List<String> groupIds) async {
    _visibleCalendarGroupIds = groupIds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visibleCalendarGroupIds', groupIds);
    notifyListeners();
  }

  void updateOneSignalUser() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      OneSignal.login(userId);
    } else {
      OneSignal.logout();
    }
  }

  void resetAppState() {
    _themeMode = ThemeMode.system;
    _languageCode = 'en';
    _hasSeenLanding = false;
    _showCountdown = true;
    _showGroupAnnouncements = true;
    _fontScale = 1.0;
    notifyListeners();
  }

  void setWifiOnlyMediaDownload(bool value) async {
    _wifiOnlyMediaDownload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifiOnlyMediaDownload', value);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStreamController.close();
    super.dispose();
  }
}