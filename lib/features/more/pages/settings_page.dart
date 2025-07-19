import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_state.dart';
import '../models/calendar_settings_modal.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to check for updates.')),
      );
      return;
    }

    if (latestVersion.compareTo(currentVersion) > 0) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version ($latestVersion) is available.'),
          actions: [
            TextButton(
              child: const Text('Later'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Update Now'),
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(Uri.parse(updateUrl));
              },
            ),
          ],
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You’re using the latest version.')),
      );
    }
  }


  void _showLanguageSheet() {
    final appState = Provider.of<AppState>(context, listen: false);
    String selected = appState.languageCode;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                  groupValue: selected,
                  onChanged: (val) {
                    if (val != null) {
                      appState.setLanguageCode(val);
                      setModalState(() => selected = val);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Spanish'),
                  value: 'es',
                  groupValue: selected,
                  onChanged: (val) {
                    if (val != null) {
                      appState.setLanguageCode(val);
                      setModalState(() => selected = val);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCalendarSyncModal() {
    CalendarSettingsModal.show(context);
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeMode = appState.themeMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          _settingsCard(title: 'General', children: [
            _tile('Language', onTap: _showLanguageSheet),
            _tile('Notifications', onTap: () {}),
            _tile('Calendar', onTap: _showCalendarSyncModal),
            _tile('Data & Delete Account', onTap: () {context.push('/data-and-delete');}),
          ]),

          _settingsCard(title: 'App Info', children: [
            _disabledTile('Version: $appVersion'),
            _tile('Check for Updates', onTap: () => _checkForUpdates(context)),
            _tile('Contact Support', onTap: () {context.push('/contact-support');}),
            _tile('View Terms and Conditions', onTap: () {}),
            _tile('Privacy Policy', onTap: () {}),
          ]),

          _settingsCard(title: 'Theme', children: [
            _radioTile('System Default', ThemeMode.system, themeMode),
            _radioTile('Light Mode', ThemeMode.light, themeMode),
            _radioTile('Dark Mode', ThemeMode.dark, themeMode),
          ]),

          _settingsCard(title: 'Announcements', children: [
            _switchTile(
              'Show Countdown',
              value: appState.showCountdown,
              onChanged: (val) => appState.setShowCountdown(val),
            ),
            _switchTile(
              'Show Group Announcements in Home',
              value: appState.showGroupAnnouncements,
              onChanged: (val) => appState.setShowGroupAnnouncements(val),
            ),
          ]),

          _settingsCard(title: 'Accessibility', children: [
            _tile('Font Size', onTap: () {}),
            _tile('High Contrast Mode', onTap: () {}),
          ]),

          _settingsCard(title: 'App Behavior', children: [
            _switchTile('Auto-scroll to Latest Message', value: false, onChanged: (_) {}),
          ]),

          _settingsCard(title: 'Media & Background', children: [
            _switchTile('Auto Refresh / Background Sync', value: true, onChanged: (_) {}),
            _tile('Media and Storage Settings', onTap: () {}),
          ]),
        ],
      ),
    );
  }

  void _setThemeMode(ThemeMode? mode) {
    if (mode != null) {
      Provider.of<AppState>(context, listen: false).setThemeMode(mode);
    }
  }

  Widget _settingsCard({required String title, required List<Widget> children}) {
    return Card(
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
  }

  Widget _tile(String title, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _disabledTile(String title) {
    return ListTile(
      title: Text(title),
      enabled: false,
    );
  }

  Widget _switchTile(String title, {required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _radioTile(String title, ThemeMode value, ThemeMode groupValue) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: _setThemeMode,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}