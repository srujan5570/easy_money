import 'dart:convert';
import 'package:http/http.dart' as http;
import 'preferences_service.dart';
import 'dart:math';
import 'package:collection/collection.dart';

class FactsService {
  static const String _newsApiKey = '070356a312484f67bb275cf5b4035cce'; // Replace with your API key
  static const String _newsApiUrl = 'https://newsapi.org/v2/everything';
  
  // Cache control - reduced cache time to 2 minutes for fresher updates
  static DateTime? _lastFetchTime;
  static String? _cachedFact;
  static Set<String>? _lastUsedCategories;
  
  // Keep track of recently shown items with timestamps
  static final Map<String, DateTime> _recentlyShownFacts = {};
  static final Map<String, DateTime> _recentlyShownQuotes = {};
  static int _currentPage = 1;
  static const int _maxRecentItems = 15; // Increased to allow more variety
  static const Duration _factRepeatDelay = Duration(hours: 12); // Only repeat facts after 12 hours
  
  // List of predefined quotes as fallback
  static const List<Map<String, String>> _fallbackQuotes = [
    {"content": "Be the change you wish to see in the world.", "author": "Mahatma Gandhi"},
    {"content": "Success is not final, failure is not fatal: it is the courage to continue that counts.", "author": "Winston Churchill"},
    {"content": "The only way to do great work is to love what you do.", "author": "Steve Jobs"},
    {"content": "Life is what happens when you're busy making other plans.", "author": "John Lennon"},
    {"content": "The future belongs to those who believe in the beauty of their dreams.", "author": "Eleanor Roosevelt"},
    {"content": "Everything you've ever wanted is on the other side of fear.", "author": "George Addair"},
    {"content": "Success usually comes to those who are too busy to be looking for it.", "author": "Henry David Thoreau"},
    {"content": "The best way to predict the future is to create it.", "author": "Peter Drucker"},
    {"content": "If you want to lift yourself up, lift up someone else.", "author": "Booker T. Washington"},
    {"content": "The only limit to our realization of tomorrow will be our doubts of today.", "author": "Franklin D. Roosevelt"}
  ];

