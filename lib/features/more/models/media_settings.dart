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
    
    // Set both provider states based on local storage
    appState.setWifiOnlyMediaDownload(prefs.getBool(_wifiKey) ?? true);
    appState.setAutoDownloadImages(prefs.getBool(_imageKey) ?? true);
    
    // Trigger the UI build now that the global state is hydrated
    setState(() {
      _prefsLoaded = true;
    });
  }

  Future<void> _updateImagePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_imageKey, value);
    if (mounted) {
      // Tell the global state to update
      Provider.of<AppState>(context, listen: false).setAutoDownloadImages(value);
    }
  }

  Future<void> _updateWifiPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiKey, value);
    if (mounted) {
      Provider.of<AppState>(context, listen: false).setWifiOnlyMediaDownload(value);
    }
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

    if (confirmed != true) return;

    setState(() => _clearingCache = true);
    
    await MediaCacheService().clearCache();
    
    if (!mounted) return;
    
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("key_222".tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global state
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: Text("key_223".tr())),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: Text("key_224".tr()),
                  // Now directly reading from the AppState!
                  value: appState.autoDownloadImages,
                  onChanged: _clearingCache ? null : _updateImagePreference,
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