import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_money/providers/auth_provider.dart';
import 'package:easy_money/screens/home_screen.dart';
import 'package:easy_money/screens/login_screen.dart';
import 'package:easy_money/constants.dart';
import 'package:easy_money/services/firebase_service.dart';
import 'helpers/unified_ad_helper.dart';
import 'helpers/unity_ad_helper.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:easy_money/providers/game_progress_provider.dart';
import 'screens/version_check_screen.dart';
import 'services/location_service.dart';
import 'screens/location_restriction_screen.dart';
import 'services/unity_ads_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Start with loading screen
    runApp(const MyApp(isInitializing: true));
    
    // Load environment variables
    await dotenv.load(fileName: '.env');
    
    // Initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    
    print('\n=== Ad SDKs Initialization ===');
    
    // Initialize Unity Ads SDK
    print('Initializing Unity Ads SDK...');
    await UnityAdHelper.initialize();
    
    // Initialize AdMob SDK
    print('\nInitializing AdMob SDK...');
    await MobileAds.instance.initialize();

    // Configure for production ads
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        testDeviceIds: [],
      ),
    );

    // Remove app open ad since we can't get context here
    // await UnifiedAdHelper.showUnifiedInterstitialAd();

    // Update app to initialized state
    runApp(const MyApp(isInitializing: false));
  } catch (e) {
    print('Error during initialization: $e');
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  final bool isInitializing;
  const MyApp({super.key, this.isInitializing = true});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Show ad when app is resumed from background, only if we have context
      if (mounted) {
        UnifiedAdHelper.showUnifiedInterstitialAd(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => GameProgressProvider()),
      ],
      child: MaterialApp(
        title: 'Easy Money',
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => widget.isInitializing 
            ? const LoadingScreen()
            : const LocationCheckWrapper(),
        },
      ),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _currentMessage = '';
  
  final List<String> _welcomeMessages = [
    "✨ Welcome back! Ready to win big? ✨",
    "🌟 Your lucky day is loading... 🌟",
    "🎯 Get ready for amazing rewards! 🎯",
    "🎁 Exciting surprises coming your way! 🎁",
    "🌈 Making your day brighter! 🌈",
    "🍀 Loading your lucky moments... 🍀",
    "💫 Your winning streak starts here! 💫",
    "🎮 Fun times ahead! 🎮",
    "🌺 Welcome to a world of rewards! 🌺",
    "🎨 Creating magic moments for you... 🎨",
    "🚀 Preparing your adventure... 🚀",
    "🌞 Another beautiful day to win! 🌞",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _currentMessage = _getRandomMessage();
    _controller.forward();

    // Change message every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _controller.reset();
        setState(() {
          _currentMessage = _getRandomMessage();
        });
        _controller.forward();
      }
    });
  }

  String _getRandomMessage() {
    return _welcomeMessages[DateTime.now().millisecondsSinceEpoch % _welcomeMessages.length];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/app_logo.png',
              height: 120,
              width: 120,
            ),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  _currentMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class LocationCheckWrapper extends StatefulWidget {
  const LocationCheckWrapper({Key? key}) : super(key: key);

  @override
  State<LocationCheckWrapper> createState() => _LocationCheckWrapperState();
}

class _LocationCheckWrapperState extends State<LocationCheckWrapper> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    final allowed = await LocationService.isLocationAllowed();
    if (mounted) {
      setState(() {
        _checking = false;
        _allowed = allowed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_allowed) {
      return const LocationRestrictionScreen();
    }

    // Return the auth flow if location is allowed
    return StreamBuilder(
      stream: FirebaseService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        return snapshot.hasData 
          ? const VersionCheckWrapper() 
          : const LoginScreen();
      },
    );
  }
}

class VersionCheckWrapper extends StatelessWidget {
  const VersionCheckWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VersionCheckScreen();
  }
}
