import 'package:flutter/material.dart';
import '../services/version_check_service.dart';
import '../screens/home_screen.dart';

class VersionCheckScreen extends StatefulWidget {
  const VersionCheckScreen({Key? key}) : super(key: key);

  @override
  State<VersionCheckScreen> createState() => _VersionCheckScreenState();
}

class _VersionCheckScreenState extends State<VersionCheckScreen> {
  bool _isChecking = true;
  bool _needsUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentVersion = '';
  String _latestVersion = '';
  String _error = '';
  String _releaseNotes = '';
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final versionInfo = await VersionCheckService.checkVersion();
      
      if (mounted) {
        setState(() {
          _isChecking = false;
          _needsUpdate = versionInfo['needsUpdate'] ?? false;
          _currentVersion = versionInfo['currentVersion'] ?? '';
          _latestVersion = versionInfo['latestVersion'] ?? '';
          _releaseNotes = versionInfo['releaseNotes'] ?? '';
          _downloadUrl = versionInfo['downloadUrl'];
          _error = versionInfo['error'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _error = 'Failed to check version';
        });
      }
    }
  }

  Future<void> _startUpdate() async {
    if (_downloadUrl == null) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await VersionCheckService.downloadAndInstallUpdate(
        _downloadUrl!,
        context,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Checking for updates...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                _error,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkVersion,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_needsUpdate) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade100,
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.system_update,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your version: $_currentVersion\nLatest version: $_latestVersion',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'What\'s New:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _releaseNotes,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isDownloading) ...[
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: _startUpdate,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text(
                              'Update Now',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // If no update needed, proceed to app
    return const HomeScreen();
  }
} 