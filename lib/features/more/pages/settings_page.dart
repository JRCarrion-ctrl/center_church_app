// File: lib/features/more/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:ccf_app/core/graph_provider.dart';
import '../../../app_state.dart';
import '../models/calendar_settings_modal.dart';

// --- Helper Widgets for Settings UI ---

/// Base structure for a settings group (replaces _settingsCard).
class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
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

/// A standard tappable settings tile (replaces _tile).
class _TappableTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _TappableTile({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );
}

/// A standard disabled settings tile (replaces _disabledTile).
class _DisabledTile extends StatelessWidget {
  final String title;

  const _DisabledTile({required this.title});

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        enabled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );
}

/// A settings tile with a switch (replaces _switchTile).
class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );
}

// --- Extracted Modals using RadioGroup Pattern ---

/// Language Selection Modal
class _LanguageSelectorModal extends StatefulWidget {
  const _LanguageSelectorModal();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _LanguageSelectorModal(),
    );
  }

  @override
  State<_LanguageSelectorModal> createState() => __LanguageSelectorModalState();
}

class __LanguageSelectorModalState extends State<_LanguageSelectorModal> {
  late String _selectedLanguage;
  late AppState appState;

  @override
  void initState() {
    super.initState();
    appState = Provider.of<AppState>(context, listen: false);
    _selectedLanguage = appState.languageCode;
  }
  
