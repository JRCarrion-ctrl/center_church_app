import 'package:flutter/material.dart';
import 'package:flutter_native_timezone_latest/flutter_native_timezone_latest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:logger/logger.dart';

import 'features/auth/profile.dart';
import 'features/auth/profile_service.dart';
import 'features/groups/models/group_model.dart';
import 'features/groups/group_service.dart';

class AppState extends ChangeNotifier {
  // State
  int _selectedIndex = 0;
  int _previousTabIndex = 2;
  int _currentTabIndex = 2;
  bool _isLoading = true;
  bool _initialized = false;
  bool _hasSeenLanding = false;
  final _logger = Logger();
  ThemeMode _themeMode = ThemeMode.system;
  String? _timezone;
  String? get timezone => _timezone;

  Future<void> loadTimezone() async {
    try {
      _timezone = await FlutterNativeTimezoneLatest.getLocalTimezone();
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Failed to get timezone', error: e, stackTrace: stackTrace);
      _timezone = 'UTC';
    }
  }

  // Profile
  Profile? _profile;
  final ValueNotifier<int> _authChangeNotifier = ValueNotifier(0);
  final _authStreamController = StreamController<void>.broadcast();

  // Settings
  bool _showCountdown = true;
  bool _showGroupAnnouncements = true;
  String _languageCode = 'en';
  String get languageCode => _languageCode;

  // Groups
  List<GroupModel> _userGroups = [];
  List<String> _visibleCalendarGroupIds = [];

  List<GroupModel> get userGroups => _userGroups;
  List<String> get visibleCalendarGroupIds => _visibleCalendarGroupIds;

  void setUserGroups(List<GroupModel> groups) {
    _userGroups = groups;
    notifyListeners();
  }

  void setVisibleCalendarGroupIds(List<String> groupIds) async {
    _visibleCalendarGroupIds = groupIds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visibleCalendarGroupIds', groupIds);
  }

  Future<void> loadUserGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final groups = await GroupService().getUserGroups(userId);
      setUserGroups(groups);
    }
  }

  AppState() {
    _init();
  }

  // Initialization
  void _init() async {
    if (_initialized) return;
    _initialized = true;

    _setLoading(true);
    await _loadTheme();
    await _loadAnnouncementSettings();
    await _loadCachedProfile();
    await _loadLanguage();
    await _loadVisibleCalendarGroupIds();

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _restoreSession();
    });

    await _restoreSession();
    _setLoading(false);
  }

  Future<void> _loadVisibleCalendarGroupIds() async {
    final prefs = await SharedPreferences.getInstance();
    _visibleCalendarGroupIds = prefs.getStringList('visibleCalendarGroupIds') ?? [];
  }

  // Getters
  bool get isInitialized => _initialized && !_isLoading;
  bool get isLoading => _isLoading;
  bool get hasSeenLanding => _hasSeenLanding;
  int get selectedIndex => _selectedIndex;
  int get previousTabIndex => _previousTabIndex;
  int get currentTabIndex => _currentTabIndex;
  ThemeMode get themeMode => _themeMode;
  Profile? get profile => _profile;
  bool get isAuthenticated => _profile != null;
  String? get displayName => _profile?.displayName;
  String? get role => _profile?.role;
  bool get showCountdown => _showCountdown;
  bool get showGroupAnnouncements => _showGroupAnnouncements;
  ValueNotifier<int> get authChangeNotifier => _authChangeNotifier;

  // Navigation
  void setIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void updateTabIndex(int newIndex) {
    if (newIndex != _currentTabIndex) {
      _previousTabIndex = _currentTabIndex;
      _currentTabIndex = newIndex;
      notifyListeners();
    }
  }

  // Landing
  void markLandingSeen() {
    _hasSeenLanding = true;
    notifyListeners();
  }

  void setLanguageCode(String code) async {
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }

  Future<void> resetLandingSeen() async {
    _hasSeenLanding = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenLanding', false);
    notifyListeners();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language_code') ?? 'en';
  }

  // Theme
  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');

    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        _themeMode = ThemeMode.system;
    }
  }

  // Announcements settings
  void setShowCountdown(bool value) async {
    _showCountdown = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showCountdown', value);
  }

  void setShowGroupAnnouncements(bool value) async {
    _showGroupAnnouncements = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showGroupAnnouncements', value);
  }

  Future<void> _loadAnnouncementSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showCountdown = prefs.getBool('showCountdown') ?? true;
    _showGroupAnnouncements = prefs.getBool('showGroupAnnouncements') ?? true;
  }

  // Profile
  void setProfile(Profile? profile) {
    _setProfile(profile);
    _cacheProfile(profile);
    _notifyAuthChanged();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _setProfile(null);
    await _cacheProfile(null);
    _notifyAuthChanged();
  }

  void _setProfile(Profile? profile) {
    if (_profile != profile) {
      _profile = profile;
      notifyListeners();
    }
  }

  void _notifyAuthChanged() {
    _authChangeNotifier.value++;
  }

  // Session
  Future<void> _restoreSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        final profile = await ProfileService().getProfile(user.id);
        _setProfile(profile);
        await _cacheProfile(profile);
        await loadUserGroups();
      } else {
        _setProfile(null);
        await _cacheProfile(null);
      }
    } catch (e) {
      debugPrint("Failed to restore session: $e");
      _setProfile(null);
    }
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_displayName');
    final role = prefs.getString('profile_role');

    if (name != null && role != null) {
      _profile = Profile(id: 'cached', displayName: name, role: role);
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

  void updateOneSignalUser() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      OneSignal.login(userId);
    } else {
      OneSignal.logout();
    }
  }

  // Cleanup
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