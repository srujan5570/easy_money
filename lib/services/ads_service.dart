import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/location_service.dart';
import 'dart:math';

class AdsService {
  static String get gameId => '5850242';

  static const String rewardedPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';
  static const String bannerPlacementId = 'Banner_Android';

  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  static bool _isInitialized = false;
  static String? _deviceId;
  static final Random _random = Random();
  static int _lastAdTimestamp = 0;
  static const int _minAdInterval = 30;

  static final List<String> _vpnCheckServices = [
    'https://ipapi.co/json/',
    'https://api.ipify.org?format=json',
    'https://ip-api.com/json',
    'https://ipinfo.io/json',
    'https://api.myip.com',
    'https://api64.ipify.org?format=json'
  ];

  static final List<String> _userAgents = [
    'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; M2101K6G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; V2169) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36'
  ];

  static String _getRandomUserAgent() {
    return _userAgents[_random.nextInt(_userAgents.length)];
  }

  static Future<void> _generateDeviceId() async {
    if (_deviceId != null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      // Create a randomized device identifier
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = _random.nextInt(10000);
      _deviceId = '${androidInfo.brand}_${timestamp}_$randomSuffix';
      print('Generated new device ID: $_deviceId');
    } catch (e) {
      print('Error generating device ID: $e');
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
    }
  }

