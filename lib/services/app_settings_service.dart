import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AppSettingsService {
  // Singleton instance
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'app_settings';
  final String _document = 'settings';

  // Core Methods
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_document).get();
      if (!doc.exists) {
        await _initializeDefaultSettings();
        return await getAppSettings();
      }
      return doc.data() ?? {};
    } catch (e) {
      print('Error fetching app settings: $e');
      return {};
    }
  }

  Stream<DocumentSnapshot> appSettingsStream() {
    return _firestore.collection(_collection).doc(_document).snapshots();
  }

  Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    try {
      await _firestore.collection(_collection).doc(_document).set(
        settings,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating app settings: $e');
      throw Exception('Failed to update app settings');
    }
  }

  Future<void> updateSpecificSettings(String key, dynamic value) async {
    try {
      await _firestore.collection(_collection).doc(_document).update({
        key: value,
      });
    } catch (e) {
      print('Error updating specific setting: $e');
      throw Exception('Failed to update setting: $key');
    }
  }

  // Specialized Methods
  Future<void> toggleMaintenanceMode(bool enabled) async {
    try {
      await updateSpecificSettings('maintenanceMode', enabled);
    } catch (e) {
      print('Error toggling maintenance mode: $e');
      throw Exception('Failed to toggle maintenance mode');
    }
  }

  Future<void> updateAppVersion({
    required String version,
    required int buildNumber,
    required bool forceUpdate,
  }) async {
    try {
      await updateSpecificSettings('appVersion', {
        'version': version,
        'buildNumber': buildNumber,
        'forceUpdate': forceUpdate,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating app version: $e');
      throw Exception('Failed to update app version');
    }
  }

  // Private Methods
  Future<void> _initializeDefaultSettings() async {
    final defaultSettings = {
      'maintenanceMode': false,
      'appVersion': {
        'version': '1.0.0',
        'buildNumber': 1,
        'forceUpdate': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection(_collection).doc(_document).set(defaultSettings);
    } catch (e) {
      print('Error initializing default settings: $e');
      throw Exception('Failed to initialize default settings');
    }
  }
} 