  void _handleLanguageChange(String? value) {
    if (value != null) {
      appState.setLanguageCode(context, value); 
      setState(() => _selectedLanguage = value); 
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "key_318a".tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          
          // Use RadioGroup for managing selection state (NON-DEPRECATED)
          RadioGroup<String>(
            groupValue: _selectedLanguage,
            onChanged: _handleLanguageChange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  // Radio only needs value; state and handler come from RadioGroup
                  leading: const Radio<String>(value: 'en'), 
                  title: Text("key_347".tr()),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Radio<String>(value: 'es'),
                  title: Text("key_348".tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Font Size Selection Modal
class _FontSizeSelectorModal extends StatefulWidget {
  const _FontSizeSelectorModal();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _FontSizeSelectorModal(),
    );
  }

  @override
  State<_FontSizeSelectorModal> createState() => __FontSizeSelectorModalState();
}

class __FontSizeSelectorModalState extends State<_FontSizeSelectorModal> {
  late double _selectedScale;
  late AppState appState;
  
  final Map<String, double> _options = {
    "key_318b".tr(): 0.85, 
    "key_318c".tr(): 1.0,  
    "key_318d".tr(): 1.15, 
    "key_318e".tr(): 1.3,  
  };

  @override
  void initState() {
    super.initState();
    appState = Provider.of<AppState>(context, listen: false);
    _selectedScale = appState.fontScale;
  }

  void _handleScaleChange(double? value) {
    if (value != null) {
      appState.setFontScale(value);
      setState(() => _selectedScale = value);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Use RadioGroup for managing selection state (NON-DEPRECATED)
          RadioGroup<double>(
            groupValue: _selectedScale,
            onChanged: _handleScaleChange,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _options.entries.map((entry) {
                return ListTile(
                  leading: Radio<double>(value: entry.value),
                  title: Text(entry.key),
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme Mode Selection Group (NON-DEPRECATED)
class _ThemeModeRadioGroup extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode?> onChanged;

  const _ThemeModeRadioGroup({
    required this.currentThemeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Use RadioGroup for managing selection state
    return RadioGroup<ThemeMode>(
      groupValue: currentThemeMode,
      onChanged: onChanged,
      child: Column(
        children: [
          ListTile(
            leading: const Radio<ThemeMode>(value: ThemeMode.system),
            title: Text("set_3a".tr()),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          ListTile(
            leading: const Radio<ThemeMode>(value: ThemeMode.light),
            title: Text("set_3b".tr()),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          ListTile(
            leading: const Radio<ThemeMode>(value: ThemeMode.dark),
            title: Text("set_3c".tr()),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }
}


// --- Main Refactored SettingsPage ---

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = ''; 
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    // Correctly call the two original asynchronous loading methods
    _loadAppVersion(); 
    _loadAutoRefreshSetting();
  }

  // Reloaded implementation of original methods
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  Future<void> _loadAutoRefreshSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = prefs.getBool('auto_refresh_enabled') ?? true;
    });
  }

  // Set Auto Refresh logic (extracted from the inline callback)
  Future<void> _setAutoRefresh(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoRefresh = val);
    await prefs.setBool('auto_refresh_enabled', val);
  }
  
  // Theme Mode Setter
  void _setThemeMode(ThemeMode? mode) {
    if (mode != null) {
      Provider.of<AppState>(context, listen: false).setThemeMode(mode);
    }
  }

  // --- API/Update Check Logic (Kept as private methods in State for GraphQL access) ---

  void _showSnackbar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkForUpdates() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    if (!mounted) return;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final platform = isIOS ? 'ios' : 'android';

    const q = r'''
      query AppVersions($platform: String!) {
        app_versions(where: { platform: { _eq: $platform } }, limit: 1) {
          latest_version
          update_url
        }
      }
    ''';

    try {
      final client = GraphProvider.of(context);
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'platform': platform},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        _showSnackbar('Unable to check for updates.'.tr());
        return;
      }

      final rows = (res.data?['app_versions'] as List<dynamic>? ?? []);
      if (rows.isEmpty) {
        _showSnackbar('Unable to check for updates.'.tr());
        return;
      }

      final latestVersion = rows.first['latest_version'] as String?;
      final updateUrl = rows.first['update_url'] as String?;

      if (latestVersion == null || updateUrl == null) {
        _showSnackbar('Unable to check for updates.'.tr());
        return;
      }

      if (latestVersion.compareTo(currentVersion) > 0) {
        _showUpdateDialog(latestVersion, updateUrl);
      } else {
        _showSnackbar('You’re using the latest version.'.tr());
      }
    } catch (_) {
      _showSnackbar('Unable to check for updates.'.tr());
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


  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeMode = appState.themeMode;

    return Scaffold(
      appBar: AppBar(title: Text("key_319".tr()), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          // Group 1: General
          _SettingsCard(
            title: "set_1".tr(), 
            children: [
              _TappableTile(title: "set_1a".tr(), onTap: () => _LanguageSelectorModal.show(context)),
              _TappableTile(title: "set_1b".tr(), onTap: () => context.push('/more/settings/notifications')),
              _TappableTile(title: "set_1c".tr(), onTap: () => CalendarSettingsModal.show(context)),
              _TappableTile(title: "set_1d".tr(), onTap: () => context.push('/more/settings/data-and-delete')),
            ],
          ),

          // Group 2: About & Support
          _SettingsCard(
            title: "set_2".tr(),
            children: [
              _DisabledTile(title: "set_2a".tr(args: [_appVersion])), 
              _TappableTile(title: "set_2b".tr(), onTap: _checkForUpdates),
              _TappableTile(title: "set_2c".tr(), onTap: () => context.push('/more/settings/contact-support')),
              _TappableTile(title: "set_2d".tr(), onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/terms_and_conditions'))),
              _TappableTile(title: "set_2e".tr(), onTap: () => launchUrl(Uri.parse('https://jrcarrion-ctrl.github.io/CCF-Policies/privacy_policy'))),
            ],
          ),

          // Group 3: Appearance (Theme Mode)
          _SettingsCard(
            title: "set_3".tr(), 
            children: [
              _ThemeModeRadioGroup(
                currentThemeMode: themeMode,
                onChanged: _setThemeMode,
              ),
            ],
          ),

          // Group 4: App Features
          _SettingsCard(
            title: "set_4".tr(), 
            children: [
              _SwitchTile(title: "set_4a".tr(), value: appState.showCountdown, onChanged: appState.setShowCountdown),
              _SwitchTile(title: "set_4b".tr(), value: appState.showGroupAnnouncements, onChanged: appState.setShowGroupAnnouncements),
            ],
          ),

          // Group 5: Accessibility
          _SettingsCard(
            title: "set_5".tr(), 
            children: [
              _TappableTile(title: "set_5a".tr(), onTap: () => _FontSizeSelectorModal.show(context)),
            ],
          ),

          // Group 6: Advanced
          _SettingsCard(
            title: "set_6".tr(), 
            children: [
              // Uses _autoRefresh and _setAutoRefresh (now correctly implemented)
              _SwitchTile(
                title: "set_6a".tr(),
                value: _autoRefresh,
                onChanged: _setAutoRefresh,
              ),
              _TappableTile(title: "set_6b".tr(), onTap: () => context.push('/more/settings/media-settings')),
            ],
          ),
        ],
      ),
    );
  }
}