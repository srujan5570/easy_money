class AppConstants {
  // App Information
  static const String appName = 'Easy Money';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String transactionsCollection = 'transactions';

  // Points and Rewards
  static const int dailyBonusPoints = 100;
  static const int referralBonusPoints = 2000; // ₹2 = 2000 points
  static const int spinWinPoints = 10;
  static const int adWatchBonusMultiplier = 2;
  static const int maxSpinsPerDay = 5;
  static const int pointsToRupeeRatio = 1000; // 1000 points = ₹1

  // Spin Rewards
  static const List<int> spinRewards = [100, 10, 25, 50, 25, 10, 100, 50];

  // Withdrawal Settings
  static const int minWithdrawalAmount = 100;
  static const int maxWithdrawalAmount = 1000;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const double defaultElevation = 2.0;

  // Animation Durations
  static const Duration spinDuration = Duration(seconds: 3);
  static const Duration toastDuration = Duration(seconds: 2);

  // Validation
  static const int minUpiIdLength = 4;
  static const int maxUpiIdLength = 50;
  static const String upiIdRegex = r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$';

  // Error Messages
  static const String invalidUpiIdMessage = 'Please enter a valid UPI ID';
  static const String insufficientPointsMessage = 'Insufficient points for withdrawal';
  static const String maxSpinsReachedMessage = 'You have reached the maximum spins for today';
} 