// File: lib/features/more/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_state.dart';
import '../../../shared/user_roles.dart';
import '../models/calendar_settings_modal.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String appVersion = '';
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadAutoRefreshSetting();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => appVersion = info.version);
  }

  Future<void> _loadAutoRefreshSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoRefresh = prefs.getBool('auto_refresh_enabled') ?? true;
    });
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    if (!context.mounted) return;
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    final res = await Supabase.instance.client
        .from('app_versions')
        .select()
        .eq('platform', platform)
        .single();

    final latestVersion = res['latest_version'] as String?;
    final updateUrl = res['update_url'] as String?;

    if (latestVersion == null || updateUrl == null) {
      _showSnackbar('Unable to check for updates.');
      return;
    }

    if (latestVersion.compareTo(currentVersion) > 0) {
      _showUpdateDialog(latestVersion, updateUrl);
    } else {
      _showSnackbar('You’re using the latest version.');
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('A new version ($version) is available.'),
        actions: [
          TextButton(child: const Text('Later'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Update Now'),
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(url));
            },
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLanguageSheet() {
    final appState = Provider.of<AppState>(context, listen: false);
    String selected = appState.languageCode;

    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (final lang in ['en', 'es'])
                RadioListTile<String>(
                  title: Text(lang == 'en' ? 'English' : 'Spanish'),
                  value: lang,
                  groupValue: selected,
                  onChanged: (val) {
                    if (val != null) {
                      appState.setLanguageCode(val);
                      setModalState(() => selected = val);
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizeModal() {
    final appState = Provider.of<AppState>(context, listen: false);
    final options = {
      'Small': 0.85,
      'Default': 1.0,
      'Large': 1.15,
      'Extra Large': 1.3,
    };
    double selected = appState.fontScale;

    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.entries.map((entry) {
              return RadioListTile<double>(
                title: Text(entry.key),
                value: entry.value,
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) {
                    appState.setFontScale(value);
                    setModalState(() => selected = value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _setThemeMode(ThemeMode? mode) {
    if (mode != null) {
      Provider.of<AppState>(context, listen: false).setThemeMode(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeMode = appState.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          _settingsCard('General', [
            _tile('Language', onTap: _showLanguageSheet),
            _tile('Notifications', onTap: () => context.push('/settings/notifications')),
            _tile('Calendar', onTap: () => CalendarSettingsModal.show(context)),
            _tile('Data & Delete Account', onTap: () => context.push('/data-and-delete')),
          ]),

          _settingsCard('App Info', [
            _disabledTile('Version: $appVersion'),
            _tile('Check for Updates', onTap: () => _checkForUpdates(context)),
            _tile('Contact Support', onTap: () => context.push('/contact-support')),
            _tile('View Terms and Conditions', onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/terms_and_conditions'))),
            _tile('Privacy Policy', onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/privacy_policy'))),
          ]),

          _settingsCard('Theme', [
            _radioTile('System Default', ThemeMode.system, themeMode),
            _radioTile('Light Mode', ThemeMode.light, themeMode),
            _radioTile('Dark Mode', ThemeMode.dark, themeMode),
          ]),

          _settingsCard('Announcements', [
            _switchTile('Show Countdown', appState.showCountdown, appState.setShowCountdown),
            _switchTile('Show Group Announcements in Home', appState.showGroupAnnouncements, appState.setShowGroupAnnouncements),
          ]),

          _settingsCard('Accessibility', [
            _tile('Font Size', onTap: _showFontSizeModal),
          ]),

          _settingsCard('Media & Background', [
            _switchTile(
              'Auto Refresh / Background Sync',
              _autoRefresh,
              (val) async {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _autoRefresh = val);
                await prefs.setBool('auto_refresh_enabled', val);
              },
            ),
            _tile('Media and Storage Settings', onTap: () => context.push('/media-settings')),
          ]),

          if (appState.userRole == UserRole.owner) _settingsCard('Developer Tools', [
            _tile('Debug Panel', onTap: () => context.push('/debug-panel')),
          ]),
        ],
      ),
    );
  }

  Widget _settingsCard(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    ),
  );

  Widget _tile(String title, {VoidCallback? onTap}) => ListTile(
    title: Text(title),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: onTap,
  );

  Widget _disabledTile(String title) => ListTile(title: Text(title), enabled: false);

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    title: Text(title),
    value: value,
    onChanged: onChanged,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
  );

  Widget _radioTile(String title, ThemeMode value, ThemeMode groupValue) => RadioListTile<ThemeMode>(
    title: Text(title),
    value: value,
    groupValue: groupValue,
    onChanged: _setThemeMode,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
  );
}
