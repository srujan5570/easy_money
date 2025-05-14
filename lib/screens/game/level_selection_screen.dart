import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_card.dart';
import '../../theme/app_theme.dart';
import '../../helpers/unified_ad_helper.dart';
import '../../widgets/unity_banner_ad.dart';
import '../../services/unity_ads_service.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  Widget? _adWidget;

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
    final user = Provider.of<AuthProvider>(context).user;
    // Default to level 1 if user is null or we don't have a level field
    final userLevel = 1; // Simplified as user model doesn't have level property

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level'),
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
              'Select a Level',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 10, // Total number of levels
              itemBuilder: (context, index) {
                final level = index + 1;
                final isUnlocked = level <= userLevel;
                
                return CustomCard(
                  color: isUnlocked
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  child: InkWell(
                    onTap: isUnlocked
                        ? () {
                            // Navigate to the game for this level
                            Navigator.pop(context, level);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isUnlocked ? Icons.lock_open : Icons.lock,
                          color: isUnlocked
                              ? AppTheme.primaryColor
                              : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Level $level',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked
                                ? AppTheme.textColor
                                : Colors.grey,
                          ),
                        ),
                        if (level == userLevel)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomUnityBannerAd(
            placementId: UnityAdsService.getBannerPlacementId('level_selection'),
          ),
        ],
      ),
    );
  }
} 