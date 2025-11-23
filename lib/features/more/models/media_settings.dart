import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../groups/media_cache_service.dart';

class MediaSettingsPage extends StatefulWidget {
  const MediaSettingsPage({super.key});

  @override
  State<MediaSettingsPage> createState() => _MediaSettingsPageState();
}

class _MediaSettingsPageState extends State<MediaSettingsPage> {
  static const _imageKey = 'autoDownloadImages';
  static const _wifiKey = 'mediaWifiOnly';

  bool _autoDownloadImages = true;
  bool _prefsLoaded = false;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _autoDownloadImages = prefs.getBool(_imageKey) ?? true;
      appState.setWifiOnlyMediaDownload(prefs.getBool(_wifiKey) ?? true);
      _prefsLoaded = true;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == _imageKey) _autoDownloadImages = value;
    });
  }

  Future<void> _updateWifiPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiKey, value);
    if (mounted) Provider.of<AppState>(context, listen: false).setWifiOnlyMediaDownload(value);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_218".tr()),
        content: Text("key_219".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_220".tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("key_221".tr())),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _clearingCache = true);
      await MediaCacheService().clearCache();
      if (!mounted) return;
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_222".tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (!_prefsLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("key_223".tr())),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text("key_224".tr()),
            value: _autoDownloadImages,
            onChanged: _clearingCache ? null : (val) => _updatePreference(_imageKey, val),
          ),
          SwitchListTile(
            title: Text("key_226".tr()),
            subtitle: Text("key_227".tr()),
            value: appState.wifiOnlyMediaDownload,
            onChanged: _clearingCache ? null : _updateWifiPreference,
          ),
          ListTile(
            title: Text("key_228".tr()),
            trailing: _clearingCache
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
            onTap: _clearingCache ? null : _clearCache,
          ),
        ],
      ),
    );
  }
}