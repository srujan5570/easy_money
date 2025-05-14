import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_level.dart';
import '../services/game_progress_service.dart';
import '../services/leaderboard_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameProgressProvider extends ChangeNotifier {
  Set<int> _unlockedLevels = {1}; // Level 1 is always unlocked
  Set<int> _completedLevels = {};
  Map<int, int> _levelStars = {};
  Map<int, int> _bestTimes = {};
  Set<int> _watchedAdsForLevels = {}; // Track levels where ads were watched
  final GameProgressService _gameProgressService = GameProgressService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  String? currentGameId;

  Set<int> get unlockedLevels => _unlockedLevels;
  Set<int> get completedLevels => _completedLevels;
  Map<int, int> get levelStars => _levelStars;
  Map<int, int> get bestTimes => _bestTimes;

  // Initialize from SharedPreferences and Firebase
  Future<void> loadProgress() async {
    // Load from SharedPreferences first for immediate data
    final prefs = await SharedPreferences.getInstance();
    
    _unlockedLevels = (prefs.getStringList('unlockedLevels') ?? ['1'])
        .map((e) => int.parse(e))
        .toSet();
    
    _completedLevels = (prefs.getStringList('completedLevels') ?? [])
        .map((e) => int.parse(e))
        .toSet();
    
    final starsMap = prefs.getString('levelStars') ?? '{}';
    _levelStars = Map<String, int>.from(
      const JsonDecoder().convert(starsMap) as Map,
    ).map((key, value) => MapEntry(int.parse(key), value));
    
    final timesMap = prefs.getString('bestTimes') ?? '{}';
    _bestTimes = Map<String, int>.from(
      const JsonDecoder().convert(timesMap) as Map,
    ).map((key, value) => MapEntry(int.parse(key), value));

    // Load watched ads data
    _watchedAdsForLevels = (prefs.getStringList('watchedAdsForLevels') ?? [])
        .map((e) => int.parse(e))
        .toSet();

    // Then try to load from Firebase
    try {
      final firebaseProgress = await _gameProgressService.getLevelProgress();
      if (firebaseProgress != null) {
        // Update local data with Firebase data
        firebaseProgress.forEach((levelStr, data) {
          final level = int.parse(levelStr);
          final stars = data['stars'] as int;
          final time = data['bestTime'] as int;
          
          // Update if Firebase has better progress
          if (stars > (_levelStars[level] ?? 0)) {
            _levelStars[level] = stars;
            _completedLevels.add(level);
            _unlockedLevels.add(level + 1);
          }
          if (time < (_bestTimes[level] ?? 999999)) {
            _bestTimes[level] = time;
          }
        });
        
        // Save merged data back to SharedPreferences
        await _saveProgress();
        
        // Update leaderboard
        await _updateLeaderboard();
      }
    } catch (e) {
      print('Error loading Firebase progress: $e');
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setStringList(
      'unlockedLevels',
      _unlockedLevels.map((e) => e.toString()).toList(),
    );
    
    await prefs.setStringList(
      'completedLevels',
      _completedLevels.map((e) => e.toString()).toList(),
    );
    
    await prefs.setString(
      'levelStars',
      const JsonEncoder().convert(
        _levelStars.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
    
    await prefs.setString(
      'bestTimes',
      const JsonEncoder().convert(
        _bestTimes.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );

    // Save watched ads data
    await prefs.setStringList(
      'watchedAdsForLevels',
      _watchedAdsForLevels.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _updateLeaderboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user profile from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return;

    final totalStars = getTotalStars();
    final highestLevel = _completedLevels.isEmpty ? 1 : _completedLevels.reduce(max);
    final username = userDoc.data()?['username'] as String? ?? 'Player';

    await _leaderboardService.updateLeaderboard(
      userName: username,
      totalStars: totalStars,
      highestLevel: highestLevel,
    );
  }

  bool isLevelUnlocked(int level) {
    return _unlockedLevels.contains(level);
  }

  int getStarsForLevel(int level) {
    return _levelStars[level] ?? 0;
  }

  int? getBestTimeForLevel(int level) {
    return _bestTimes[level];
  }

  Future<void> completeLevel(int level, int stars, int timeSeconds) async {
    // Mark level as completed
    _completedLevels.add(level);
    
    // Update stars if better than previous
    if (stars > (_levelStars[level] ?? 0)) {
      _levelStars[level] = stars;
    }
    
    // Update best time if better than previous
    if (timeSeconds < (_bestTimes[level] ?? 999999)) {
      _bestTimes[level] = timeSeconds;
    }
    
    // Always unlock just the next level
    _unlockedLevels.add(level + 1);
    
    // Save to local storage
    await _saveProgress();

    // Save to Firebase
    await _gameProgressService.saveLevelProgress(
      level: level,
      stars: stars,
      timeSeconds: timeSeconds,
    );

    // Update leaderboard
    await _updateLeaderboard();
    
    notifyListeners();
  }

  int getTotalStars() {
    return _levelStars.values.fold(0, (sum, stars) => sum + stars);
  }

  String getBestTimeString() {
    if (_bestTimes.isEmpty) return '--:--';
    final bestTime = _bestTimes.values.reduce((min, time) => time < min ? time : min);
    final minutes = (bestTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (bestTime % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> addAdRewardPoints(int timeSeconds, int level) async {
    final prefs = await SharedPreferences.getInstance();
    int bonusPoints = 10; // Base points for watching ad
    
    // Add quick completion bonus if level was completed under 30 seconds
    if (timeSeconds < 30) {
      bonusPoints += 5; // Additional bonus for quick completion
    }

    // Update local storage
    final adRewardPoints = prefs.getInt('adRewardPoints') ?? 0;
    await prefs.setInt('adRewardPoints', adRewardPoints + bonusPoints);
    
    // Mark this level as having watched an ad
    _watchedAdsForLevels.add(level);
    await _saveProgress();

    // Update total earnings in Firebase
    await _gameProgressService.updateTotalEarnings(bonusPoints);
    
    notifyListeners();
  }

  Future<int> getTotalPoints() async {
    try {
      // Get points from Firebase first
      final firebasePoints = await _gameProgressService.getTotalEarnings();
      
      // If Firebase has points, use those
      if (firebasePoints > 0) {
        // Update local storage to match Firebase
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('adRewardPoints', firebasePoints);
        return firebasePoints;
      }
      
      // Otherwise, use local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('adRewardPoints') ?? 0;
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('adRewardPoints') ?? 0;
    }
  }

  int getHighestUnlockedLevel() {
    int highest = 1;
    for (int level = 1; level <= GameLevel.predefinedLevels.length; level++) {
      if (isLevelUnlocked(level)) {
        highest = level;
      } else {
        break;
      }
    }
    return highest;
  }

  // Add method to check if ad was watched for a level
  bool hasWatchedAdForLevel(int level) {
    return _watchedAdsForLevels.contains(level);
  }

  Future<void> _initializeLevels() async {
    // Initialize levels up to the predefined ones
    for (int level = 1; level <= GameLevel.predefinedLevels.length; level++) {
      if (!_levelStars.containsKey(level)) {
        _levelStars[level] = 0;
        _completedLevels.add(level);
        _unlockedLevels.add(level + 1);
      }
    }
    
    // Save the initialized levels
    await _saveProgress();
  }

  void startNewGame() {
    currentGameId = DateTime.now().millisecondsSinceEpoch.toString();
    // Additional implementation as needed
    notifyListeners();
  }
} 