  // List of predefined facts as fallback
  static const Map<String, List<String>> _fallbackFacts = {
    'gaming': [
      "The gaming industry generates more revenue than movies and music combined! 🎮",
      "Nintendo was founded in 1889 as a playing card company! 🎴",
      "The first gaming console had no memory card - games couldn't be saved! 💾",
      "The longest video game marathon lasted 138 hours and 34 minutes! 🏆",
      "The most expensive video game ever developed cost \$265 million! 💰",
      "Minecraft has sold over 238 million copies worldwide! ⛏️",
      "The first video game was created in 1958! 🕹️",
      "The PlayStation 2 is the best-selling console of all time! 🎮",
      "The term 'Easter Egg' for hidden features came from Adventure (1979)! 🥚",
      "Super Mario originally was a carpenter, not a plumber! 🔧",
      "The term 'Sandbox Game' comes from actual children's sandboxes! 🏖️",
      "The first gaming tournament was held in 1972 at Stanford University! 🏆",
      "The highest-earning game is GTA V with over \$6 billion in revenue! 💵",
      "The most expensive gaming PC cost over \$30,000! 💻",
      "The first gaming mouse was invented in 1999! 🖱️",
      "The average age of a gamer is 34 years old! 👨‍🦰",
      "The most expensive virtual item sold for \$6 million! 💎",
      "The first 3D game was 3D Monster Maze in 1981! 👾",
      "The longest development time for a game was Duke Nukem Forever at 15 years! ⏳",
      "The first game console was the Magnavox Odyssey in 1972! 🎮"
    ],
    'tech': [
      "The first computer mouse was made of wood! 🖱️",
      "The first message sent over the internet was 'LO'! 💻",
      "The first YouTube video was uploaded on April 23, 2005! 🎥",
      "About 90% of the world's data was created in the last two years! 📊",
      "The first computer virus was created in 1983! 🦠",
      "The first website is still online today! 🌐",
      "The average smartphone today has more computing power than NASA in 1969! 📱",
      "The term 'bug' in computing came from an actual moth! 🪲",
      "The first domain name ever registered was Symbolics.com! 🔤",
      "The first tweet was sent on March 21, 2006! 🐦",
      "The first hard drive could store only 5MB and weighed over a ton! 💽",
      "The first iPhone had only 128MB of RAM! 📱",
      "The word robot comes from the Czech word 'robota' meaning forced labor! 🤖",
      "The first computer programmer was Ada Lovelace! 👩‍💻",
      "The first computer game was created in 1962 called Spacewar! 🚀",
      "The first computer mouse was called the 'X-Y Position Indicator'! 🖱️",
      "The first computer virus was called Creeper! 🦠",
      "The first webcam was used to monitor a coffee pot! ☕",
      "The first email was sent in 1971! 📧",
      "The most expensive domain name sold for \$872 million! 💰"
    ],
    'science': [
      "The human brain can process images in just 13 milliseconds! 🧠",
      "A day on Venus is longer than its year! ⭐",
      "Honey never spoils! Archaeologists found 3,000-year-old honey! 🍯",
      "Bananas are berries, but strawberries aren't! 🍌",
      "A teaspoonful of neutron star would weigh 6 billion tons! ⚖️",
      "Light travels 6 trillion miles in a year! 💫",
      "The human body contains enough carbon for 900 pencils! ✏️",
      "There are more possible chess games than atoms in the universe! ♟️",
      "The average cloud weighs around 1.1 million pounds! ☁️",
      "DNA is 98% identical between humans and chimpanzees! 🧬",
      "The human body has enough iron to make a 3-inch nail! ⚒️",
      "A single lightning bolt contains enough energy to toast 100,000 slices of bread! ⚡",
      "The sun loses 4 million tons of mass every second! ☀️",
      "Butterflies taste with their feet! 🦋",
      "The average person spends 6 months of their lifetime waiting for red lights! 🚦",
      "A day on Mars is only 40 minutes longer than Earth! 🔴",
      "The human brain generates enough electricity to power a small light bulb! 💡",
      "Sharks have existed longer than trees! 🦈",
      "The fastest wind speed ever recorded was 253 miles per hour! 🌪️",
      "The smallest bone in your body is the size of a grain of rice! 🦴"
    ]
  };

