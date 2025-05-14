import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/email_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  UserModel? _user;
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Map to store OTP codes with email addresses
  final Map<String, String> _emailOtpCodes = {};
  
  // Email verification status
  bool _isEmailVerified = false;
  bool get isEmailVerified => _isEmailVerified;

  bool get isLoading => _isLoading;
  UserModel? get user => _user;
  bool get isLoggedIn => _auth.currentUser != null;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    _auth.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser == null) {
        _user = null;
        _userSubscription?.cancel();
      } else {
        _subscribeToUserUpdates(firebaseUser.uid);
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void _subscribeToUserUpdates(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            _user = UserModel.fromMap(snapshot.data()!);
            
            // Check and reset spins when user data is first loaded
            try {
              final firebaseService = FirebaseService();
              await firebaseService.checkAndResetSpinsOnStart(uid);
            } catch (e) {
              print('Error checking spins on start: $e');
            }
            
            notifyListeners();
          }
        });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateUserPoints(int points) async {
    if (_user == null) return;
    
    final userRef = _firestore.collection('users').doc(_user!.uid);
    
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      final currentPoints = userDoc.data()?['points'] as int? ?? 0;
      final spinsToday = userDoc.data()?['spinsToday'] as int? ?? 0;
      final currentTodayEarning = userDoc.data()?['todayEarning'] as int? ?? 0;
      final currentTotalEarnings = userDoc.data()?['totalEarnings'] as int? ?? 0;
      final remainingSpins = userDoc.data()?['remainingSpins'] as int? ?? 5;

      // Calculate new remaining spins
      final newRemainingSpins = remainingSpins > 0 ? remainingSpins - 1 : 0;

      transaction.update(userRef, {
        'points': currentPoints + points,
        'spinsToday': spinsToday + 1,
        'todayEarning': currentTodayEarning + points,
        'totalEarnings': currentTotalEarnings + points,
        'lastSpinDate': FieldValue.serverTimestamp(),
        'remainingSpins': newRemainingSpins,  // Update remaining spins
      });

      // Update local user model
      _user!.points = currentPoints + points;
      _user!.spinsToday = spinsToday + 1;
      _user!.todayEarning = currentTodayEarning + points;
      _user!.totalEarnings = currentTotalEarnings + points;
      _user!.lastSpinDate = DateTime.now();
      _user!.remainingSpins = newRemainingSpins;  // Update local remaining spins
    });

    notifyListeners();
  }

  // Generate a random 6-character referral code
  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Sign out first to ensure a fresh sign-in
      await _googleSignIn.signOut();
      await _auth.signOut();

      // Begin sign in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Create or update user in Firestore using FirebaseService
        final firebaseService = FirebaseService();
        await firebaseService.createOrUpdateUser(user);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in signInWithGoogle: ${e.code} - ${e.message}');
      // Sign out on error to ensure clean state
      await _googleSignIn.signOut();
      await _auth.signOut();
      rethrow;
    } catch (e) {
      print('Error signing in with Google: $e');
      // Sign out on error to ensure clean state
      await _googleSignIn.signOut();
      await _auth.signOut();
      rethrow;
    }
  }

  // Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _userSubscription?.cancel();
    _user = null;
    notifyListeners();
  }

  // Apply referral code
  Future<bool> applyReferralCode(String code) async {
    if (_user == null || _user!.referredBy != null) return false;
    
    try {
      // First check the referralCodes collection
      final refDoc = await _firestore.collection('referralCodes').doc(code).get();
      if (!refDoc.exists || !(refDoc.data()?['isActive'] ?? false)) {
        return false;
      }
      
      final referrerUid = refDoc.data()?['uid'] as String;
      
      // Check if user is trying to use their own referral code
      if (referrerUid == _user!.uid) return false;
      
      // Get referrer user document
      final referrerDoc = await _firestore.collection('users').doc(referrerUid).get();
      if (!referrerDoc.exists) return false;
      
      // Update both users with 2000 points (₹2)
      final batch = _firestore.batch();
      
      // Update current user
      final userRef = _firestore.collection('users').doc(_user!.uid);
      batch.update(userRef, {
        'referredBy': referrerUid,
        'points': FieldValue.increment(2000),
        'totalEarnings': FieldValue.increment(2000),
        'todayEarning': FieldValue.increment(2000),
        'referralAppliedDate': FieldValue.serverTimestamp(),
      });
      
      // Update referrer
      final referrerRef = _firestore.collection('users').doc(referrerUid);
      batch.update(referrerRef, {
        'points': FieldValue.increment(2000),
        'totalEarnings': FieldValue.increment(2000),
        'todayEarning': FieldValue.increment(2000),
        'referralEarnings': FieldValue.increment(2000),
        'totalReferrals': FieldValue.increment(1),
        'referredUsers': FieldValue.arrayUnion([_user!.uid]),
        'lastReferralDate': FieldValue.serverTimestamp(),
      });
      
      // Create a referral record
      final referralRef = _firestore.collection('referrals').doc();
      batch.set(referralRef, {
        'referrerId': referrerUid,
        'refereeId': _user!.uid,
        'referralCode': code,
        'amount': 2000,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed'
      });
      
      await batch.commit();
      
      // Update local user data
      _user!.referredBy = referrerUid;
      _user!.points += 2000;
      _user!.totalEarnings += 2000;
      _user!.todayEarning += 2000;
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error applying referral code: $e');
      return false;
    }
  }

  Future<void> addExtraSpin() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('Error: No user logged in');
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // Run in a transaction to ensure data consistency
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        print('\n=== Adding Extra Spin ===');
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          print('Error: User document not found');
          throw Exception('User document not found');
        }

        // Get current values
        final currentSpins = userDoc.data()?['remainingSpins'] as int? ?? 0;
        final spinsToday = userDoc.data()?['spinsToday'] as int? ?? 0;
        final now = DateTime.now();
        
        print('Current values:');
        print('- Remaining spins: $currentSpins');
        print('- Spins today: $spinsToday');
        
        // Calculate new spinsToday (decrease by 1, but ensure it doesn't go below 0)
        final newSpinsToday = spinsToday > 0 ? spinsToday - 1 : 0;
        
        final updates = {
          'remainingSpins': currentSpins + 1,
          'lastAdRewardTime': now.toIso8601String(),
          'lastSpinDate': now, // Use actual DateTime instead of server timestamp
          'spinsToday': newSpinsToday, // Decrease spinsToday by 1
        };
        
        print('Updating with: $updates');
        print('- Decreasing spinsToday from $spinsToday to $newSpinsToday');
        
        transaction.update(userRef, updates);
        success = true;

        // Update local user model immediately for UI responsiveness
        if (_user != null) {
          _user!.remainingSpins = currentSpins + 1;
          _user!.spinsToday = newSpinsToday; // Update local spinsToday as well
          _user!.lastSpinDate = now;
          print('Updated local user model:');
          print('- Remaining spins: ${_user!.remainingSpins}');
          print('- Spins today: ${_user!.spinsToday}');
        }
      });

      if (success) {
        // Notify listeners immediately after transaction completes
        notifyListeners();
        
        // Force a refresh of the user data to ensure UI is updated
        print('\nFetching fresh user data...');
        final freshData = await userRef.get();
        if (freshData.exists && _user != null) {
          final newSpins = freshData.data()?['remainingSpins'] as int? ?? 0;
          final newSpinsToday = freshData.data()?['spinsToday'] as int? ?? 0;
          print('Fresh data - remaining spins: $newSpins');
          print('Fresh data - spins today: $newSpinsToday');
          _user = UserModel.fromMap(freshData.data()!);
          notifyListeners(); // Notify again with fresh data
          print('✓ Successfully updated spins');
        }
      }
    } catch (e) {
      print('Error adding extra spin: $e');
      rethrow;
    }
  }

  // Add this method to update user data
  void updateUserData(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check if email is verified in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      // Get email verification status
      final isVerified = userDoc.data()?['emailVerified'] ?? false;
      _isEmailVerified = isVerified;
      
      // If email is not verified, send a new OTP
      if (!isVerified) {
        await sendEmailVerificationOtp(email);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in signInWithEmailAndPassword: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error signing in with email and password: $e');
      rethrow;
    }
  }

  // Register with Email and Password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name, 
    String phoneNumber
  ) async {
    try {
      print('Registering user with name: "$name", email: $email, phone: $phoneNumber');
      
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        print('User created successfully. Setting display name: "$name"');
        // Update display name
        await user.updateDisplayName(name);
        
        // Create user in Firestore with phone number and email verification status
        final firebaseService = FirebaseService();
        print('Creating user in Firestore with name: "$name"');
        await firebaseService.createOrUpdateUser(
          user,
          phoneNumber: phoneNumber,
          emailVerified: true, // Email is already verified with OTP
          name: name, // Pass the name directly to createOrUpdateUser
        );
        
        // We've already verified email with OTP, no need to send it again
        // await sendEmailVerificationOtp(email);
        
        // Set email as verified since we've already verified it
        _isEmailVerified = true;
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in registerWithEmailAndPassword: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error registering with email and password: $e');
      rethrow;
    }
  }

  // Enhanced reset password method
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      // Check if email exists in our database first
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (emailQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No account found with this email address.'
        };
      }

      // Send password reset email through Firebase Auth
      await _auth.sendPasswordResetEmail(email: email);
      
      // Also send a custom email with instructions for better user experience
      final emailService = EmailService();
      await emailService.sendPasswordResetEmail(email: email);
      
      return {
        'success': true,
        'message': 'Password reset link has been sent to your email.'
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Try again later.';
          break;
        default:
          message = 'An error occurred. Please try again later.';
      }
      return {
        'success': false,
        'message': message,
        'error': e.toString()
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send reset email. Please try again later.',
        'error': e.toString()
      };
    }
  }

  // Send verification OTP to email
  Future<void> sendEmailVerificationOtp(String email) async {
    try {
      // Generate a random 6-digit OTP
      final random = Random();
      final otp = List.generate(6, (_) => random.nextInt(10)).join();
      
      // Store the OTP with the email (in memory)
      _emailOtpCodes[email] = otp;
      
      // Send the OTP via email
      final emailService = EmailService();
      await emailService.sendOtpEmail(
        email: email,
        otp: otp,
        isNewUser: true,
      );
      
      print('Verification OTP sent to $email: $otp');
    } catch (e) {
      print('Error sending verification email: $e');
      rethrow;
    }
  }
  
  // Verify the email OTP
  Future<bool> verifyEmailOtp(String email, String otp) async {
    try {
      // Retrieve the stored OTP for this email
      final storedOtp = _emailOtpCodes[email];
      
      if (storedOtp == null) {
        print('No OTP found for email: $email');
        return false;
      }
      
      // Verify the OTP
      final isValid = storedOtp == otp;
      
      if (isValid) {
        // Mark email as verified
        _isEmailVerified = true;
        
        // If using Firebase Auth's email verification
        if (_auth.currentUser != null) {
          // Update user's emailVerified status in Firestore
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Remove the OTP from storage
        _emailOtpCodes.remove(email);
        
        print('Email verified successfully: $email');
      } else {
        print('Invalid OTP for email: $email');
      }
      
      return isValid;
    } catch (e) {
      print('Error verifying email OTP: $e');
      return false;
    }
  }
  
  // Request account deletion
  Future<Map<String, dynamic>> requestAccountDeletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }
      
      final firebaseService = FirebaseService();
      final result = await firebaseService.requestAccountDeletion();
      
      return result;
    } catch (e) {
      print('Error requesting account deletion: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  // Check if account deletion is requested
  Future<bool> isAccountDeletionRequested() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final firebaseService = FirebaseService();
      return await firebaseService.isAccountDeletionRequested();
    } catch (e) {
      print('Error checking account deletion status: $e');
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
      
      final firebaseService = FirebaseService();
      final result = await firebaseService.cancelAccountDeletionRequest();
      
      return result;
    } catch (e) {
      print('Error canceling account deletion: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
} 