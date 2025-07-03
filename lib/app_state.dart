// File: lib/app_state.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'features/auth/profile.dart';
import 'features/auth/profile_service.dart';

class AppState extends ChangeNotifier {
  int _selectedIndex = 0;
  Profile? _profile;
  bool _isLoading = true;
  bool _initialized = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasSeenLanding = false;

  bool get hasSeenLanding => _hasSeenLanding;

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

  final _authStreamController = StreamController<void>.broadcast();

  AppState() {
    _init();
  }

  // Navigation Index
  int get selectedIndex => _selectedIndex;
  void setIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  // Theme State
  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  // Auth & Profile State
  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _profile != null;
  String? get displayName => _profile?.displayName;
  String? get role => _profile?.role;

  final ValueNotifier<int> _authChangeNotifier = ValueNotifier(0);
  ValueNotifier<int> get authChangeNotifier => _authChangeNotifier;

  void _init() async {
    if (_initialized) return;
    _initialized = true;

    _setLoading(true);
    await _loadTheme();
    await _loadCachedProfile();

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _restoreSession();
    });

    await _restoreSession();
    _setLoading(false);
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

  Future<void> _restoreSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        final profile = await ProfileService().getProfile(user.id);
        _setProfile(profile);
        await _cacheProfile(profile);
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

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _setProfile(null);
    await _cacheProfile(null);
    _notifyAuthChanged();
  }

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

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _notifyAuthChanged() {
     _authChangeNotifier.value++;
  }

  @override
  void dispose() {
    _authStreamController.close();
    super.dispose();
  }
}