  static Future<String> getLatestFact({bool forceRefresh = false}) async {
    try {
      final selectedCategories = await PreferencesService.getSelectedFactCategories();
      
      // Remove cache check since we want to force refresh every time
      if (selectedCategories.isEmpty) {
        return "Please select fact categories in settings! ⚙️";
      }

      _lastUsedCategories = selectedCategories;

      // Handle quotes separately
      if (selectedCategories.length == 1 && selectedCategories.contains('whatsapp_quotes')) {
        String quote;
        // Try up to 3 times to get a different quote than the last one
        for (int i = 0; i < 3; i++) {
          final randomQuote = _fallbackQuotes[Random().nextInt(_fallbackQuotes.length)];
          quote = 'Quote: "${randomQuote["content"]}" - ${randomQuote["author"]} 💭';
          
          // If this is a different quote than the last one, or we've tried 3 times, use it
          if (quote != _cachedFact || i == 2) {
            _cacheFact(quote);
            return quote;
          }
        }
      }

      // Build category-specific queries with more variety
      final newsCategories = <String, String>{
        'gaming': '(gaming OR "video games" OR esports OR "game development" OR "game industry")',
        'indian_news': '(India OR Indian) AND (technology OR innovation OR startup OR business)',
        'american_news': '(USA OR "United States") AND (technology OR innovation OR startup OR business)',
        'software': '(software OR "tech news" OR programming OR developers OR "artificial intelligence")',
        'crypto': '(cryptocurrency OR bitcoin OR ethereum OR "web3" OR blockchain)',
        'nft': '(NFT OR "non-fungible token" OR "digital art" OR "crypto art")',
        'stock': '(stock market OR investing OR "wall street" OR nasdaq OR "financial markets")',
        'weather': '(climate change OR "extreme weather" OR "global warming" OR environment)',
        'healthcare': '(healthcare OR medicine OR "medical breakthrough" OR "health technology")',
        'fitness': '(fitness OR "health tech" OR "digital health" OR "wellness technology")'
      };

      final activeCategories = selectedCategories.where((cat) => cat != 'whatsapp_quotes').toList();
      
      if (activeCategories.isEmpty) {
        String fact;
        // Try up to 3 times to get a different fact than the last one
        for (int i = 0; i < 3; i++) {
          final category = _fallbackFacts.keys.elementAt(Random().nextInt(_fallbackFacts.length));
          final facts = _fallbackFacts[category]!;
          fact = "[$category] ${facts[Random().nextInt(facts.length)]}";
          
          // If this is a different fact than the last one, or we've tried 3 times, use it
          if (fact != _cachedFact || i == 2) {
            _cacheFact(fact);
            return fact;
          }
        }
      }

      final selectedCategory = activeCategories[Random().nextInt(activeCategories.length)];
      final query = newsCategories[selectedCategory];

      try {
        // Always increment page number for each request
        _currentPage = (_currentPage % 5) + 1;
        
        final response = await http.get(
          Uri.parse(
            '$_newsApiUrl?q=$query&sortBy=publishedAt&pageSize=10&page=$_currentPage&language=en&apiKey=$_newsApiKey'
          ),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'error') {
            print('News API error: ${data['message']}');
            throw Exception(data['message']);
          }
          
          final articles = data['articles'] as List;
          if (articles.isNotEmpty) {
            String newsTitle;
            // Try up to 3 times to get a different article than the last one
            for (int i = 0; i < 3; i++) {
              final article = articles[Random().nextInt(articles.length)];
              final categoryName = PreferencesService.factCategories[selectedCategory] ?? selectedCategory;
              newsTitle = "[$categoryName] ${article['title']} 📰";
              
              // If this is a different article than the last one, or we've tried 3 times, use it
              if (newsTitle != _cachedFact || i == 2) {
                _cacheFact(newsTitle);
                return newsTitle;
              }
            }
          }
        }
        throw Exception('Failed to fetch news');
      } catch (e) {
        print('Error fetching news: $e');
        String fact;
        // Try up to 3 times to get a different fact than the last one
        for (int i = 0; i < 3; i++) {
          final fallbackCategory = _fallbackFacts.keys.elementAt(Random().nextInt(_fallbackFacts.length));
          final facts = _fallbackFacts[fallbackCategory]!;
          fact = "[$selectedCategory - Offline] ${facts[Random().nextInt(facts.length)]}";
          
          // If this is a different fact than the last one, or we've tried 3 times, use it
          if (fact != _cachedFact || i == 2) {
            _cacheFact(fact);
            return fact;
          }
        }
      }
    } catch (e) {
      print('Error in getLatestFact: $e');
      String fact;
      // Try up to 3 times to get a different fact than the last one
      for (int i = 0; i < 3; i++) {
        final fallbackCategory = _fallbackFacts.keys.elementAt(Random().nextInt(_fallbackFacts.length));
        final facts = _fallbackFacts[fallbackCategory]!;
        fact = "[Offline] ${facts[Random().nextInt(facts.length)]}";
        
        // If this is a different fact than the last one, or we've tried 3 times, use it
        if (fact != _cachedFact || i == 2) {
          _cacheFact(fact);
          return fact;
        }
      }
    }
    
    // If all else fails, return a random fact
    final category = _fallbackFacts.keys.elementAt(Random().nextInt(_fallbackFacts.length));
    final facts = _fallbackFacts[category]!;
    final fact = "[Offline] ${facts[Random().nextInt(facts.length)]}";
    _cacheFact(fact);
    return fact;
  }

  static void _cacheFact(String fact) {
    _cachedFact = fact;
    _lastFetchTime = DateTime.now();
  }

  static void clearCache() {
    _cachedFact = null;
    _lastFetchTime = null;
    _lastUsedCategories = null;
  }
} 