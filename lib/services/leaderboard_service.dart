import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateLeaderboard({
    required String userName,
    required int totalStars,
    required int highestLevel,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get the user's profile data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String displayName = 'Player';
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        displayName = userData?['username'] ?? 'Player';
      }

      await _firestore
          .collection('leaderboards')
          .doc('zip_game')
          .collection('rankings')
          .doc(userId)
          .set({
        'userId': userId,
        'userName': displayName, // Use the username from profile
        'totalStars': totalStars,
        'highestLevel': highestLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getLeaderboard() {
    return _firestore
        .collection('leaderboards')
        .doc('zip_game')
        .collection('rankings')
        .orderBy('highestLevel', descending: true)
        .orderBy('totalStars', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'userId': data['userId'] as String,
              'userName': data['userName'] as String,
              'totalStars': data['totalStars'] as int,
              'highestLevel': data['highestLevel'] as int,
              'lastUpdated': data['lastUpdated'] as Timestamp?,
            };
          }).toList();
        });
  }

  Future<int> getUserRank(String userId) async {
    try {
      final rankings = await _firestore
          .collection('leaderboards')
          .doc('zip_game')
          .collection('rankings')
          .orderBy('highestLevel', descending: true)
          .orderBy('totalStars', descending: true)
          .get();

      final index = rankings.docs.indexWhere((doc) => doc.id == userId);
      return index + 1;
    } catch (e) {
      print('Error getting user rank: $e');
      return 0;
    }
  }
} 