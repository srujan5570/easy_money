import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Submit a new support ticket
  Future<void> submitSupportTicket({
    required String name,
    required String email,
    required String issueCategory,
    required String issueDescription,
    required bool includeDeviceInfo,
    required bool includeScreenshot,
  }) async {
    try {
      // Get current user if logged in
      final User? currentUser = _auth.currentUser;
      final String? userId = currentUser?.uid;
      
      // Get device info
      Map<String, dynamic> deviceData = {};
      if (includeDeviceInfo) {
        deviceData = await _getDeviceInfo();
      }
      
      // Create default admin response
      final defaultAdminResponse = {
        'text': 'Thank you for your ticket. We apologize for the inconvenience and will resolve your issue as soon as possible.',
        'timestamp': Timestamp.now(),
        'isAdmin': true,
      };
      
      // Create support ticket document
      final ticketData = {
        'userId': userId,
        'name': name,
        'email': email,
        'issueCategory': issueCategory,
        'issueDescription': issueDescription,
        'deviceInfo': includeDeviceInfo ? deviceData : null,
        'includeScreenshot': includeScreenshot,
        'status': 'in_progress', // Update status to in_progress since admin has responded
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'resolved': false,
        'adminResponses': [defaultAdminResponse], // Include the default response
        'userReplies': [],
      };
      
      // Save to Firestore
      await _firestore.collection('support_tickets').add(ticketData);
    } catch (e) {
      print('Error submitting support ticket: $e');
      rethrow;
    }
  }
  
  /// Get device information for debugging
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'deviceModel': androidInfo.model,
          'osVersion': 'Android ${androidInfo.version.release}',
          'manufacturer': androidInfo.manufacturer,
          'deviceId': androidInfo.id,
          'platform': 'Android',
          'sdkVersion': androidInfo.version.sdkInt.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'deviceModel': iosInfo.model,
          'osVersion': '${iosInfo.systemName} ${iosInfo.systemVersion}',
          'deviceId': iosInfo.identifierForVendor,
          'platform': 'iOS',
          'utsname': iosInfo.utsname.version,
        };
      }
      
      return {
        'platform': 'Unknown',
        'deviceModel': 'Unknown',
        'osVersion': 'Unknown',
      };
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'error': e.toString(),
        'deviceModel': 'Error retrieving',
        'osVersion': 'Error retrieving',
      };
    }
  }
  
  /// Add a user reply to an existing support ticket
  Future<void> addUserReplyToTicket(String ticketId, String replyText) async {
    try {
      // Get the current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'User not authenticated';
      }

      // Get a reference to the ticket document
      final ticketRef = _firestore.collection('support_tickets').doc(ticketId);
      
      // Create a timestamp for the reply (use client-side timestamp instead of server timestamp)
      final timestamp = Timestamp.now();
      
      // Run this as a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the current ticket data
        final ticketDoc = await transaction.get(ticketRef);
        if (!ticketDoc.exists) {
          throw 'Ticket not found';
        }
        
        final ticketData = ticketDoc.data() as Map<String, dynamic>;
        
        // Get the current userReplies array or create a new one if it doesn't exist
        List<dynamic> userReplies = List<dynamic>.from(ticketData['userReplies'] ?? []);
        
        // Create the new reply object
        Map<String, dynamic> newReply = {
          'text': replyText,
          'timestamp': timestamp, // Use client-side timestamp
          'userId': currentUser.uid,
          'isAdmin': false, // Add isAdmin flag for proper UI display
        };
        
        // Add the new reply to the userReplies array
        userReplies.add(newReply);
        
        // Update the ticket document with the new userReplies array and update the updatedAt field
        transaction.update(ticketRef, {
          'userReplies': userReplies,
          'updatedAt': timestamp, // Use client-side timestamp
          'status': 'open', // Reopen the ticket if it was closed
        });
      });
      
      print('User reply added successfully to ticket $ticketId');
    } catch (e) {
      print('Error adding user reply to ticket: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }
  
  /// Get a stream of user support tickets
  Stream<QuerySnapshot> getUserSupportTickets() {
    final User? currentUser = _auth.currentUser;
    final String? userId = currentUser?.uid;
    
    if (userId == null) {
      // Return an empty stream if no user is logged in
      return Stream<QuerySnapshot>.empty();
    }
    
    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: userId)
        // Removing the complex ordering to avoid the need for a composite index
        // .orderBy('updatedAt', descending: true)
        .snapshots();
  }
  
  /// Add an admin response to an existing support ticket
  Future<void> addAdminResponseToTicket(String ticketId, String responseText) async {
    try {
      // Get a reference to the ticket document
      final ticketRef = _firestore.collection('support_tickets').doc(ticketId);
      
      // Create a timestamp for the response
      final timestamp = Timestamp.now();
      
      // Run this as a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the current ticket data
        final ticketDoc = await transaction.get(ticketRef);
        if (!ticketDoc.exists) {
          throw 'Ticket not found';
        }
        
        final ticketData = ticketDoc.data() as Map<String, dynamic>;
        
        // Get the current adminResponses array or create a new one if it doesn't exist
        List<dynamic> adminResponses = List<dynamic>.from(ticketData['adminResponses'] ?? []);
        
        // Create the new response object
        Map<String, dynamic> newResponse = {
          'text': responseText,
          'timestamp': timestamp, // Use client-side timestamp
          'isAdmin': true,
        };
        
        // Add the new response to the adminResponses array
        adminResponses.add(newResponse);
        
        // Update the ticket document
        transaction.update(ticketRef, {
          'adminResponses': adminResponses,
          'updatedAt': timestamp,
          'status': 'in_progress',
        });
      });
      
      print('Admin response added successfully to ticket $ticketId');
    } catch (e) {
      print('Error adding admin response to ticket: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }
} 