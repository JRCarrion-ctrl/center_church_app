import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../../app_state.dart';
import '../../groups/media_cache_service.dart';

class MediaSettingsPage extends StatefulWidget {
  const MediaSettingsPage({super.key});

  @override
  State<MediaSettingsPage> createState() => _MediaSettingsPageState();
}

class _MediaSettingsPageState extends State<MediaSettingsPage> {
  static const _imageKey = 'autoDownloadImages';
  static const _videoKey = 'autoDownloadVideos';
  static const _wifiKey = 'mediaWifiOnly';

  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = false;
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
      _autoDownloadVideos = prefs.getBool(_videoKey) ?? false;
      appState.setWifiOnlyMediaDownload(prefs.getBool(_wifiKey) ?? true);
      _prefsLoaded = true;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == _imageKey) _autoDownloadImages = value;
      if (key == _videoKey) _autoDownloadVideos = value;
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
        title: const Text('Clear Cached Media?'),
        content: const Text('This will delete all downloaded images and videos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _clearingCache = true);
      await MediaCacheService().clearCache();
      if (!mounted) return;
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media cache cleared.')),
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
      appBar: AppBar(title: const Text('Media & Storage')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Auto-download Images'),
            value: _autoDownloadImages,
            onChanged: _clearingCache ? null : (val) => _updatePreference(_imageKey, val),
          ),
          SwitchListTile(
            title: const Text('Auto-download Videos'),
            value: _autoDownloadVideos,
            onChanged: _clearingCache ? null : (val) => _updatePreference(_videoKey, val),
          ),
          SwitchListTile(
            title: const Text('Wi-Fi Only'),
            subtitle: const Text('Download media only on Wi-Fi'),
            value: appState.wifiOnlyMediaDownload,
            onChanged: _clearingCache ? null : _updateWifiPreference,
          ),
          ListTile(
            title: const Text('Clear Cached Media'),
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