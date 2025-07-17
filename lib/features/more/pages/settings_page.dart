import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';

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
                // Add more languages here
              ],
            ),
          ),
        );
      },
    );
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
    final isOwner = appState.role == 'Owner';

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
            _tile('Calendar Sync', onTap: () {}),
            _tile('Privacy', onTap: () {}),
            _tile('Data & Delete Account', onTap: () {}),
          ]),

          _settingsCard(title: 'App Info', children: [
            _disabledTile('Version: $appVersion'),
            _tile('Check for Updates', onTap: () {}),
            _tile('Contact Support', onTap: () {}),
            _tile('View Terms and Conditions', onTap: () {}),
            _tile('Privacy Policy', onTap: () {}),
          ]),

          _settingsCard(title: 'Theme', children: [
            _radioTile('System Default', ThemeMode.system, themeMode),
            _radioTile('Light Mode', ThemeMode.light, themeMode),
            _radioTile('Dark Mode', ThemeMode.dark, themeMode),
          ]),

          _settingsCard(title: 'Security', children: [
            _switchTile('Enable Biometric Login', value: false, onChanged: (_) {}),
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


          _settingsCard(title: 'Link Settings', children: [
            _tile('Default Link Opening', onTap: () {}),
          ]),

          _settingsCard(title: 'Accessibility', children: [
            _tile('Font Size', onTap: () {}),
            _tile('High Contrast Mode', onTap: () {}),
          ]),

          _settingsCard(title: 'Quiet Hours', children: [
            _tile('Notification Quiet Hours', onTap: () {}),
          ]),

          _settingsCard(title: 'App Behavior', children: [
            _switchTile('Remember Last Tab', value: true, onChanged: (_) {}),
            _switchTile('Auto-scroll to Latest Message', value: false, onChanged: (_) {}),
          ]),

          _settingsCard(title: 'Media & Background', children: [
            _switchTile('Auto Refresh / Background Sync', value: true, onChanged: (_) {}),
            _tile('Media and Storage Settings', onTap: () {}),
          ]),

          if (isOwner)
            _settingsCard(title: 'Developer Tools', children: [
              _tile('Show Logs / Debug Tools', onTap: () {}),
              _tile('Run Diagnostics', onTap: () {}),
              _tile('Reset App State', onTap: () {}),
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
