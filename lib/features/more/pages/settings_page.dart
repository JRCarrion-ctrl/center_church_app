// File: lib/features/more/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

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
        title: Text("key_315".tr()),
        content: Text("key_316".tr(args: [version])),
        actions: [
          TextButton(child: Text("key_317".tr()), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("key_318".tr()),
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
              Text("key_318a".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (final lang in ['en', 'es'])
                RadioListTile<String>(
                  title: Text(lang == 'en' ? "key_347".tr() : "key_348".tr()),
                  value: lang,
                  groupValue: selected,
                  onChanged: (val) {
                    if (val != null) {
                      appState.setLanguageCode(context, lang);
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
      "key_318b".tr(): 0.85,
      "key_318c".tr(): 1.0,
      "key_318d".tr(): 1.15,
      "key_318e".tr(): 1.3,
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
      appBar: AppBar(title: Text("key_319".tr()), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          _settingsCard("set_1".tr(), [
            _tile("set_1a".tr(), onTap: _showLanguageSheet),
            _tile("set_1b".tr(), onTap: () => context.push('/settings/notifications')),
            _tile("set_1c".tr(), onTap: () => CalendarSettingsModal.show(context)),
            _tile("set_1d".tr(), onTap: () => context.push('/data-and-delete')),
          ]),

          _settingsCard("set_2".tr(), [
            _disabledTile("set_2a".tr(args: [appVersion])),
            _tile("set_2b".tr(), onTap: () => _checkForUpdates(context)),
            _tile("set_2c".tr(), onTap: () => context.push('/contact-support')),
            _tile("set_2d".tr(), onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/terms_and_conditions'))),
            _tile("set_2e".tr(), onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/privacy_policy'))),
          ]),

          _settingsCard("set_3".tr(), [
            _radioTile("set_3a".tr(), ThemeMode.system, themeMode),
            _radioTile("set_3b".tr(), ThemeMode.light, themeMode),
            _radioTile("set_3c".tr(), ThemeMode.dark, themeMode),
          ]),

          _settingsCard("set_4".tr(), [
            _switchTile("set_4a".tr(), appState.showCountdown, appState.setShowCountdown),
            _switchTile("set_4b".tr(), appState.showGroupAnnouncements, appState.setShowGroupAnnouncements),
          ]),

          _settingsCard("set_5".tr(), [
            _tile("set_5a".tr(), onTap: _showFontSizeModal),
          ]),

          _settingsCard("set_6".tr(), [
            _switchTile(
              "set_6a".tr(),
              _autoRefresh,
              (val) async {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _autoRefresh = val);
                await prefs.setBool('auto_refresh_enabled', val);
              },
            ),
            _tile("set_6b".tr(), onTap: () => context.push('/media-settings')),
          ]),

          if (appState.userRole == UserRole.owner) _settingsCard("set_7".tr(), [
            _tile("set_7a".tr(), onTap: () => context.push('/debug-panel')),
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
