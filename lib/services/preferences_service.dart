import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _factPrefsKey = 'fact_preferences';
  
  static const Map<String, String> factCategories = {
    'whatsapp_quotes': 'WhatsApp Quotes',
    'gaming': 'Gaming News',
    'indian_news': 'Indian News',
    'american_news': 'American News',
    'software': 'New Software Updates',
    'crypto': 'Crypto News & Facts',
    'nft': 'NFT News',
    'stock': 'Stock Market News & Facts',
    'weather': 'Weather Updates',
    'healthcare': 'Healthcare News',
    'fitness': 'Fitness & Yoga'
  };

  static Future<Set<String>> getSelectedFactCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList(_factPrefsKey);
    if (categories == null || categories.isEmpty) {
      // Default to all categories selected
      return factCategories.keys.toSet();
    }
    return categories.toSet();
  }

  static Future<void> saveSelectedFactCategories(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_factPrefsKey, categories.toList());
  }
} 