import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveLevelProgress({
    required int level,
    required int stars,
    required int timeSeconds,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get existing data first
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('game_progress')
          .doc('zip_game')
          .get();

      final existingData = doc.data();
      final existingLevels = existingData?['levels'] as Map<String, dynamic>? ?? {};
      
      // Only update if new progress is better
      final existingLevel = existingLevels[level.toString()] as Map<String, dynamic>?;
      final existingStars = existingLevel?['stars'] as int? ?? 0;
      final existingTime = existingLevel?['bestTime'] as int? ?? 999999;

      if (stars >= existingStars || timeSeconds < existingTime) {
        existingLevels[level.toString()] = {
          'stars': stars > existingStars ? stars : existingStars,
          'bestTime': timeSeconds < existingTime ? timeSeconds : existingTime,
          'completedAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('game_progress')
            .doc('zip_game')
            .set({
          'levels': existingLevels,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastPlayedLevel': level,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving level progress: $e');
    }
  }

  Future<Map<String, dynamic>?> getLevelProgress() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('game_progress')
          .doc('zip_game')
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      // Update last access time
      await doc.reference.update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });

      return data['levels'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting level progress: $e');
      return null;
    }
  }

  Future<int?> getLastPlayedLevel() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('game_progress')
          .doc('zip_game')
          .get();

      return doc.data()?['lastPlayedLevel'] as int?;
    } catch (e) {
      print('Error getting last played level: $e');
      return null;
    }
  }

  Future<void> updateTotalEarnings(int additionalPoints) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get the user document reference
      final userRef = _firestore.collection('users').doc(userId);
      
      // Get current earnings
      final userDoc = await userRef.get();
      final currentEarnings = userDoc.data()?['totalEarnings'] as int? ?? 0;
      
      // Update total earnings
      await userRef.set({
        'totalEarnings': currentEarnings + additionalPoints,
        'lastEarningsUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Also update in game progress
      await userRef.collection('game_progress').doc('zip_game').set({
        'totalEarnings': currentEarnings + additionalPoints,
        'lastEarningsUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating total earnings: $e');
    }
  }

  Future<int> getTotalEarnings() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      return userDoc.data()?['totalEarnings'] as int? ?? 0;
    } catch (e) {
      print('Error getting total earnings: $e');
      return 0;
    }
  }
} 