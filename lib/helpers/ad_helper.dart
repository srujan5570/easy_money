import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return dotenv.get('ADMOB_BANNER_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/4491054083');
    } else if (Platform.isIOS) {
      return dotenv.get('ADMOB_IOS_BANNER_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/4491054083');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return dotenv.get('ADMOB_INTERSTITIAL_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/6491054083');
    } else if (Platform.isIOS) {
      return dotenv.get('ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/6491054083');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return dotenv.get('ADMOB_REWARDED_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/8491054083');
    } else if (Platform.isIOS) {
      return dotenv.get('ADMOB_IOS_REWARDED_AD_UNIT_ID', fallback: 'ca-app-pub-7312716976176410/8491054083');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
} 