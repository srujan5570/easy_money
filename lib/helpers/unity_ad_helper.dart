import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// Add enum for ad failure types
enum AdFailureType {
  loadFailed,
  showFailed,
  skipped,
  timeout,
  notWatched
}

// Add class for ad result
class AdResult {
  final bool success;
  final String? error;
  final bool completedFiveAds;
  final bool shouldShowRetry;

  AdResult({
    required this.success, 
    this.error,
    this.completedFiveAds = false,
    this.shouldShowRetry = false
  });
}

// Add banner ad state
class BannerAdState {
  final bool isLoaded;
  final String? error;

  BannerAdState({
    required this.isLoaded,
    this.error,
  });
}

class UnityAdHelper {
  static String gameId = '5850242';
  static bool _isInitialized = false;
  static bool _isLoadingAd = false;
  static bool _isShowingAd = false;
  static int _loadedRewardedAdsCount = 0;
  static int _loadedInterstitialAdsCount = 0;
  static bool _isBannerAdLoaded = false;
  static const int _maxLoadedAds = 5;
  static bool _isInitializing = false;
  static int _retryAttempt = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _minAdInterval = Duration(seconds: 3);
  static DateTime? _lastAdShownTime;
  static bool _isPreloadingRewarded = false;
  static bool _isWaitingForShow = false;
  static int _adsWatchedCount = 0;

  // Keep track of when ads were last preloaded
  static DateTime? _lastPreloadTime;
  static const Duration _preloadCooldown = Duration(seconds: 30);
  static const Duration _showTimeout = Duration(seconds: 5);

  // Add getter for checking if rewarded ad is loaded
  static bool get hasLoadedRewardedAd => _loadedRewardedAdsCount > 0;

