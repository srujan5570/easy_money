import 'package:flutter/material.dart';
import '../helpers/unity_ad_helper.dart';

class UnityBannerAdWidget extends StatefulWidget {
  final double height;
  final bool autoLoad;

  const UnityBannerAdWidget({
    super.key, 
    this.height = 50.0,
    this.autoLoad = true,
  });

  @override
  State<UnityBannerAdWidget> createState() => _UnityBannerAdWidgetState();
}

class _UnityBannerAdWidgetState extends State<UnityBannerAdWidget> {
  bool _isAdLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final result = await UnityAdHelper.loadBannerAd();
    if (mounted) {
      setState(() {
        _isAdLoaded = result.isLoaded;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      color: Colors.transparent,
      child: UnityAdHelper.getBannerAd(
        onLoad: (placementId) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _error = null;
            });
          }
          print('Banner ad loaded successfully: $placementId');
        },
        onFailed: (placementId, error, message) {
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _error = message;
            });
          }
          print('Banner ad failed to load: $message');
        },
      ),
    );
  }
} 