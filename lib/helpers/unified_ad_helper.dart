import 'package:flutter/material.dart';
import 'dart:async';
import 'unity_ad_helper.dart';

class UnifiedAdHelper {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Unified banner ad with fallback
  static Future<Widget?> loadUnifiedBannerAd() async {
    try {
      // Return a container for now since we're not using banner ads
      return Container();
    } catch (e) {
      print('Error loading unified banner ad: $e');
      return null;
    }
  }

  // Unified interstitial ad
  static Future<bool> showUnifiedInterstitialAd(BuildContext context) async {
    try {
      final adResult = await UnityAdHelper.showInterstitialAd(context);
      return adResult.success;
    } catch (e) {
      debugPrint('Error showing unified interstitial ad: $e');
      return false;
    }
  }

  // Unified rewarded ad
  static Future<bool> showUnifiedRewardedAd(BuildContext context) async {
    try {
      final adResult = await UnityAdHelper.showRewardedAd(context);
      return adResult.success;
    } catch (e) {
      debugPrint('Error showing unified rewarded ad: $e');
      return false;
    }
  }
} 