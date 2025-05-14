import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class UnityAdsService {
  static const String _gameId = '5850242'; // Replace with your Unity Game ID
  static bool _isInitialized = false;

  // Banner placement IDs for different screens
  static const Map<String, String> bannerPlacements = {
    'home': 'Banner_Android_Home',
    'profile': 'Banner_Android_Profile',
    'wallet': 'Banner_Android_Wallet',
    'game': 'Banner_Android_Game',
    'spin': 'Banner_Android_Spin',
    'leaderboard': 'Banner_Android_Leaderboard',
    'help': 'Banner_Android_Help',
    'tickets': 'Banner_Android_Tickets',
    'instagram': 'Banner_Android_Instagram',
  };

  static Future<void> initialize() async {
    if (_isInitialized) return;

    await UnityAds.init(
      gameId: _gameId,
      testMode: true, // Set to false for production
      onComplete: () => _isInitialized = true,
      onFailed: (error, message) => print('Unity Ads initialization failed: $message'),
    );
  }

  static String getBannerPlacementId(String screen) {
    return bannerPlacements[screen] ?? bannerPlacements['home']!;
  }
} 