  static Future<void> initializeAds() async {
    if (_isInitialized) {
      // Reset initialization after some time to refresh ad state
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (currentTime - _lastAdTimestamp > 3600) { // Reset every hour
        _isInitialized = false;
        _deviceId = null;
      } else {
        return;
      }
    }

    try {
      await _generateDeviceId();
      await _ensureVpnConnection();

      // Randomize initialization parameters
      final Map<String, dynamic> options = {
        'custom_device_id': _deviceId,
        'user_agent': _getRandomUserAgent(),
        'game_version': '1.${_random.nextInt(5)}.${_random.nextInt(10)}',
        'connection_type': _random.nextBool() ? 'wifi' : 'cellular',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      await UnityAds.init(
        gameId: gameId,
        testMode: false,
        onComplete: () {
          print('Unity Ads initialization complete with device ID: $_deviceId');
          _isInitialized = true;
          _lastAdTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        },
        onFailed: (error, message) {
          print('Unity Ads initialization failed: $message');
          _isInitialized = false;
        },
      );

      await _initializeAdSettings();
    } catch (e) {
      print('Error initializing ads: $e');
      _isInitialized = false;
    }
  }

  static Future<void> _ensureVpnConnection() async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      if (await _isUsingVpnConnection()) {
        return;
      }
      print('VPN check failed, attempt ${attempts + 1}/$maxAttempts');
      await Future.delayed(Duration(seconds: 2));
      attempts++;
    }
    throw Exception('VPN connection not detected after $maxAttempts attempts');
  }

  static Future<void> _initializeAdSettings() async {
    try {
      final Map<String, String> extras = {
        'device_id': _deviceId ?? 'unknown',
        'connection_type': _random.nextBool() ? 'wifi' : 'cellular',
        'country': _random.nextBool() ? 'US' : 'CA',
        'language': 'en',
        'timezone': 'America/New_York',
        'device_make': 'Samsung',
        'device_model': 'Galaxy S${_random.nextInt(20) + 10}',
        'os_version': 'Android ${_random.nextInt(4) + 10}',
      };

      print('Ad settings initialized with device ID: $_deviceId');
    } catch (e) {
      print('Error initializing ad settings: $e');
    }
  }

  // Anti-ban configuration
  static const Duration _sessionTimeout = Duration(hours: 4);
  static const int _maxSessionsPerDay = 12;
  static final List<String> _preferredIPs = [
    '167.99.156.205',
    '164.92.108.145',
    '159.223.124.89',
    // Add more trusted IPs here
  ];

  static int _sessionCount = 0;
  static DateTime? _lastSessionTime;
  static String? _currentSessionId;
  static String? _currentIP;
  static bool _isProxyEnabled = false;

  // Enhanced tracking
  static final Map<String, int> _adRequestCounts = {};
  static final Map<String, DateTime> _lastAdTimes = {};
  static int _totalDailyRequests = 0;
  static DateTime? _dailyResetTime;

  static Future<void> initializeAntibanHost() async {
    try {
      // Reset daily counters if needed
      _resetDailyCountersIfNeeded();
      
      // Generate new session ID
      _currentSessionId = _generateSessionId();
      
      // Select optimal IP
      _currentIP = await _selectOptimalIP();
      
      print('Anti-ban host initialized:');
      print('Session ID: $_currentSessionId');
      print('Selected IP: $_currentIP');
      
      _isProxyEnabled = true;
      _lastSessionTime = DateTime.now();
      _sessionCount++;
      
    } catch (e) {
      print('Error initializing anti-ban host: $e');
      _isProxyEnabled = false;
    }
  }

  static String _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(1000000);
    return '$timestamp$randomPart';
  }

  static Future<String> _selectOptimalIP() async {
    // Rotate through preferred IPs
    final index = _sessionCount % _preferredIPs.length;
    return _preferredIPs[index];
  }

  static void _resetDailyCountersIfNeeded() {
    final now = DateTime.now();
    if (_dailyResetTime == null || now.day != _dailyResetTime!.day) {
      _totalDailyRequests = 0;
      _adRequestCounts.clear();
      _dailyResetTime = now;
      _sessionCount = 0;
    }
  }

  static Future<bool> _checkAntibanStatus() async {
    if (!_isProxyEnabled || _currentIP == null || _currentSessionId == null) {
      await initializeAntibanHost();
    }

    final now = DateTime.now();
    if (_lastSessionTime != null && now.difference(_lastSessionTime!) > _sessionTimeout) {
      await initializeAntibanHost();
    }

    if (_sessionCount >= _maxSessionsPerDay) {
      print('Daily session limit reached. Please try again tomorrow.');
      return false;
    }

    return _isProxyEnabled;
  }

  static Future<Map<String, dynamic>> _getAdRequestHeaders() async {
    if (!await _checkAntibanStatus()) {
      throw Exception('Anti-ban protection not ready');
    }

    return {
      'X-Forwarded-For': _currentIP!,
      'X-Session-ID': _currentSessionId!,
      'User-Agent': _getRandomUserAgent(),
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  static Future<bool> loadRewardedAd([String? customPlacementId]) async {
    if (!_isInitialized) {
      await initializeAds();
    }

    final placementId = customPlacementId ?? rewardedPlacementId;
    int attempts = 0;
    Duration delay = initialRetryDelay;

    while (attempts < maxRetries) {
      attempts++;
      try {
        print('Loading rewarded ad (attempt $attempts/$maxRetries)');
        print('Using placement ID: $placementId');
        
        await _ensureVpnConnection();

        final completer = Completer<bool>();
        
        UnityAds.load(
          placementId: placementId,
          onComplete: (placementId) {
            print('✅ Ad loaded successfully for placement: $placementId');
            _lastAdTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            completer.complete(true);
          },
          onFailed: (placementId, error, message) {
            print('❌ Failed to load rewarded ad:');
            print('Placement ID: $placementId');
            print('Error: $error');
            print('Message: $message');
            completer.complete(false);
          },
        );

        final result = await completer.future;
        if (result) return true;

        if (attempts < maxRetries) {
          final randomDelay = delay.inSeconds + _random.nextInt(5);
          print('Retrying ad load in $randomDelay seconds (attempt $attempts/$maxRetries)');
          await Future.delayed(Duration(seconds: randomDelay));
          delay *= 2;
        }
      } catch (e) {
        print('Error loading ad: $e');
        if (attempts < maxRetries) {
          final randomDelay = delay.inSeconds + _random.nextInt(5);
          await Future.delayed(Duration(seconds: randomDelay));
          delay *= 2;
        }
      }
    }

    print('Max retry attempts reached for ad loading');
    return false;
  }

  static Future<bool> _isUsingVpnConnection() async {
    try {
      // Simple services that just return IP info
      final simpleServices = [
        'https://api.ipify.org?format=json',
        'https://api64.ipify.org?format=json',
        'https://ip4.seeip.org/json'
      ];

      // More detailed services that provide VPN/proxy detection
      final detailedServices = [
        'https://ipapi.co/json/',
        'https://ip-api.com/json',
        'https://ipinfo.io/json'
      ];

      // First try simple IP check
      for (final service in simpleServices) {
        try {
          final response = await http.get(
            Uri.parse(service),
            headers: {
              'User-Agent': _getRandomUserAgent(),
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            print('IP Check Response: ${response.body}');
            // Just getting a response from these services is enough
            // as it means we have internet connectivity
            return true;
          }
        } catch (e) {
          print('Error with simple IP service $service: $e');
          continue;
        }
      }

      // Then try detailed services
      for (final service in detailedServices) {
        try {
          final response = await http.get(
            Uri.parse(service),
            headers: {
              'User-Agent': _getRandomUserAgent(),
              'Accept': 'application/json',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            print('Detailed IP Check Response: ${response.body}');
            final data = json.decode(response.body);
            
            // Get country code from various possible fields
            final countryCode = data['country_code'] ?? 
                              data['countryCode'] ?? 
                              data['country'] ?? 
                              data['location']?['country'] ??
                              'Unknown';

            // Consider various proxy/VPN indicators
            final isProxy = data['proxy'] ?? 
                          data['vpn'] ?? 
                          data['hosting'] ??
                          data['datacenter'] ?? 
                          false;

            print('Country Code: $countryCode, Is Proxy: $isProxy');

            // Accept any valid connection for now
            if (countryCode != 'Unknown') {
              return true;
            }
          }
        } catch (e) {
          print('Error with detailed service $service: $e');
          continue;
        }
      }

      // If we got here, try one last simple check
      try {
        final response = await http.get(
          Uri.parse('https://www.google.com'),
          headers: {'User-Agent': _getRandomUserAgent()},
        ).timeout(const Duration(seconds: 3));
        
        return response.statusCode == 200;
      } catch (e) {
        print('Final connectivity check failed: $e');
      }

      return false;
    } catch (e) {
      print('Error in VPN check: $e');
      return false;
    }
  }

  static Future<void> showRewardedAd([String? customPlacementId]) async {
    if (!_isInitialized) {
      await initializeAds();
    }

    final placementId = customPlacementId ?? rewardedPlacementId;

    try {
      print('Showing rewarded ad with placement ID: $placementId');
      UnityAds.showVideoAd(
        placementId: placementId,
        onComplete: (placementId) {
          print('✅ Rewarded ad completed for placement: $placementId');
          _lastAdTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        },
        onFailed: (placementId, error, message) {
          print('❌ Rewarded ad failed:');
          print('Placement ID: $placementId');
          print('Error: $error');
          print('Message: $message');
        },
        onStart: (placementId) {
          print('Rewarded ad started for placement: $placementId');
        },
        onSkipped: (placementId) {
          print('Rewarded ad skipped for placement: $placementId');
        },
      );
    } catch (e) {
      print('Error showing rewarded ad: $e');
    }
  }

  // Add getters for the private fields
  static String? get currentIP => _currentIP;
  static String? get currentSessionId => _currentSessionId;
} 