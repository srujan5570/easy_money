import 'package:flutter/material.dart';
import '../services/ads_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdsSettingsWidget extends StatefulWidget {
  const AdsSettingsWidget({Key? key}) : super(key: key);

  @override
  State<AdsSettingsWidget> createState() => _AdsSettingsWidgetState();
}

class _AdsSettingsWidgetState extends State<AdsSettingsWidget> {
  bool _isReverseMode = false;
  int _patchVersion = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isReverseMode = _prefs?.getBool('use_reverse') ?? false;
      _patchVersion = _prefs?.getInt('patch_version') ?? 0;
    });
  }

  Future<void> _resetDeviceId() async {
    _prefs?.remove('device_id');
    _prefs?.remove('last_rotation');
    setState(() {
      _patchVersion = 0;
      _prefs?.setInt('patch_version', 0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device ID reset successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ad Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Reverse Mode'),
              subtitle: const Text('Enable reverse mode for ad requests'),
              value: _isReverseMode,
              onChanged: (value) {
                setState(() {
                  _isReverseMode = value;
                  AdsService.setReverseMode(value);
                });
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Patch Version'),
              subtitle: Text('Current version: $_patchVersion'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _patchVersion = (_patchVersion + 1) % 100;
                    _prefs?.setInt('patch_version', _patchVersion);
                  });
                },
              ),
            ),
            const Divider(),
            Center(
              child: ElevatedButton(
                onPressed: _resetDeviceId,
                child: const Text('Reset Device ID'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 