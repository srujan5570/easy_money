import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class CustomUnityBannerAd extends StatefulWidget {
  final String placementId;
  final double height;

  const CustomUnityBannerAd({
    Key? key,
    required this.placementId,
    this.height = 50,
  }) : super(key: key);

  @override
  State<CustomUnityBannerAd> createState() => _CustomUnityBannerAdState();
}

class _CustomUnityBannerAdState extends State<CustomUnityBannerAd> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: UnityBannerAd(
        placementId: widget.placementId,
      ),
    );
  }
} 