  static String getFailureMessage(AdFailureType type) {
    switch (type) {
      case AdFailureType.loadFailed:
        return 'Ad loading failed. Please try again after 1 minute.';
      case AdFailureType.showFailed:
        return 'Failed to display ad. Please try again.';
      case AdFailureType.skipped:
        return 'Please watch the entire ad to earn progress.';
      case AdFailureType.timeout:
        return 'Ad took too long to load. Please try again.';
      case AdFailureType.notWatched:
        return 'Please watch the entire ad to earn progress.';
    }
  }

  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      print('Unity Ads already initialized or initializing');
      return;
    }
    
    _isInitializing = true;
    try {
      print('\n=== Unity Ads Initialization ===');
      print('Game ID: $gameId');
      print('Production Mode Enabled');
      print('Initializing Unity Ads SDK...');
      
      await UnityAds.init(
        gameId: gameId,
        onComplete: () async {
          print('✅ Unity Ads initialization complete');
          print('SDK Status: Production Mode');
          print('Ad Placements:');
          print('- Rewarded: Rewarded_Android');
          print('- Interstitial: Interstitial_Android');
          print('- Banner: Banner_Android');
          _isInitialized = true;
          _isInitializing = false;
          _retryAttempt = 0;
          
          // Ensure first ad load to trigger user session
          print('Starting to preload ads for user session...');
          await preloadAds();
          
          // Load an initial interstitial to ensure user tracking
          await loadInterstitialAd();
          
          // Load initial banner ad
          await loadBannerAd();
        },
        onFailed: (error, message) {
          print('❌ Unity Ads initialization failed:');
          print('Error: $error');
          print('Message: $message');
          _isInitializing = false;
          _retryInitialization();
        },
        testMode: false,
      );
    } catch (e) {
      print('❌ Error initializing Unity Ads:');
      print(e);
      _isInitializing = false;
      _retryInitialization();
    }
  }

  static Future<void> _retryInitialization() async {
    if (_retryAttempt >= _maxRetryAttempts) {
      print('Max retry attempts reached for initialization');
      return;
    }

    _retryAttempt++;
    final delay = _initialRetryDelay * _retryAttempt;
    print('Retrying initialization in ${delay.inSeconds} seconds (attempt $_retryAttempt/$_maxRetryAttempts)');
    await Future.delayed(delay);
    await initialize();
  }

  static Future<void> _ensureRewardedAdsAvailable() async {
    if (_isPreloadingRewarded) return;
    
    final now = DateTime.now();
    if (_lastPreloadTime != null && now.difference(_lastPreloadTime!) < _preloadCooldown) {
      print('Skipping preload - cooldown active');
      return;
    }

    if (_loadedRewardedAdsCount < 1) {
      print('\n=== Ensuring Rewarded Ads Availability ===');
      print('Current loaded ads: $_loadedRewardedAdsCount');
      print('Starting background preload...');
      _preloadRewardedAdsInBackground();
    }
  }

  static Future<void> _preloadRewardedAdsInBackground() async {
    if (_isPreloadingRewarded) return;
    
    if (_loadedRewardedAdsCount > 0) {
      print('Rewarded ad already loaded');
      return;
    }
    
    _isPreloadingRewarded = true;
    try {
      print('\nPreloading rewarded ad');
      await loadRewardedAd();
      _lastPreloadTime = DateTime.now();
    } finally {
      _isPreloadingRewarded = false;
    }
  }

  static Future<void> preloadAds() async {
    if (!_isInitialized) {
      print('Cannot preload ads - Unity Ads not initialized');
      return;
    }

    print('\n=== Preloading Unity Ads (Production Mode) ===');
    print('Target: 1 rewarded ad and 1 interstitial ad');
    
    // Load one rewarded and one interstitial ad
    if (_loadedRewardedAdsCount == 0) {
      await _preloadRewardedAdsInBackground();
    }
    if (_loadedInterstitialAdsCount == 0) {
      await _preloadInterstitialAds();
    }
  }

  static Future<void> _preloadInterstitialAds() async {
    if (_loadedInterstitialAdsCount > 0) {
      print('Interstitial ad already loaded');
      return;
    }

    print('\nAttempting to load interstitial ad');
    await loadInterstitialAd();
  }

  static Future<void> loadRewardedAd() async {
    if (!_isInitialized) {
      print('Cannot load rewarded ad - Unity Ads not initialized');
      return;
    }

    if (_isLoadingAd) {
      print('Ad load in progress, waiting...');
      // Wait for the current loading to complete
      int attempts = 0;
      while (_isLoadingAd && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      return;
    }

    if (_loadedRewardedAdsCount >= 1) {
      print('Rewarded ad already loaded');
      return;
    }

    _isLoadingAd = true;
    _retryAttempt = 0;
    await _attemptLoadRewardedAd();
  }

  static Future<void> loadInterstitialAd() async {
    if (!_isInitialized || _isLoadingAd) {
      print('Cannot load interstitial ad - Unity Ads not initialized or loading in progress');
      return;
    }

    if (_loadedInterstitialAdsCount >= _maxLoadedAds) {
      print('Maximum number of interstitial ads already loaded');
      return;
    }

    _isLoadingAd = true;
    try {
      await UnityAds.load(
        placementId: 'Interstitial_Android',
        onComplete: (placementId) {
          print('✅ Interstitial ad loaded successfully');
          _loadedInterstitialAdsCount++;
          _isLoadingAd = false;
        },
        onFailed: (placementId, error, message) {
          print('❌ Interstitial ad load failed: $message');
          _isLoadingAd = false;
        },
      );
    } catch (e) {
      print('❌ Error loading interstitial ad: $e');
      _isLoadingAd = false;
    }
  }

  static Future<void> _attemptLoadRewardedAd() async {
    try {
      print('Loading rewarded ad (attempt ${_retryAttempt + 1}/$_maxRetryAttempts)');
      
      final completer = Completer<void>();
      
      UnityAds.load(
        placementId: 'Rewarded_Android',
        onComplete: (placementId) {
          print('✅ Rewarded ad loaded successfully');
          _loadedRewardedAdsCount = 1; // Always keep exactly one ad loaded
          _isLoadingAd = false;
          _retryAttempt = 0;
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: (placementId, error, message) {
          print('❌ Failed to load rewarded ad:');
          print('Error: $error');
          print('Message: $message');
          if (!completer.isCompleted) {
            _retryLoadRewardedAd();
            completer.complete();
          }
        },
      );
      
      // Wait for the ad to load with a timeout
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 5)).then((_) {
          if (!completer.isCompleted) {
            print('Ad load timeout');
            _isLoadingAd = false;
            completer.complete();
          }
        }),
      ]);
      
    } catch (e) {
      print('❌ Error loading rewarded ad: $e');
      _isLoadingAd = false;
      _retryLoadRewardedAd();
    }
  }

  static Future<void> _retryLoadRewardedAd() async {
    if (_retryAttempt >= _maxRetryAttempts) {
      print('Max retry attempts reached for ad loading');
      _isLoadingAd = false;
      return;
    }

    _retryAttempt++;
    final delay = _initialRetryDelay * _retryAttempt;
    print('Retrying ad load in ${delay.inSeconds} seconds (attempt $_retryAttempt/$_maxRetryAttempts)');
    await Future.delayed(delay);
    if (_loadedRewardedAdsCount == 0) {
      await _attemptLoadRewardedAd();
    }
  }

  static Future<bool> _canShowAd() async {
    if (_lastAdShownTime == null) return true;
    
    final timeSinceLastAd = DateTime.now().difference(_lastAdShownTime!);
    final canShow = timeSinceLastAd >= _minAdInterval;
    
    print('\n=== Checking if can show ad ===');
    print('Time since last ad: ${timeSinceLastAd.inSeconds}s');
    print('Minimum interval: ${_minAdInterval.inSeconds}s');
    print('Can show: $canShow');
    
    return canShow;
  }

  static Future<void> _updateLastAdShownTime() async {
    _lastAdShownTime = DateTime.now();
    print('Updated last ad shown time to: $_lastAdShownTime');
  }

  static Future<bool> _handleAdCompletion() async {
    _adsWatchedCount++;
    print('Ad watched count: $_adsWatchedCount');
    
    // Check if we've completed 5 ads
    if (_adsWatchedCount >= 5) {
      print('✨ Completed 5 ads! Resetting counter');
      _adsWatchedCount = 0;
      return true;
    }
    
    return false;
  }

  static Future<AdResult> _loadAndShowRewardedAd(BuildContext context) async {
    debugPrint('\n=== Attempting immediate ad load and show ===');
    _isLoadingAd = true;
    
    try {
      final completer = Completer<bool>();
      
      UnityAds.load(
        placementId: 'Rewarded_Android',
        onComplete: (placementId) {
          debugPrint('✅ Immediate rewarded ad load successful');
          _loadedRewardedAdsCount = 1;
          _isLoadingAd = false;
          if (!completer.isCompleted) completer.complete(true);
        },
        onFailed: (placementId, error, message) {
          debugPrint('❌ Immediate rewarded ad load failed:');
          debugPrint('Error: $error');
          debugPrint('Message: $message');
          _isLoadingAd = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Wait for ad to load with a timeout
      final loadSuccess = await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 3)).then((_) {
          if (!completer.isCompleted) {
            debugPrint('Immediate ad load timeout');
            _isLoadingAd = false;
            completer.complete(false);
          }
          return false;
        }),
      ]);

      if (loadSuccess) {
        // Ad loaded successfully, try to show it
        return await showRewardedAd(context);
      } else {
        // Ad failed to load, suggest retry
        return AdResult(
          success: false, 
          error: 'Failed to load ad',
          shouldShowRetry: true
        );
      }
    } catch (e) {
      debugPrint('Error in immediate ad load: $e');
      return AdResult(
        success: false, 
        error: e.toString(),
        shouldShowRetry: true
      );
    }
  }

  static Future<AdResult> showRewardedAd(BuildContext context) async {
    if (!_isInitialized) {
      debugPrint('Unity Ads not initialized');
      return AdResult(success: false, error: 'Unity Ads not initialized');
    }

    if (_isShowingAd) {
      debugPrint('Ad already showing');
      return AdResult(success: false, error: 'Ad already showing');
    }

    if (_isWaitingForShow) {
      debugPrint('Already waiting for ad to show');
      return AdResult(success: false, error: 'Already waiting for ad to show');
    }

    debugPrint('\n=== Attempting to show rewarded ad ===');
    debugPrint('Current state:');
    debugPrint('- Is initialized: $_isInitialized');
    debugPrint('- Is showing ad: $_isShowingAd');
    debugPrint('- Is waiting for show: $_isWaitingForShow');
    debugPrint('- Loaded ads count: $_loadedRewardedAdsCount');
    debugPrint('- Ads watched count: $_adsWatchedCount');

    if (!await _canShowAd()) {
      debugPrint('Please wait before showing another ad');
      return AdResult(success: false, error: 'Please wait before showing another ad');
    }

    // If no ad is preloaded, try immediate load
    if (_loadedRewardedAdsCount <= 0) {
      debugPrint('No preloaded ad available, attempting immediate load...');
      return await _loadAndShowRewardedAd(context);
    }

    _isWaitingForShow = true;
    _isShowingAd = true;
    bool adStarted = false;
    bool adCompleted = false;
    Timer? timeoutTimer;

    try {
      debugPrint('Showing Unity rewarded ad...');
      final startTime = DateTime.now().millisecondsSinceEpoch;

      final completer = Completer<AdResult>();

      // Set up timeout
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (adStarted == false) {
          debugPrint('Ad show timeout - resetting states');
          _isWaitingForShow = false;
          _isShowingAd = false;
          if (!completer.isCompleted) {
            completer.complete(AdResult(
              success: false, 
              error: 'Ad show timeout',
              shouldShowRetry: true
            ));
          }
        }
      });

      UnityAds.showVideoAd(
        placementId: 'Rewarded_Android',
        onStart: (placementId) {
          debugPrint('Unity rewarded ad started at ${DateTime.now().toString()}');
          adStarted = true;
          timeoutTimer?.cancel();
        },
        onComplete: (placementId) async {
          final endTime = DateTime.now().millisecondsSinceEpoch;
          final duration = endTime - startTime;
          debugPrint('✅ Unity rewarded ad completed');
          debugPrint('Ad duration: ${duration}ms');
          adCompleted = true;
          _updateLastAdShownTime();
          _loadedRewardedAdsCount--;
          _isWaitingForShow = false;
          _isShowingAd = false;
          
          // Handle ad completion and check if 5 ads were watched
          bool completedFiveAds = await _handleAdCompletion();
          
          if (!completer.isCompleted) {
            completer.complete(AdResult(
              success: true,
              completedFiveAds: completedFiveAds
            ));
          }
          
          // Preload next ad after successful completion
          await loadRewardedAd();
        },
        onSkipped: (placementId) {
          debugPrint('Unity rewarded ad skipped');
          _isWaitingForShow = false;
          _isShowingAd = false;
          if (!completer.isCompleted) {
            completer.complete(AdResult(success: false, error: 'Ad was skipped'));
          }
        },
        onFailed: (placementId, error, message) {
          debugPrint('❌ Unity rewarded ad failed: $message');
          _isWaitingForShow = false;
          _isShowingAd = false;
          if (!completer.isCompleted) {
            completer.complete(AdResult(
              success: false, 
              error: message,
              shouldShowRetry: true
            ));
          }
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
      _isWaitingForShow = false;
      _isShowingAd = false;
      return AdResult(
        success: false, 
        error: e.toString(),
        shouldShowRetry: true
      );
    } finally {
      timeoutTimer?.cancel();
      if (!adCompleted) {
        _isWaitingForShow = false;
        _isShowingAd = false;
      }
    }
  }

  static Future<AdResult> showInterstitialAd(BuildContext context) async {
    if (!_isInitialized) {
      print('Cannot show interstitial ad - Unity Ads not initialized');
      return AdResult(success: false, error: 'Unity Ads not initialized');
    }

    if (_isShowingAd) {
      print('Another ad is currently showing');
      return AdResult(success: false, error: 'Another ad is currently showing');
    }

    if (!await _canShowAd()) {
      print('Please wait before showing another ad');
      return AdResult(success: false, error: 'Please wait before showing another ad');
    }

    if (_loadedInterstitialAdsCount <= 0) {
      print('No preloaded interstitial ads available');
      await loadInterstitialAd();
      return AdResult(success: false, error: 'No ad available');
    }

    final completer = Completer<AdResult>();
    _isShowingAd = true;
    
    try {
      await UnityAds.showVideoAd(
        placementId: 'Interstitial_Android',
        onComplete: (placementId) async {
          print('✅ Interstitial ad completed');
          _loadedInterstitialAdsCount--;
          await _updateLastAdShownTime();
          loadInterstitialAd(); // Load next ad
          _isShowingAd = false;
          completer.complete(AdResult(success: true));
        },
        onFailed: (placementId, error, message) {
          print('❌ Interstitial ad failed: $message');
          _isShowingAd = false;
          completer.complete(AdResult(success: false, error: message));
        },
        onStart: (placementId) => print('Interstitial ad started'),
        onSkipped: (placementId) {
          print('⚠️ Interstitial ad skipped');
          _isShowingAd = false;
          completer.complete(AdResult(success: false, error: 'Ad skipped'));
        },
        onClick: (placementId) => print('Interstitial ad clicked'),
      );
    } catch (e) {
      print('❌ Error showing interstitial ad: $e');
      _isShowingAd = false;
      completer.complete(AdResult(success: false, error: e.toString()));
    }

    return completer.future;
  }

  static bool get hasLoadedInterstitialAd => _loadedInterstitialAdsCount > 0;

  // Add banner ad methods
  static Widget getBannerAd({
    void Function(String)? onLoad,
    void Function(String, UnityAdsBannerError, String)? onFailed,
    void Function(String)? onClick,
  }) {
    return UnityBannerAd(
      size: BannerSize.standard,
      placementId: 'Banner_Android',
      onLoad: onLoad ?? (placementId) => print('Banner ad loaded: $placementId'),
      onFailed: onFailed ?? (placementId, error, message) => print('Banner ad failed to load: $message'),
      onClick: onClick ?? (placementId) => print('Banner ad clicked'),
    );
  }

  static Future<BannerAdState> loadBannerAd() async {
    if (!_isInitialized) {
      print('Cannot load banner ad - Unity Ads not initialized');
      return BannerAdState(isLoaded: false, error: 'Unity Ads not initialized');
    }

    try {
      print('\n=== Loading Unity Banner Ad ===');
      final completer = Completer<BannerAdState>();
      
      // Unity Banner ads don't need explicit loading - they load when placed in the widget tree
      _isBannerAdLoaded = true;
      return BannerAdState(isLoaded: true);
    } catch (e) {
      print('❌ Error loading banner ad: $e');
      return BannerAdState(isLoaded: false, error: e.toString());
    }
  }

  static bool get isBannerAdLoaded => _isBannerAdLoaded;
} 