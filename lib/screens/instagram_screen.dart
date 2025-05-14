import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../helpers/unity_ad_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoQuality {
  final String url;
  final String quality;
  final int width;
  final int height;

  VideoQuality({
    required this.url,
    required this.quality,
    required this.width,
    required this.height,
  });
}

class InstagramScreen extends StatefulWidget {
  const InstagramScreen({Key? key}) : super(key: key);

  @override
  State<InstagramScreen> createState() => _InstagramScreenState();
}

class _InstagramScreenState extends State<InstagramScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _reelsScrollCount = 0;
  bool _isShowingAd = false;
  bool _isDownloading = false;
  String _currentUrl = '';
  final _mediaStore = MediaStore();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    
    // For Android 13 and above
    if (await Permission.photos.status.isDenied) {
      await Permission.photos.request();
    }
    if (await Permission.videos.status.isDenied) {
      await Permission.videos.request();
    }
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            await _injectScrollTracker();
            await _injectVideoExtractor();
            await _optimizeForLowBandwidth();
          },
          onUrlChange: (UrlChange change) {
            setState(() {
              _currentUrl = change.url ?? '';
            });
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false);

    await _controller.loadRequest(Uri.parse('https://www.instagram.com/'));
  }

  Future<void> _optimizeForLowBandwidth() async {
    await _controller.runJavaScript('''
      // Disable high-quality images initially
      document.querySelectorAll('img').forEach(img => {
        img.loading = 'lazy';
        if (img.srcset) {
          img.srcset = img.srcset.split(',')[0]; // Use lowest quality initially
        }
      });

      // Optimize video loading
      document.querySelectorAll('video').forEach(video => {
        video.preload = 'metadata';
        video.setAttribute('playsinline', '');
        video.setAttribute('data-quality-optimized', 'true');
      });

      // Remove unnecessary elements
      document.querySelectorAll('[role="presentation"]').forEach(el => el.remove());
      document.querySelectorAll('.non-essential-content').forEach(el => el.remove());
    ''');
  }

  Future<void> _injectVideoExtractor() async {
    await _controller.runJavaScript('''
      window.findVideoQualities = async function() {
        try {
          const qualities = [];
          
          // Check if we're on a reel page
          const isReelPage = window.location.pathname.includes('/reels/') || 
                           window.location.pathname.includes('/reel/') || 
                           window.location.pathname.includes('/p/');
          
          if (!isReelPage) {
            console.log('Not on a reel page');
            return qualities;
          }

          // Wait for video data to load (up to 5 seconds)
          for (let i = 0; i < 50; i++) {
            if (window.__additionalDataLoaded || window._sharedData) {
              break;
            }
            await new Promise(resolve => setTimeout(resolve, 100));
          }
          
          // Check for video data in window.__additionalDataLoaded
          if (window.__additionalDataLoaded) {
            console.log('Found __additionalDataLoaded');
            const data = window.__additionalDataLoaded;
            if (data.items && data.items[0] && data.items[0].video_versions) {
              console.log('Found video versions:', data.items[0].video_versions);
              data.items[0].video_versions.forEach(version => {
                qualities.push({
                  url: version.url,
                  quality: version.type || 'Default',
                  width: version.width,
                  height: version.height
                });
              });
            }
          }

          // Check for video data in window._sharedData
          if (window._sharedData && window._sharedData.entry_data) {
            console.log('Found _sharedData');
            const entryData = window._sharedData.entry_data;
            if (entryData.PostPage && entryData.PostPage[0] && entryData.PostPage[0].graphql) {
              const media = entryData.PostPage[0].graphql.shortcode_media;
              if (media && media.video_url) {
                console.log('Found video URL in _sharedData:', media.video_url);
                qualities.push({
                  url: media.video_url,
                  quality: 'HD',
                  width: media.dimensions.width,
                  height: media.dimensions.height
                });
              }
            }
          }

          // Check for video URLs in script tags
          const scripts = document.getElementsByTagName('script');
          console.log('Checking', scripts.length, 'script tags');
          for (const script of scripts) {
            const content = script.textContent || '';
            if (content.includes('video_url')) {
              console.log('Found script with video_url');
              const urlMatches = content.match(/"video_url":"([^"]+)"/g);
              if (urlMatches) {
                console.log('Found URL matches:', urlMatches);
                urlMatches.forEach(match => {
                  const url = match.match(/"video_url":"([^"]+)"/)[1].replace(/\\\\/g, '');
                  qualities.push({
                    url: url,
                    quality: 'Default',
                    width: 720,
                    height: 1280
                  });
                });
              }
            }
          }

          // Wait for video elements to load (up to 2 seconds)
          for (let i = 0; i < 20; i++) {
            const videoElements = document.getElementsByTagName('video');
            const sourceElements = document.getElementsByTagName('source');
            if (videoElements.length > 0 || sourceElements.length > 0) {
              break;
            }
            await new Promise(resolve => setTimeout(resolve, 100));
          }

          // Check video elements
          const videoElements = document.getElementsByTagName('video');
          console.log('Found', videoElements.length, 'video elements');
          for (const video of videoElements) {
            if (video.src && !video.src.startsWith('blob:')) {
              console.log('Found video source:', video.src);
              qualities.push({
                url: video.src,
                quality: 'Default',
                width: video.videoWidth || 720,
                height: video.videoHeight || 1280
              });
            }
          }

          // Check source elements
          const sourceElements = document.getElementsByTagName('source');
          console.log('Found', sourceElements.length, 'source elements');
          for (const source of sourceElements) {
            if (source.src && !source.src.startsWith('blob:')) {
              console.log('Found source URL:', source.src);
              qualities.push({
                url: source.src,
                quality: source.getAttribute('quality') || 'Default',
                width: 720,
                height: 1280
              });
            }
          }

          // Check meta tags for video content
          const metaTags = document.getElementsByTagName('meta');
          console.log('Found', metaTags.length, 'meta tags');
          for (const meta of metaTags) {
            const content = meta.getAttribute('content') || '';
            if (content.includes('video_url')) {
              console.log('Found meta tag with video content:', content);
              try {
                const data = JSON.parse(content);
                if (data.video_url) {
                  qualities.push({
                    url: data.video_url,
                    quality: 'Default',
                    width: 720,
                    height: 1280
                  });
                }
              } catch (e) {
                console.error('Error parsing meta content:', e);
              }
            }
          }

          console.log('Found qualities:', qualities);
          return qualities;
        } catch (e) {
          console.error('Error finding video qualities:', e);
          return [];
        }
      };
    ''');
  }

  Future<List<VideoQuality>> _getVideoQualities() async {
    try {
      // Run the JavaScript function and wait for the promise to resolve
      final result = await _controller.runJavaScriptReturningResult('(async () => { return JSON.stringify(await window.findVideoQualities()); })()');
      print('Raw JavaScript result: $result');

      if (result == null) {
        print('No result from JavaScript');
        return [];
      }

      // The result is already a string since we used JSON.stringify in JavaScript
      final String jsonString = result.toString();
      if (jsonString.isEmpty || jsonString == '[]') {
        print('Empty result from JavaScript');
        return [];
      }

      // Parse the JSON array
      final List<dynamic> qualities = jsonDecode(jsonString);
      
      // Map each quality object to a VideoQuality instance
      return qualities.map((quality) {
        final url = quality['url'] as String;
        if (url.isEmpty) {
          throw Exception('Empty URL found in quality object');
        }
        
        return VideoQuality(
          url: url,
          quality: quality['quality'] as String? ?? 'Default',
          width: quality['width'] as int? ?? 720,
          height: quality['height'] as int? ?? 1280,
        );
      }).where((quality) => quality.url.isNotEmpty && !quality.url.startsWith('blob:')).toList();
    } catch (e) {
      print('Error getting video qualities: $e');
      return [];
    }
  }

  Future<VideoQuality?> _showQualityDialog(List<VideoQuality> qualities) async {
    return showDialog<VideoQuality>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities.map((quality) => ListTile(
            title: Text('${quality.quality} (${quality.width}x${quality.height})'),
            onTap: () {
              Navigator.pop(context, quality);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _injectScrollTracker() async {
    await _controller.runJavaScript('''
      let lastScrollY = 0;
      document.addEventListener('scroll', function() {
        if (window.location.pathname.includes('/reels/')) {
          const currentScrollY = window.scrollY;
          if (currentScrollY > lastScrollY + 100) {
            window.flutter_inappwebview.callHandler('onReelScroll');
            lastScrollY = currentScrollY;
          }
        }
      });
    ''');
  }

  Future<void> _handleReelScroll() async {
    if (_isShowingAd) return;

    _reelsScrollCount++;
    print('Reels scrolled: $_reelsScrollCount');

    if (_reelsScrollCount >= 5) {
      _isShowingAd = true;
      
      // First try to show an interstitial ad
      try {
        if (UnityAdHelper.hasLoadedInterstitialAd) {
          await UnityAdHelper.showInterstitialAd(context);
        } else {
          // If no interstitial ad is ready, show a rewarded ad
          await UnityAdHelper.showRewardedAd(context);
        }
      } catch (e) {
        print('Error showing ad: $e');
      } finally {
        // Reset counter and flag
        _reelsScrollCount = 0;
        _isShowingAd = false;
        
        // Preload next ad
        UnityAdHelper.loadInterstitialAd();
        UnityAdHelper.loadRewardedAd();
      }
    }
  }

  Future<void> _downloadReel() async {
    if (!_isReelsPage || _isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // Get available qualities
      final qualities = await _getVideoQualities();
      
      if (qualities.isEmpty) {
        throw 'Could not find video URL. Please make sure you are on a reel page.';
      }

      // Show quality selection dialog
      if (!mounted) return;
      final selectedQuality = await _showQualityDialog(qualities);
      
      if (selectedQuality == null) {
        setState(() => _isDownloading = false);
        return;
      }

      // Show downloading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting download...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Get video data
      final response = await http.get(Uri.parse(selectedQuality.url));
      if (response.statusCode != 200) {
        throw 'Failed to download video (Status: ${response.statusCode})';
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'Instagram_Reel_${selectedQuality.quality}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempPath = '${directory.path}/$fileName';
      
      // Save to temporary file first
      await File(tempPath).writeAsBytes(response.bodyBytes);

      // Save to gallery using media_store_plus
      await _mediaStore.saveFile(
        tempFilePath: tempPath,
        dirType: DirType.video,
        dirName: DirName.movies,
      );

      // Clean up temporary file
      await File(tempPath).delete();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reel saved to gallery in ${selectedQuality.quality} quality!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Show ad after successful download
      if (mounted) {
        try {
          if (UnityAdHelper.hasLoadedInterstitialAd) {
            await UnityAdHelper.showInterstitialAd(context);
          } else {
            await UnityAdHelper.loadInterstitialAd();
            await UnityAdHelper.showInterstitialAd(context);
          }
        } catch (e) {
          print('Error showing ad after download: $e');
        }
      }

    } catch (e) {
      print('Error downloading reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download reel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  bool get _isReelsPage {
    return _currentUrl.contains('/reels/') || 
           _currentUrl.contains('/reel/') || 
           _currentUrl.contains('/p/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
              _reelsScrollCount = 0;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: _isReelsPage
          ? FloatingActionButton(
              onPressed: _isDownloading ? null : _downloadReel,
              backgroundColor: _isDownloading ? Colors.grey : Theme.of(context).primaryColor,
              child: _isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
} 