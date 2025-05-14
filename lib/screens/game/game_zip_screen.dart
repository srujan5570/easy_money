import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_card.dart';
import '../../helpers/unified_ad_helper.dart';
import '../../widgets/unity_banner_ad.dart';
import '../../services/unity_ads_service.dart';

class GameZipScreen extends StatefulWidget {
  const GameZipScreen({super.key});

  @override
  State<GameZipScreen> createState() => _GameZipScreenState();
}

class _GameZipScreenState extends State<GameZipScreen> {
  Widget? _adWidget;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    final adWidget = await UnifiedAdHelper.loadUnifiedBannerAd();
    if (mounted && adWidget != null) {
      setState(() {
        _adWidget = adWidget;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zip Code Game'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_adWidget != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _adWidget!,
              ),
            const Text(
              'Zip Code Game',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Complete this game to earn points',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                // Game logic would go here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Game feature is under development'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Start Game',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomUnityBannerAd(
            placementId: UnityAdsService.getBannerPlacementId('game_zip'),
          ),
        ],
      ),
    );
  }
} 