import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_wheel.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import '../helpers/unity_ad_helper.dart';
import '../screens/leaderboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLoading = false;
  bool _isSpinning = false;
  int _adsWatched = 0;
  bool _isWatchingAd = false;
  bool _isProcessingReward = false;
  bool _canWatchAd = true;

  // Define the rewards and their angles on the wheel
  final List<Map<String, dynamic>> _wheelItems = [
    {'points': 5, 'angle': 0.0},
    {'points': 15, 'angle': math.pi / 4},
    {'points': 30, 'angle': math.pi / 2},
    {'points': 50, 'angle': 3 * math.pi / 4},
    {'points': 65, 'angle': math.pi},
    {'points': 75, 'angle': 5 * math.pi / 4},
    {'points': 90, 'angle': 3 * math.pi / 2},
    {'points': 100, 'angle': 7 * math.pi / 4},
  ];

  @override
  void initState() {
    super.initState();
    print('\n=== SpinScreen Initialized ===');
    // Randomize the wheel positions
    final random = math.Random();
    _wheelItems.shuffle(random);
    
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCirc),
    );

    // Load saved ad count
    _loadSavedAdCount();
  }

  Future<void> _loadSavedAdCount() async {
    print('\n=== Loading Saved Ad Count ===');
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        print('Loading for user: ${user.uid}');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('adProgress')
            .doc('extraSpin')
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final lastWatchTime = (data['lastWatchTime'] as Timestamp).toDate();
          final timeDiff = DateTime.now().difference(lastWatchTime);
          
          print('Last watch time: $lastWatchTime');
          print('Time difference: ${timeDiff.inHours} hours');
          print('Current ads watched: ${data['adsWatched']}');
          print('Can watch ads: ${data['canWatchAd']}');

          // Reset if more than 1 hour has passed
          if (timeDiff.inHours >= 1) {
            print('More than 1 hour passed - Resetting progress');
            setState(() {
              _adsWatched = 0;
              _canWatchAd = true;
            });
            await _saveAdCount(); // Save the reset state
          } else {
            print('Less than 1 hour passed - Loading saved progress');
            setState(() {
              _adsWatched = data['adsWatched'] ?? 0;
              _canWatchAd = data['canWatchAd'] ?? true;
            });
          }
        } else {
          print('No saved progress found - Starting fresh');
          await _saveAdCount(); // Initialize with default values
        }
      }
    } catch (e) {
      print('❌ Error loading saved ad count: $e');
    }
  }

  Future<void> _saveAdCount() async {
    print('\n=== Saving Ad Count ===');
    print('Ads watched: $_adsWatched');
    print('Can watch ads: $_canWatchAd');
    
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        print('Saving for user: ${user.uid}');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('adProgress')
            .doc('extraSpin')
            .set({
          'adsWatched': _adsWatched,
          'canWatchAd': _canWatchAd,
          'lastWatchTime': FieldValue.serverTimestamp(),
        });
        print('✅ Progress saved successfully');
      }
    } catch (e) {
      print('❌ Error saving ad count: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _watchAdForSpin() async {
    print('\n=== Watch Ad For Spin ===');
    print('Current state:');
    print('- Ads watched: $_adsWatched');
    print('- Is watching ad: $_isWatchingAd');
    print('- Is processing reward: $_isProcessingReward');
    print('- Can watch ad: $_canWatchAd');

    if (_isWatchingAd || _isProcessingReward || !_canWatchAd) {
      print('❌ Cannot watch ad:');
      print('- Is watching ad: $_isWatchingAd');
      print('- Is processing reward: $_isProcessingReward');
      print('- Can watch ad: $_canWatchAd');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, processing previous ad...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isWatchingAd = true);
    print('Starting ad watch process...');

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading ad, please wait...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Show the Unity rewarded ad
      final adResult = await UnityAdHelper.showRewardedAd(context);
      print('Ad show result: ${adResult.success}');

      if (adResult.success) {
        print('✅ User completed watching the ad');
        setState(() {
          _adsWatched++;
          _isWatchingAd = false;
          _isProcessingReward = true;
        });
        
        print('Incremented ads watched to: $_adsWatched');
        
        // Save progress
        await _saveAdCount();
        setState(() => _isProcessingReward = false);
        
        if (_adsWatched >= 5) {
          // Reset counter and add spin
          setState(() {
            _adsWatched = 0;
            _canWatchAd = false;
          });
          
          // Add spin and update UI
          final user = Provider.of<AuthProvider>(context, listen: false).user;
          if (user != null) {
            try {
              final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
              
              // Get current values first
              final userData = await userRef.get();
              final currentSpins = userData.data()?['remainingSpins'] ?? 0;
              final currentSpinsToday = userData.data()?['spinsToday'] ?? 0;
              
              // Update with incremented values
              await userRef.update({
                'remainingSpins': currentSpins + 1,
                'spinsToday': currentSpinsToday + 1,
              });
              
              print('✅ Updated spins:');
              print('Previous remainingSpins: $currentSpins');
              print('New remainingSpins: ${currentSpins + 1}');
              print('Previous spinsToday: $currentSpinsToday');
              print('New spinsToday: ${currentSpinsToday + 1}');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Congratulations! You earned a free spin!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              print('❌ Error updating spins: $e');
              // Reset states if update fails
              setState(() {
                _adsWatched = 4; // Keep progress but don't award spin
                _canWatchAd = true;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error updating spins. Please try again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
          }
          
          // Start cooldown timer
          _startCooldown();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✨ Great! Watch ${5 - _adsWatched} more ads to earn a free spin!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        print('❌ Ad failed or was not completed');
        setState(() => _isWatchingAd = false);
        
        if (mounted) {
          final message = adResult.error != null 
            ? adResult.error!
            : 'Failed to show ad. Please try again.';
          
          final isLoadFailure = adResult.error?.contains('load') == true || 
                              adResult.error?.contains('No ad available') == true;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isLoadFailure ? Colors.orange : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error in ad process: $e');
      setState(() => _isWatchingAd = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again later.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _startCooldown() async {
    print('\n=== Starting Cooldown ===');
    setState(() => _canWatchAd = false);
    await Future.delayed(const Duration(hours: 1));
    if (mounted) {
      print('Cooldown complete - Enabling ad watching');
      setState(() => _canWatchAd = true);
    }
  }

  Future<void> _handleAdResult(AdResult adResult) async {
    if (adResult.success) {
      if (adResult.completedFiveAds) {
        setState(() {
          _adsWatched++;
        });
        await _saveAdCount();
      }
      // ... rest of success handling
    } else {
      if (adResult.shouldShowRetry) {
        bool shouldRetry = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Ad Load Failed'),
              content: const Text('Would you like to try loading the ad again?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('Retry'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ?? false;

        if (shouldRetry) {
          // Show loading indicator
          setState(() {
            _isWatchingAd = true;
          });

          // Wait a moment before retrying
          await Future.delayed(const Duration(seconds: 1));
          
          // Try showing ad again
          AdResult retryResult = await UnityAdHelper.showRewardedAd(context);
          setState(() {
            _isWatchingAd = false;
          });
          await _handleAdResult(retryResult); // Handle the retry result recursively
        }
      } else {
        // Show error message for non-retry failures
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adResult.error ?? 'Failed to show ad'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _loadRewardedAd() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading ad, please wait...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Try to load the ad immediately
    await UnityAdHelper.loadRewardedAd();
    await Future.delayed(const Duration(seconds: 2));
    
    if (!UnityAdHelper.hasLoadedRewardedAd) {
      bool shouldRetry = await _showRetryDialog();
      while (shouldRetry) {
        // Show loading indicator again
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading ad, please wait...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        await UnityAdHelper.loadRewardedAd();
        await Future.delayed(const Duration(seconds: 2));
        
        if (UnityAdHelper.hasLoadedRewardedAd) {
          return true;
        }
        
        shouldRetry = await _showRetryDialog();
      }
      return false;
    }
    
    return true;
  }

  Future<bool> _showRetryDialog() async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ad Load Failed'),
        content: const Text('Failed to load the ad. Would you like to try again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  Future<void> _onSpinPressed() async {
    if (_isSpinning || _isLoading) return;

    setState(() {
      _isSpinning = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to spin')),
      );
      setState(() {
        _isSpinning = false;
      });
      return;
    }

    if (user.remainingSpins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spins left for today')),
      );
      setState(() {
        _isSpinning = false;
      });
      return;
    }

    // Check if we have a preloaded rewarded ad
    if (!UnityAdHelper.hasLoadedRewardedAd) {
      final adLoaded = await _loadRewardedAd();
      if (!adLoaded) {
        setState(() {
          _isSpinning = false;
        });
        return;
      }
    }

    // Start loading the second rewarded ad for potential double reward
    UnityAdHelper.loadRewardedAd();

    final random = math.Random();
    final selectedIndex = random.nextInt(_wheelItems.length);
    final selectedItem = _wheelItems[selectedIndex];
    
    // Calculate final angle to ensure proper alignment
    final spinAngle = (8 * 2 * math.pi) + (2 * math.pi - (2 * math.pi * selectedIndex / _wheelItems.length));
    
    _animation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: spinAngle)
            .chain(CurveTween(curve: Curves.easeOutCirc)),
        weight: 100,
      ),
    ]).animate(_controller);

    _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 5000));

    setState(() {
      _isSpinning = false;
    });

    if (!mounted) return;

    // Show first rewarded ad (which was preloaded)
    AdResult firstAdResult;
    try {
      firstAdResult = await UnityAdHelper.showRewardedAd(context);
      
      // Only proceed if the first ad was watched completely
      if (!firstAdResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firstAdResult.error != null 
              ? firstAdResult.error!
              : 'Please watch the entire ad to claim your reward'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      print('Error showing first ad: $e');
      return;
    }

    if (!mounted) return;

    // Show the reward dialog
    final watchAd = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: Text('You won ${selectedItem['points']} points!\nWatch an ad to double your points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, thanks'),
          ),
          TextButton(
            onPressed: () async {
              if (!UnityAdHelper.hasLoadedRewardedAd) {
                // Show loading indicator in the dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading ad...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                
                // Try to load the ad immediately
                await UnityAdHelper.loadRewardedAd();
                await Future.delayed(const Duration(seconds: 2));
                
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }
                
                if (!UnityAdHelper.hasLoadedRewardedAd) {
                  bool shouldRetry = await _showRetryDialog();
                  while (shouldRetry && context.mounted) {
                    // Show loading indicator again
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading ad...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    
                    await UnityAdHelper.loadRewardedAd();
                    await Future.delayed(const Duration(seconds: 2));
                    
                    // Close loading dialog
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    
                    if (UnityAdHelper.hasLoadedRewardedAd) {
                      break;
                    }
                    
                    if (context.mounted) {
                      shouldRetry = await _showRetryDialog();
                    } else {
                      shouldRetry = false;
                    }
                  }
                  
                  if (!UnityAdHelper.hasLoadedRewardedAd) {
                    if (context.mounted) {
                      Navigator.pop(context, false);
                    }
                    return;
                  }
                }
              }
              Navigator.pop(context, true);
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (watchAd == true && UnityAdHelper.hasLoadedRewardedAd) {
        // Show the second rewarded ad that was loaded during spin
        final secondAdResult = await UnityAdHelper.showRewardedAd(context);
        
        // Update points based on whether the second ad was watched
        if (secondAdResult.success) {
          await auth.updateUserPoints(selectedItem['points'] * 2);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Congratulations! You earned ${selectedItem['points'] * 2} points!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // If second ad wasn't watched completely, award base points
          await auth.updateUserPoints(selectedItem['points']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You earned ${selectedItem['points']} points'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        // User chose not to watch second ad
        await auth.updateUserPoints(selectedItem['points']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You earned ${selectedItem['points']} points'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Start preloading the next rewarded ad for future spins
      UnityAdHelper.loadRewardedAd();
    } catch (e) {
      print('Error in reward process: $e');
      // Ensure user gets base points even if there's an error
      await auth.updateUserPoints(selectedItem['points']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You earned ${selectedItem['points']} points'),
          backgroundColor: Colors.blue,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    print('\n=== SpinScreen Build ===');
    print('User data:');
    print('- Remaining spins: ${user.remainingSpins}');
    print('- Spins today: ${user.spinsToday}');

    // Calculate spins left based on remaining spins field
    final spinsLeft = user.remainingSpins;
    final canSpin = spinsLeft > 0 && !_isSpinning && !_isLoading;

    print('Calculated values:');
    print('- Spins left: $spinsLeft');
    print('- Can spin: $canSpin');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/app_logo.png',
                    height: 32,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Easy Money',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  print('Manual refresh triggered');
                  // Force a refresh of the AuthProvider
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (auth.user != null) {
                    final userRef = FirebaseFirestore.instance.collection('users').doc(auth.user!.uid);
                    final freshData = await userRef.get();
                    if (freshData.exists) {
                      // Update through the provider's public methods
                      final updatedUser = UserModel.fromMap(freshData.data()!);
                      // Force a notification to listeners
                      auth.updateUserData(updatedUser);
                      print('Manual refresh completed');
                      print('Updated spins: ${updatedUser.remainingSpins}');
                    }
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Stats Cards
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total Points',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.stars_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${user.totalEarnings}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white24,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Spins Left',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.refresh_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$spinsLeft',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (canSpin) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Win up to 100 points per spin!',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Wheel Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: CustomWheel(
                                      animation: _animation,
                                      segments: _wheelItems.length,
                                      rewards: _wheelItems.map((item) => item['points'] as int).toList(),
                                    ),
                                  ),
                                  // Center decoration
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.stars_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 30,
                                    ),
                                  ),
                                  // Pointer at the top
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      width: 24,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                          bottom: Radius.circular(4),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              // Spin Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: canSpin ? _onSpinPressed : null,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                                    backgroundColor: canSpin 
                                        ? Theme.of(context).primaryColor 
                                        : Colors.grey.shade300,
                                  ),
                                  child: _isSpinning
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              canSpin ? Icons.play_circle_outline : Icons.lock_outline,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              canSpin ? 'SPIN NOW' : 'NO SPINS LEFT',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Watch Ads for Spins Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.campaign_rounded,
                                    color: Theme.of(context).primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'EARN EXTRA SPINS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _canWatchAd 
                                  ? 'Watch 5 ads to get 1 extra spin!'
                                  : 'Extra spin earned! Come back in 1 hour.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Progress indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index < _adsWatched
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade200,
                                      boxShadow: index < _adsWatched
                                          ? [
                                              BoxShadow(
                                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: index < _adsWatched
                                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                                          : Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: (_isWatchingAd || !_canWatchAd) ? null : _watchAdForSpin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                                  ),
                                  icon: _isWatchingAd
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.play_circle_outline),
                                  label: Text(
                                    _isWatchingAd 
                                      ? 'WATCHING AD...' 
                                      : !_canWatchAd 
                                        ? 'COME BACK IN 1 HOUR'
                                        : 'WATCH AD (${math.min(_adsWatched, 5)}/5)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Add Leaderboard Button
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          width: double.infinity,
                          height: 50,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LeaderboardScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.leaderboard),
                            label: const Text(
                              'LEADERBOARD',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
} 