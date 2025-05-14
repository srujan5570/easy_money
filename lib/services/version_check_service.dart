import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class VersionCheckService {
  // Replace these with your GitHub repository details
  static const String GITHUB_OWNER = "srujan5570";
  static const String GITHUB_REPO = "easy_money";
  static const String GITHUB_API_URL = "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest";
  
  static Future<Map<String, dynamic>> checkVersion() async {
    try {
      // Get current installed version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      
      print('Current installed version: $currentVersion');
      print('Checking GitHub URL: $GITHUB_API_URL');
      
      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(GITHUB_API_URL),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      
      print('GitHub API Response Status: ${response.statusCode}');
      print('GitHub API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].replaceAll('v', ''); // Remove 'v' prefix if present
        print('Latest version from GitHub: $latestVersion');
        
        // Log available assets
        print('Available assets:');
        for (var asset in data['assets']) {
          print('- ${asset['name']}: ${asset['browser_download_url']}');
        }
        
        final apkAsset = data['assets'].firstWhere(
          (asset) => asset['name'].toString().endsWith('.apk'),
          orElse: () => null,
        );
        
        if (apkAsset == null) {
          print('No APK found in release assets');
          throw 'No APK found in latest release';
        }
        
        final downloadUrl = apkAsset['browser_download_url'];
        print('APK download URL: $downloadUrl');
        
        bool needsUpdate = _compareVersions(currentVersion, latestVersion);
        print('Needs update: $needsUpdate');
        
        return {
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'needsUpdate': needsUpdate,
          'downloadUrl': downloadUrl,
          'releaseNotes': data['body'] ?? 'No release notes available',
        };
      } else {
        print('Failed to fetch version. Status code: ${response.statusCode}');
        throw 'Failed to fetch latest version';
      }
    } catch (e) {
      print('Error checking version: $e');
      return {
        'error': 'Failed to check version: $e',
        'needsUpdate': false,
      };
    }
  }
  
  static bool _compareVersions(String current, String latest) {
    try {
      // Normalize version strings to handle potential 'v' prefix
      current = current.toLowerCase().replaceAll('v', '').trim();
      latest = latest.toLowerCase().replaceAll('v', '').trim();
      
      // Split version strings into parts
      List<int> currentParts = current.split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
      List<int> latestParts = latest.split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
      
      // Pad shorter version with zeros
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);
      
      // Compare version parts
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < latestParts[i]) {
          return true; // Needs update
        } else if (currentParts[i] > latestParts[i]) {
          return false; // Current version is higher
        }
      }
      return false; // Versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false; // On error, don't suggest update
    }
  }
  
  static Future<void> downloadAndInstallUpdate(
    String downloadUrl,
    BuildContext context,
    Function(double) onProgress,
  ) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/update.apk';
      
      print('Downloading update to: $savePath');
      
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );
      
      // Install the APK
      final file = File(savePath);
      if (await file.exists()) {
        print('APK file downloaded successfully');
        
        // Get the application ID
        final packageInfo = await PackageInfo.fromPlatform();
        final authority = '${packageInfo.packageName}.fileprovider';
        
        // Create content URI using FileProvider
        final apkUri = Uri.parse('content://$authority/updates/${file.path.split('/').last}');
        print('FileProvider URI: $apkUri');
        
        // Create intent to install the APK
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            flags: [0x10000000, 0x00000001], // FLAG_ACTIVITY_NEW_TASK | FLAG_GRANT_READ_URI_PERMISSION
            type: 'application/vnd.android.package-archive',
            data: apkUri.toString(),
          );
          
          await intent.launch();
        } else {
          // Fallback for non-Android platforms
          await launchUrl(
            apkUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
        }
      } else {
        throw 'Downloaded file not found';
      }
    } catch (e) {
      print('Error downloading update: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }
} 