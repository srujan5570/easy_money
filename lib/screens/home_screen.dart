import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_card.dart';
import '../theme/app_theme.dart';
import '../widgets/unity_banner_ad_widget.dart';
import 'spin_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import '../helpers/unity_ad_helper.dart';
import 'game/games_screen.dart';
import '../widgets/unity_banner_ad.dart';
import '../services/unity_ads_service.dart';
import 'instagram_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAdReady = false;
  int _loadedAdsCount = 0;
  static const int _maxAdsToLoad = 5;

  final List<Widget> _screens = [
    const SpinScreen(),
    const GamesScreen(),
    const WalletScreen(),
    const InstagramScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    
    // Initialize Unity Ads and start loading multiple ads
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    await UnityAdHelper.initialize();
    setState(() {
      _isAdReady = true;
    });
    
    // Start loading multiple ads
    _loadMultipleAds();
  }

  Future<void> _loadMultipleAds() async {
    // Load initial batch of ads
    for (int i = 0; i < _maxAdsToLoad; i++) {
      _loadNextAd();
    }
  }

  Future<void> _loadNextAd() async {
    if (_loadedAdsCount < _maxAdsToLoad) {
      try {
        await UnityAdHelper.loadInterstitialAd();
        if (mounted) {
          setState(() {
            _loadedAdsCount++;
          });
        }
        print('Loaded ad $_loadedAdsCount of $_maxAdsToLoad');
      } catch (e) {
        print('Error loading interstitial ad: $e');
        // Retry loading after a short delay
        await Future.delayed(const Duration(seconds: 1));
        _loadNextAd();
      }
    }
  }

  Future<void> _showInterstitialAd() async {
    if (_isAdReady && _loadedAdsCount > 0) {
      try {
        await UnityAdHelper.showInterstitialAd(context);
        // Decrease loaded ads count and load a new one
        if (mounted) {
          setState(() {
            _loadedAdsCount--;
          });
        }
        // Load next ad to maintain the queue
        _loadNextAd();
      } catch (e) {
        print('Error showing interstitial ad: $e');
        // If showing fails, try to load a new ad
        _loadNextAd();
      }
    } else {
      // If no ads are ready, try to load one
      _loadNextAd();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) async {
    // Always show ad when navigating between any screens
    if (_currentIndex != index) {  // Only show ad if actually changing screens
      await _showInterstitialAd();
    }
    
    // Then update the UI
    if (mounted) {
    setState(() {
      _currentIndex = index;
    });
    _controller.reset();
    _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _screens[_currentIndex],
            ),
            const SizedBox(height: 8),
            const UnityBannerAdWidget(
              height: 50.0,
              autoLoad: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomUnityBannerAd(
            placementId: UnityAdsService.getBannerPlacementId('home'),
          ),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onItemTapped,
                backgroundColor: AppTheme.surfaceColor,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: AppTheme.secondaryTextColor,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.casino),
                    activeIcon: Icon(Icons.casino, size: 28),
                    label: 'Spin',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.sports_esports),
                    activeIcon: Icon(Icons.sports_esports, size: 28),
                    label: 'Games',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet),
                    activeIcon: Icon(Icons.account_balance_wallet, size: 28),
                    label: 'Wallet',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.photo_camera),
                    activeIcon: Icon(Icons.photo_camera, size: 28),
                    label: 'Instagram',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    activeIcon: Icon(Icons.person, size: 28),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 