import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../constants.dart';
import '../models/transaction.dart' as models;
import 'dart:math';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Add auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Add this at the top of the class
  static const String _settingsCollection = 'app_settings';
  static const String _settingsDocument = 'spin_settings';

  // Add this method to get real-time spin limit updates
  Stream<int> getSpinLimit() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_settingsDocument)
        .snapshots()
        .map((doc) => doc.data()?['maxSpinsPerDay'] ?? AppConstants.maxSpinsPerDay);
  }

  // Add this method to initialize default settings if they don't exist
  Future<void> initializeAppSettings() async {
    final settingsDoc = await _firestore
        .collection(_settingsCollection)
        .doc(_settingsDocument)
        .get();

    if (!settingsDoc.exists) {
      await _firestore
          .collection(_settingsCollection)
          .doc(_settingsDocument)
          .set({
        'maxSpinsPerDay': AppConstants.maxSpinsPerDay,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Generate a unique referral code
  Future<String> _generateUniqueReferralCode() async {
    String referralCode;
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 5;

    do {
      // Generate a code
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(999999);  // Increased range
      referralCode = 'REF${(timestamp % 100000 + random).toString().padLeft(6, '0')}';
      
      print('Attempting to generate unique referral code: $referralCode');

      // Check if code exists
      final existingCode = await _firestore
          .collection('referralCodes')
          .doc(referralCode)
          .get();

      isUnique = !existingCode.exists;
      attempts++;

      if (!isUnique && attempts >= maxAttempts) {
        // If we've tried maximum times, add user-specific suffix
        final userSpecificPart = DateTime.now().microsecondsSinceEpoch.toString().substring(8, 14);
        referralCode = 'REF$userSpecificPart';
        print('Generated fallback referral code: $referralCode');
        isUnique = true;
      }
    } while (!isUnique && attempts < maxAttempts);

    return referralCode;
  }

  // Add this method to generate a random username
  String _generateRandomUsername() {
    final random = Random();
    final adjectives = [
      'Happy', 'Lucky', 'Sunny', 'Cool', 'Super', 'Mega', 'Ultra', 'Hyper',
      'Epic', 'Pro', 'Master', 'Elite', 'Royal', 'Prime', 'Alpha', 'Omega',
      'Brave', 'Swift', 'Smart', 'Clever', 'Wise', 'Noble', 'Grand', 'Bold'
    ];
    final nouns = [
      'Player', 'Gamer', 'Winner', 'Champion', 'Warrior', 'Knight', 'Hero',
      'Legend', 'Star', 'Master', 'Chief', 'Leader', 'King', 'Lord', 'Boss',
      'Ace', 'Eagle', 'Lion', 'Tiger', 'Dragon', 'Phoenix', 'Ninja', 'Samurai'
    ];
    final numbers = random.nextInt(999).toString().padLeft(3, '0');
    
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    
    return '$adjective$noun$numbers';
  }

  // Check if a username is unique
  Future<bool> isUsernameUnique(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  // Add this method to generate a unique username
  Future<String> _generateUniqueUsername() async {
    String username;
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      username = _generateRandomUsername();
      isUnique = await isUsernameUnique(username);
      attempts++;
    } while (!isUnique && attempts < maxAttempts);

    if (!isUnique) {
      // If we couldn't generate a unique username after maxAttempts,
      // append a timestamp to make it unique
      username = '${_generateRandomUsername()}${DateTime.now().millisecondsSinceEpoch}';
    }

    return username;
  }

  // Modify the createOrUpdateUser method to include emailVerified param
  Future<void> createOrUpdateUser(User user, {String? phoneNumber, bool? emailVerified, String? name}) async {
    try {
      print('createOrUpdateUser called for uid: ${user.uid}');
      print('Parameters received - phoneNumber: $phoneNumber, emailVerified: $emailVerified, name: "$name"');
      print('Firebase user displayName: "${user.displayName}"');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        final String referralCode = await _generateUniqueReferralCode();
        final String username = await _generateUniqueUsername();
        print('Creating new user with referral code: $referralCode and username: $username');
        
        // Create referral code document first
        await _firestore.collection('referralCodes').doc(referralCode).set({
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true
        });

        final nameToUse = name ?? user.displayName ?? '';
        print('Using name: "$nameToUse" for Firestore document');
        
        // Then create user document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': nameToUse,
          'email': user.email ?? '',
          'username': username,
          'phoneNumber': phoneNumber ?? '',
          'points': 0,
          'totalEarnings': 0,
          'todayEarning': 0,
          'referralCode': referralCode,
          'referredUsers': [],
          'referredBy': null,
          'referralEarnings': 0,
          'totalReferrals': 0,
          'lastReferralDate': null,
          'upiId': '',
          'lastLoginDate': FieldValue.serverTimestamp(),
          'spinsToday': 0,
          'lastSpinDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': emailVerified ?? false,
          'emailVerifiedAt': null,
        });

        print('User created successfully with referral code: $referralCode and username: $username');
      } else {
        // If the emailVerified parameter is provided, update that field
        if (emailVerified != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'emailVerified': emailVerified,
            'emailVerifiedAt': emailVerified ? FieldValue.serverTimestamp() : null,
          });
        }
        
        await _updateDailyLogin(user.uid);
      }
    } catch (e) {
      print('Error creating/updating user: $e');
      rethrow;
    }
  }

  // Update daily login and give bonus
  Future<void> _updateDailyLogin(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final lastLoginDate = (userData['lastLoginDate'] as Timestamp).toDate();

      if (!_isSameDay(lastLoginDate, DateTime.now())) {
        final random = DateTime.now().millisecondsSinceEpoch % 3 + 1;
        final bonus = random * 1000; // Random bonus between 1000-3000 points

        await _firestore.collection('users').doc(uid).update({
          'lastLoginDate': DateTime.now(),
          'points': FieldValue.increment(bonus),
          'todayEarning': 0,
          'spinsToday': 0,
        });
      }
    } catch (e) {
      print('Error updating daily login: $e');
    }
  }

  // Apply referral code
  Future<bool> applyReferralCode(String referralCode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get current user's document
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!currentUserDoc.exists) throw Exception('User document not found');

      final currentUserData = currentUserDoc.data()!;
      
      // Check if user has already used a referral code
      if (currentUserData['referredBy'] != null) {
        throw Exception('You have already used a referral code');
      }

      // Check if user is trying to use their own referral code
      if (currentUserData['referralCode'] == referralCode) {
        throw Exception('You cannot use your own referral code');
      }

      // Find the referrer user
      final referrerQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        throw Exception('Invalid referral code');
      }

      final referrerDoc = referrerQuery.docs.first;
      final referrerUid = referrerDoc.id;

      // Start a transaction to update both users atomically
      return await _firestore.runTransaction<bool>((transaction) async {
        // Get fresh copies of both documents
        final freshReferrerDoc = await transaction.get(referrerDoc.reference);
        final freshCurrentUserDoc = await transaction.get(currentUserDoc.reference);

        if (!freshReferrerDoc.exists || !freshCurrentUserDoc.exists) {
          throw Exception('User documents not found');
        }

        // Update referrer's document
        transaction.update(referrerDoc.reference, {
          'points': FieldValue.increment(AppConstants.referralBonusPoints),
          'totalEarnings': FieldValue.increment(AppConstants.referralBonusPoints),
          'referralEarnings': FieldValue.increment(AppConstants.referralBonusPoints),
          'totalReferrals': FieldValue.increment(1),
          'referredUsers': FieldValue.arrayUnion([currentUser.uid]),
          'lastReferralDate': FieldValue.serverTimestamp(),
        });

        // Update current user's document
        transaction.update(currentUserDoc.reference, {
          'points': FieldValue.increment(AppConstants.referralBonusPoints),
          'totalEarnings': FieldValue.increment(AppConstants.referralBonusPoints),
          'referredBy': referrerUid,
          'referralAppliedDate': FieldValue.serverTimestamp(),
        });

        // Create a referral record within the transaction
        final referralRef = _firestore.collection('referrals').doc();
        transaction.set(referralRef, {
          'referrerId': referrerUid,
          'refereeId': currentUser.uid,
          'referralCode': referralCode,
          'amount': AppConstants.referralBonusPoints,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'completed'
        });

        return true;
      });
    } catch (e) {
      print('Error applying referral code: $e');
      rethrow;
    }
  }

  // Get user's referral statistics
  Stream<Map<String, dynamic>> getReferralStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => {
              'totalReferrals': doc.data()?['totalReferrals'] ?? 0,
              'referralEarnings': doc.data()?['referralEarnings'] ?? 0,
              'referralCode': doc.data()?['referralCode'] ?? '',
              'referredUsers': doc.data()?['referredUsers'] ?? [],
            });
  }

  // Get referral history
  Stream<List<Map<String, dynamic>>> getReferralHistory(String userId) {
    return _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Submit withdrawal request
  Future<bool> submitWithdrawal(double amount, String upiId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      final points = userData['points'] as int;
      final withdrawalPoints = (amount * AppConstants.pointsToRupeeRatio).round();

      if (points < withdrawalPoints) return false;

      await _firestore.collection('withdrawalRequests').add({
        'uid': user.uid,
        'amount': amount,
        'upiId': upiId,
        'status': 'pending',
        'timestamp': DateTime.now(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'points': FieldValue.increment(-withdrawalPoints),
      });

      return true;
    } catch (e) {
      print('Error submitting withdrawal: $e');
      return false;
    }
  }

  // Get user stream
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) async {
          if (!snapshot.exists) return snapshot;

          final data = snapshot.data() as Map<String, dynamic>;
          final lastSpinDate = (data['lastSpinDate'] as Timestamp?)?.toDate();
          final spinsToday = data['spinsToday'] as int? ?? 0;
          final now = DateTime.now();

          print('\n=== User Stream Update ===');
          print('Last Spin Date: ${lastSpinDate?.toString() ?? 'null'}');
          print('Current Time: ${now.toString()}');
          print('Spins Today: $spinsToday');

          // Check if we need to reset spins
          bool shouldReset = lastSpinDate == null || !_isSameDay(lastSpinDate, now);

          if (shouldReset) {
            print('\n🔄 Reset Triggered:');
            print('- Reason: ${lastSpinDate == null ? 'No last spin date' : 'Different day detected'}');
            print('- Last Spin Date: ${lastSpinDate?.toString() ?? 'null'}');
            print('- Current Date: ${now.toString()}');
            
            try {
              final userRef = _firestore.collection('users').doc(uid);
              
              // Use a batch to ensure atomic updates
              final batch = _firestore.batch();
              
              // Reset everything and give exactly 5 spins
              final updates = {
                'spinsToday': 0,
                'todayEarning': 0,
                'remainingSpins': 5,
                // Only update lastSpinDate if it's null (first time user)
                if (lastSpinDate == null) 'lastSpinDate': Timestamp.now(),
              };

              batch.update(userRef, updates);
              await batch.commit();

              print('✅ Reset successful:');
              print('- Spins reset to: 0');
              print('- Remaining spins set to: 5');
              
              // Get fresh data after the reset
              final freshData = await userRef.get();
              print('📱 UI will update with fresh data');
              return freshData;
            } catch (e) {
              print('❌ Reset failed: $e');
              return snapshot;
            }
          } else {
            // Even if no reset needed, ensure remainingSpins is correct
            final correctRemainingSpins = 5 - spinsToday;
            if (data['remainingSpins'] != correctRemainingSpins) {
              print('\n⚠️ Correcting remaining spins:');
              print('- Current: ${data['remainingSpins']}');
              print('- Should be: $correctRemainingSpins');
              
              final userRef = _firestore.collection('users').doc(uid);
              await userRef.update({
                'remainingSpins': correctRemainingSpins
              });
              return await userRef.get();
            }
          }
          return snapshot;
        })
        .asyncMap((future) => future)
        .handleError((error) {
          print('❌ Stream error: $error');
          return _firestore.collection('users').doc('error_placeholder').snapshots().first;
        });
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Helper methods
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Get user data with improved error handling
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        print('User document does not exist or is null for uid: $uid');
        return null;
      }

      return docSnapshot.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error retrieving user data: $e');
      return null;
    }
  }

  // Update user data with improved error handling and type checking
  Future<bool> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Type checking for DateTime fields
      if (data.containsKey('lastLoginDate') && data['lastLoginDate'] is DateTime) {
        data['lastLoginDate'] = Timestamp.fromDate(data['lastLoginDate'] as DateTime);
      }
      if (data.containsKey('lastSpinDate') && data['lastSpinDate'] is DateTime) {
        data['lastSpinDate'] = Timestamp.fromDate(data['lastSpinDate'] as DateTime);
      }

      await _firestore.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  Future<List<models.PaymentTransaction>> getTransactionHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => models.PaymentTransaction.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  Future<models.PaymentTransaction> createTransaction({
    required String userId,
    required double amount,
    required String type,
    String? upiId,
  }) async {
    try {
      final docRef = _firestore.collection('transactions').doc();
      final now = DateTime.now();
      
      await docRef.set({
        'userId': userId,
        'amount': amount,
        'type': type,
        'status': 'pending',
        'upiId': upiId,
        'createdAt': now.toIso8601String(),
      });
      
      final doc = await docRef.get();
      return models.PaymentTransaction.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error creating transaction: $e');
      rethrow;
    }
  }

  Future<void> updateTransactionStatus(String transactionId, String status) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': status,
      });
    } catch (e) {
      print('Error updating transaction status: $e');
      throw Exception('Failed to update transaction status');
    }
  }

  // Create referral record
  Future<void> createReferralRecord({
    required String referrerId,
    required String refereeId,
    required String referralCode,
    required int amount,
  }) async {
    try {
      await _firestore.collection('referrals').add({
        'referrerId': referrerId,
        'refereeId': refereeId,
        'referralCode': referralCode,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed'
      });
    } catch (e) {
      print('Error creating referral record: $e');
      rethrow;
    }
  }

  // Get referrals made by user
  Stream<List<Map<String, dynamic>>> getReferralsMade(String userId) {
    return _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'refereeId': doc.data()['refereeId'],
                  'referralCode': doc.data()['referralCode'],
                  'amount': doc.data()['amount'],
                  'createdAt': doc.data()['createdAt'],
                  'status': doc.data()['status'],
                })
            .toList());
  }

  // Get referrals received by user
  Stream<List<Map<String, dynamic>>> getReferralsReceived(String userId) {
    return _firestore
        .collection('referrals')
        .where('refereeId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'referrerId': doc.data()['referrerId'],
                  'referralCode': doc.data()['referralCode'],
                  'amount': doc.data()['amount'],
                  'createdAt': doc.data()['createdAt'],
                  'status': doc.data()['status'],
                })
            .toList());
  }

  // Get referral statistics
  Future<Map<String, dynamic>> getReferralStatistics(String userId) async {
    try {
      final referralsMade = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();

      final referralsReceived = await _firestore
          .collection('referrals')
          .where('refereeId', isEqualTo: userId)
          .get();

      return {
        'totalReferralsMade': referralsMade.docs.length,
        'totalReferralsReceived': referralsReceived.docs.length,
        'totalEarningsFromReferrals': referralsMade.docs.fold<int>(
            0, (sum, doc) => sum + (doc.data()['amount'] as int)),
      };
    } catch (e) {
      print('Error getting referral statistics: $e');
      return {
        'totalReferralsMade': 0,
        'totalReferralsReceived': 0,
        'totalEarningsFromReferrals': 0,
      };
    }
  }

  // Get transactions for a user
  Stream<List<models.PaymentTransaction>> getTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => models.PaymentTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get a single transaction by ID
  Future<models.PaymentTransaction?> getTransactionById(String transactionId) async {
    final doc = await _firestore.collection('transactions').doc(transactionId).get();
    if (!doc.exists) return null;
    return models.PaymentTransaction.fromMap(doc.data()!, doc.id);
  }

  // Enhanced method to ensure daily values are reset
  Future<void> ensureDailyReset(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final lastSpinDate = (data['lastSpinDate'] as Timestamp?)?.toDate();
      final lastLoginDate = (data['lastLoginDate'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      if (lastSpinDate == null || 
          lastLoginDate == null || 
          !_isSameDay(lastSpinDate, now) || 
          !_isSameDay(lastLoginDate, now)) {
        await _firestore.collection('users').doc(uid).update({
          'spinsToday': 0,
          'todayEarning': 0,
          'lastLoginDate': Timestamp.now(),
          'lastSpinDate': lastSpinDate == null ? Timestamp.now() : lastSpinDate,
        });
        print('Daily values reset successfully');
      }
    } catch (e) {
      print('Error ensuring daily reset: $e');
      rethrow;
    }
  }

  // Force reset spins for a user
  Future<void> forceResetSpins(String uid) async {
    try {
      print('\n🔄 Force Reset Spins Triggered');
      
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      // Use a batch to ensure atomic updates
      final batch = _firestore.batch();
      
      final updates = {
        'spinsToday': 0,
        'todayEarning': 0,
        'remainingSpins': 5,
        'lastSpinDate': null,  // Set to null to trigger reset on next check
      };

      batch.update(userRef, updates);
      await batch.commit();

      print('✅ Force reset successful:');
      print('- Spins reset to: 0');
      print('- Remaining spins set to: 5');
      print('- Last spin date cleared');

      // Get fresh data to trigger stream update
      await userRef.get();
      print('📱 UI will update with fresh data');
    } catch (e) {
      print('❌ Force reset failed: $e');
      throw e;
    }
  }

  // Update points after spin
  Future<void> updatePointsAfterSpin(int points) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userRef = _firestore.collection('users').doc(user.uid);
      print('\n=== Starting Spin Update ===');

      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception('User document not found');

        final data = userDoc.data()!;
        final currentPoints = data['points'] as int? ?? 0;
        final spinsToday = data['spinsToday'] as int? ?? 0;
        final currentTodayEarning = data['todayEarning'] as int? ?? 0;
        final remainingSpins = data['remainingSpins'] as int? ?? 5;
        final lastSpinDate = (data['lastSpinDate'] as Timestamp?)?.toDate();

        print('\nCurrent Values:');
        print('- Points: $currentPoints');
        print('- Spins used today: $spinsToday');
        print('- Today\'s earnings: $currentTodayEarning');
        print('- Remaining spins: $remainingSpins');
        print('- Last spin date: ${lastSpinDate?.toString() ?? 'null'}');

        final now = DateTime.now();
        final shouldResetSpins = lastSpinDate == null || !_isSameDay(lastSpinDate, now);

        // Calculate new values
        final updatedSpinsToday = shouldResetSpins ? 1 : spinsToday + 1;
        final updatedRemainingSpins = shouldResetSpins ? 4 : remainingSpins - 1;

        if (updatedRemainingSpins < 0) {
          throw Exception('No spins remaining');
        }

        print('\nSpin Update Decision:');
        print('- Should reset? $shouldResetSpins');
        print('- Updating spins used from $spinsToday to $updatedSpinsToday');
        print('- Remaining spins will be: $updatedRemainingSpins');

        final updates = {
          'points': currentPoints + points,
          'todayEarning': shouldResetSpins ? points : currentTodayEarning + points,
          'spinsToday': updatedSpinsToday,
          'remainingSpins': updatedRemainingSpins,
          'lastSpinDate': FieldValue.serverTimestamp(),
          'totalEarnings': FieldValue.increment(points),
        };

        transaction.update(userRef, updates);
        success = true;
        print('\n✅ Transaction completed successfully');
        print('- New spins used count: $updatedSpinsToday');
        print('- Remaining spins: $updatedRemainingSpins');
        print('- Points added: $points');
      });

      if (success) {
        // Force an immediate update to the stream
        await userRef.get();
        print('\n📱 UI will update with fresh data');
      }
    } catch (e) {
      print('\n❌ Error in spin update: $e');
      rethrow;
    }
  }

  // Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Force refresh user data
  Future<void> refreshUserData(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'spinsToday': 0,
        'todayEarning': 0,
        'lastLoginDate': Timestamp.now(),
        'lastSpinDate': Timestamp.now(),
      });
      print('User data refreshed successfully');
    } catch (e) {
      print('Error refreshing user data: $e');
      throw e;
    }
  }

  // Check and reset spins on app start
  Future<void> checkAndResetSpinsOnStart(String uid) async {
    try {
      print('\n=== Checking Spins on App Start ===');
      
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final data = userDoc.data()!;
      final lastSpinDate = (data['lastSpinDate'] as Timestamp?)?.toDate();
      final spinsToday = data['spinsToday'] as int? ?? 0;
      final remainingSpins = data['remainingSpins'] as int? ?? 5;
      final now = DateTime.now();

      print('\nCurrent Values:');
      print('- Last Spin Date: ${lastSpinDate?.toString() ?? 'null'}');
      print('- Spins Today: $spinsToday');
      print('- Remaining Spins: $remainingSpins');

      // Check if we need to reset
      final shouldReset = lastSpinDate == null || !_isSameDay(lastSpinDate, now);

      if (shouldReset) {
        print('\n🔄 Reset Required:');
        print('- Reason: ${lastSpinDate == null ? 'No last spin date' : 'Different day'}');
        
        // Use a batch to ensure atomic updates
        final batch = _firestore.batch();
        
        final updates = {
          'spinsToday': 0,
          'todayEarning': 0,
          'remainingSpins': 5,
          // Only update lastSpinDate if it's null
          if (lastSpinDate == null) 'lastSpinDate': Timestamp.now(),
        };

        batch.update(userRef, updates);
        await batch.commit();

        print('✅ Reset successful:');
        print('- Spins reset to: 0');
        print('- Remaining spins set to: 5');
        
        // Get fresh data to trigger stream update
        await userRef.get();
        print('📱 UI will update with fresh data');
      } else {
        print('✓ No reset needed - same day');
        
        // Even if no reset needed, ensure remainingSpins is correct
        final correctRemainingSpins = 5 - spinsToday;
        if (remainingSpins != correctRemainingSpins) {
          print('\n⚠️ Correcting remaining spins:');
          print('- Current: $remainingSpins');
          print('- Should be: $correctRemainingSpins');
          
          await userRef.update({
            'remainingSpins': correctRemainingSpins
          });
          print('✅ Correction applied');
        }
      }
    } catch (e) {
      print('❌ Check and reset failed: $e');
      throw e;
    }
  }

  // Request account deletion
  Future<Map<String, dynamic>> requestAccountDeletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }
      
      final userId = user.uid;
      print('\n=== Processing Account Deletion Request ===');
      
      // Create a deletion request in Firestore
      await _firestore.collection('deletionRequests').doc(userId).set({
        'userId': userId,
        'requestDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'completed': false
      });
      
      // Get the user's email for notification purposes
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userEmail = userDoc.data()?['email'];
        
        // Add a note to the user document that deletion was requested
        await _firestore.collection('users').doc(userId).update({
          'deletionRequested': true,
          'deletionRequestDate': FieldValue.serverTimestamp()
        });
        
        print('✅ Account deletion request created for user: $userId');
        return {'success': true, 'message': 'Your account is scheduled for deletion within 30 days.'};
      } else {
        print('❌ User document not found');
        return {'success': false, 'message': 'User not found'};
      }
    } catch (e) {
      print('❌ Error requesting account deletion: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
  
  // Check if deletion is requested
  Future<bool> isAccountDeletionRequested() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final userId = user.uid;
      final requestDoc = await _firestore.collection('deletionRequests').doc(userId).get();
      return requestDoc.exists;
    } catch (e) {
      print('❌ Error checking deletion request: $e');
      return false;
    }
  }
  
  // Cancel account deletion request
  Future<Map<String, dynamic>> cancelAccountDeletionRequest() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }
      
      final userId = user.uid;
      
      // Delete the deletion request
      await _firestore.collection('deletionRequests').doc(userId).delete();
      
      // Update the user document
      await _firestore.collection('users').doc(userId).update({
        'deletionRequested': false,
        'deletionRequestDate': null
      });
      
      print('✅ Account deletion request canceled for user: $userId');
      return {'success': true, 'message': 'Account deletion request has been canceled.'};
    } catch (e) {
      print('❌ Error canceling deletion request: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Admin method: actually delete user account and all associated data
  Future<bool> executeAccountDeletion(String userId) async {
    try {
      print('\n=== Executing Account Deletion ===');
      
      // Get a batch for atomic operations
      final batch = _firestore.batch();
      
      // 1. Delete user's transactions
      final transactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in transactions.docs) {
        batch.delete(doc.reference);
      }
      print('- Marked ${transactions.docs.length} transactions for deletion');
      
      // 2. Delete user's referrals (both as referrer and referee)
      final referralsMade = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();
      
      for (var doc in referralsMade.docs) {
        batch.delete(doc.reference);
      }
      print('- Marked ${referralsMade.docs.length} referrals made for deletion');
      
      final referralsReceived = await _firestore
          .collection('referrals')
          .where('refereeId', isEqualTo: userId)
          .get();
      
      for (var doc in referralsReceived.docs) {
        batch.delete(doc.reference);
      }
      print('- Marked ${referralsReceived.docs.length} referrals received for deletion');
      
      // 3. Delete user's support tickets
      final tickets = await _firestore
          .collection('supportTickets')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in tickets.docs) {
        batch.delete(doc.reference);
      }
      print('- Marked ${tickets.docs.length} support tickets for deletion');
      
      // 4. Update the deletion request
      batch.update(_firestore.collection('deletionRequests').doc(userId), {
        'status': 'completed',
        'completed': true,
        'executionDate': FieldValue.serverTimestamp()
      });
      
      // 5. Delete the user document last
      batch.delete(_firestore.collection('users').doc(userId));
      print('- Marked user document for deletion');
      
      // Execute the batch
      await batch.commit();
      print('✅ Database cleanup completed for user: $userId');
      
      // 6. Delete the Firebase Authentication user
      // This should be done by an admin using the Firebase Admin SDK
      // For client-side, we can only mark the account for deletion
      
      return true;
    } catch (e) {
      print('❌ Error executing account deletion: $e');
      return false;
    }
  }

  // Add extra spin after watching 5 ads
  Future<void> addExtraSpin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection('users').doc(user.uid).update({
        'spinsToday': FieldValue.increment(-1), // Decrease spins used today by 1 to give an extra spin
      });

      print('Extra spin added successfully');
    } catch (e) {
      print('Error adding extra spin: $e');
      rethrow;
    }
  }
} 