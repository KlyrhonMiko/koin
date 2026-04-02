import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';

class IntentClassifier {
  // Enhanced, comprehensive training corpus mapped to typical transaction types
  static const Map<String, List<String>> _corpus = {
    'Food': [
      'lunch',
      'dinner',
      'breakfast',
      'meal',
      'restaurant',
      'sisig',
      'shawarma',
      'burger',
      'pizza',
      'chicken',
      'coffee',
      'drink',
      'snack',
      'cafe',
      'mcdonalds',
      'jollibee',
      'eat',
      'food',
      'hungry',
      'cravings',
      'pancit',
      'adobo',
      'kare',
      'sinigang',
      'takeout',
      'delivery',
      'bakery',
      'pastry',
      'dessert',
      'beverage',
      'tea',
      'boba',
      'fastfood',
      'pork',
      'beef',
      'fish',
      'meat',
      'rice',
      'cookie',
      'cake',
      'bread',
      'water',
      'dining',
      'starbucks',
      'chowking',
      'mang inasal',
      'kfc',
      'wendys',
      'shakeys',
      'samgyupsal',
      'buffet',
    ],
    'Transport': [
      'grab',
      'taxi',
      'uber',
      'bus',
      'train',
      'fare',
      'gas',
      'fuel',
      'toll',
      'parking',
      'transport',
      'commute',
      'jeep',
      'tricycle',
      'ride',
      'gasoline',
      'ticket',
      'angkas',
      'joyride',
      'flight',
      'airplane',
      'subway',
      'mrt',
      'lrt',
      'grabcar',
      'moveit',
      'cab',
      'tollgate',
      'parkingfee',
      'autosweep',
      'easytrip',
      'motorcycle',
      'bicycle',
      'transit',
      'carpool',
      'ferry',
      'transportation',
      'diesel',
      'petrol',
      'shell',
      'petron',
      'caltex',
    ],
    'Groceries': [
      'grocery',
      'supermarket',
      'market',
      'palengke',
      'mart',
      'supplies',
      'pantry',
      'sm',
      'puregold',
      'waltermart',
      'savemore',
      'convenience',
      '711',
      'seven eleven',
      'ministop',
      'alfamart',
      'lawson',
      'sarisari',
      'produce',
      'vegetables',
      'fruits',
      'toiletries',
      'detergent',
      'soap',
      'shampoo',
      'tissue',
      'toothpaste',
      'groceries',
    ],
    'Bills': [
      'bill',
      'electricity',
      'water',
      'internet',
      'wifi',
      'rent',
      'utility',
      'meralco',
      'maynilad',
      'subscription',
      'monthly',
      'insurance',
      'phone',
      'postpaid',
      'broadband',
      'cable',
      'globe',
      'smart',
      'pldt',
      'converge',
      'sky',
      'loan',
      'mortgage',
      'dues',
      'utilities',
    ],
    'Shopping': [
      'shop',
      'clothes',
      'shoes',
      'lazada',
      'shopee',
      'mall',
      'bought',
      'shirt',
      'pants',
      'dress',
      'bag',
      'gadget',
      'apparel',
      'amazon',
      'accessories',
      'jewelry',
      'electronics',
      'appliance',
      'hardware',
      'tiktok',
      'zalora',
      'uniqlo',
      'hm',
      'zara',
      'book',
      'toy',
      'gift',
      'shopping',
      'makeup',
      'cosmetics',
      'boutique',
      'fashion',
      'wear',
      'jacket',
    ],
    'Entertainment': [
      'movie',
      'cinema',
      'game',
      'netflix',
      'spotify',
      'fun',
      'ticket',
      'arcade',
      'concert',
      'party',
      'hobby',
      'event',
      'controller',
      'youtube',
      'premium',
      'gaming',
      'steam',
      'playstation',
      'xbox',
      'nintendo',
      'disney',
      'hbo',
      'club',
      'bar',
      'alcohol',
      'beer',
      'wine',
      'karaoke',
      'billiards',
      'bowling',
      'entertainment',
    ],
    'Health': [
      'medicine',
      'doctor',
      'hospital',
      'clinic',
      'pharmacy',
      'health',
      'meds',
      'checkup',
      'dental',
      'vitamin',
      'medical',
      'therapy',
      'dentist',
      'drugstore',
      'mercury',
      'watsons',
      'supplement',
      'gym',
      'fitness',
      'workout',
      'yoga',
      'eyecare',
      'optical',
      'wellness',
      'healthcare',
    ],
    'Salary': [
      'salary',
      'wage',
      'paycheck',
      'bonus',
      'earned',
      'income',
      'profit',
      'freelance',
      'business',
      'pay',
      'allowance',
      'sweldo',
      'sahod',
      'commission',
      'payout',
    ],
    'Personal': [
      'haircut',
      'salon',
      'barber',
      'massage',
      'spa',
      'beauty',
      'cosmetics',
      'skincare',
      'facial',
      'nails',
      'manicure',
      'pedicure',
      'grooming',
      'personal',
    ],
    'Education': [
      'school',
      'tuition',
      'book',
      'course',
      'class',
      'training',
      'seminar',
      'workshop',
      'enrollment',
      'supplies',
      'education',
      'college',
      'university',
      'student',
      'learning',
    ],
    'Others': [
      'fee',
      'charge',
      'tax',
      'penalty',
      'misc',
      'miscellaneous',
      'other',
    ],
    'Other Income': [
      'sold',
      'refund',
      'cashback',
      'reward',
      'gift',
      'donation',
      'prize',
      'dividend',
      'interest',
      'investment',
    ],
  };

  // Stopwords that carry no intent value, filtered out to avoid muddying the classification scoring
  static const Set<String> _stopwords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'in',
    'on',
    'at',
    'to',
    'for',
    'with',
    'about',
    'against',
    'between',
    'into',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'from',
    'up',
    'down',
    'out',
    'off',
    'over',
    'under',
    'again',
    'further',
    'then',
    'once',
    'here',
    'there',
    'when',
    'where',
    'why',
    'how',
    'all',
    'any',
    'both',
    'each',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
    'nor',
    'not',
    'only',
    'own',
    'same',
    'so',
    'than',
    'too',
    'very',
    's',
    't',
    'can',
    'will',
    'just',
    'don',
    'should',
    'now',
    'i',
    'me',
    'my',
    'myself',
    'we',
    'our',
    'ours',
    'ourselves',
    'you',
    'your',
    'yours',
    'yourself',
    'he',
    'him',
    'his',
    'himself',
    'she',
    'her',
    'hers',
    'herself',
    'it',
    'its',
    'itself',
    'they',
    'them',
    'their',
    'theirs',
    'themselves',
    'what',
    'which',
    'who',
    'whom',
    'this',
    'that',
    'these',
    'those',
    'am',
    'did',
    'do',
    'does',
    'doing',
    'had',
    'has',
    'have',
    'having',
    'pesos',
    'peso',
    'dollars',
    'dollar',
    'bucks',
    'buck',
    'php',
    'usd',
  };

  /// Simple stemmer to handle common English/Tagalog suffixes
  static String _stem(String word) {
    if (word.length <= 3) return word; // Prevent over-stemming very short words
    if (word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
    if (word.endsWith('es')) return word.substring(0, word.length - 2);
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    if (word.endsWith('ing')) return word.substring(0, word.length - 3);
    if (word.endsWith('ed')) return word.substring(0, word.length - 2);
    if (word.endsWith('ly')) return word.substring(0, word.length - 2);
    return word;
  }

  /// Returns the category intent key matched using Bag-of-Words and Stemming TF logic + Auto-Learning.
  static String? classifyIntent(
    String text,
    List<TransactionCategory> categories,
    List<AppTransaction> pastTransactions,
  ) {
    if (text.isEmpty) return null;

    // Tokenize text into words, removing punctuation
    final rawTokens = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // 1. Remove stopwords and 2. Stem remaining tokens
    final tokens = rawTokens
        .where((w) => !_stopwords.contains(w))
        .map(_stem)
        .toList();

    if (tokens.isEmpty) return null;

    // Dynamically inject custom categories into corpus, applying stemming to everything
    Map<String, List<String>> dynamicCorpus = Map.from(
      _corpus.map((k, v) => MapEntry(k, v.map(_stem).toList())),
    );

    for (var cat in categories) {
      final nameLower = cat.name.toLowerCase();
      final stemmedName = _stem(nameLower);

      if (!dynamicCorpus.containsKey(cat.name)) {
        dynamicCorpus[cat.name] = [stemmedName, nameLower];
      } else {
        if (!dynamicCorpus[cat.name]!.contains(stemmedName)) {
          dynamicCorpus[cat.name] = List.from(dynamicCorpus[cat.name]!)
            ..add(stemmedName);
        }
      }
    }

    // Build historical weights from the user's past transactions
    final Map<String, Map<String, int>> historyWeights = {};
    for (var tx in pastTransactions) {
      if (tx.note.isEmpty) continue;

      // Look up category name by ID
      String? txCatName;
      for (var cat in categories) {
        if (cat.id == tx.categoryId) {
          txCatName = cat.name;
          break;
        }
      }

      if (txCatName == null) continue;

      final txTokens = tx.note
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && !_stopwords.contains(w))
          .map(_stem)
          .toList();

      historyWeights.putIfAbsent(txCatName, () => {});
      for (var t in txTokens) {
        historyWeights[txCatName]![t] =
            (historyWeights[txCatName]![t] ?? 0) + 1;
      }
    }

    Map<String, double> scores = {for (var key in dynamicCorpus.keys) key: 0.0};

    // Calculate term frequency weights including historical auto-learning
    for (var token in tokens) {
      for (var entry in dynamicCorpus.entries) {
        final category = entry.key;
        final keywords = entry.value;

        // Exact match on stem gets full weight
        if (keywords.contains(token)) {
          scores[category] = scores[category]! + 1.0;
        } else {
          // Similarity matching: if the token is extremely close to the keyword root
          for (var keyword in keywords) {
            if (keyword.length >= 4 && token.length >= 4) {
              if (token.startsWith(keyword) || keyword.startsWith(token)) {
                // To avoid overly aggressive matching, ensure lengths are very close
                if ((token.length - keyword.length).abs() <= 1) {
                  scores[category] = scores[category]! + 0.8;
                  break;
                }
              }
            }
          }
        }
      }

      // Add auto-learning weight from past transactions
      historyWeights.forEach((catName, tokenCounts) {
        if (tokenCounts.containsKey(token)) {
          final occurrences = tokenCounts[token]!;
          // Cap the maximum history weight (2.5) so a frequently occurring historical root exerts strong preference
          final bonus = (0.75 * occurrences).clamp(0.75, 2.5);

          if (!scores.containsKey(catName)) {
            scores[catName] = 0.0;
          }
          scores[catName] = scores[catName]! + bonus;
        }
      });
    }

    // Get the category with max score
    String? topCategory;
    double maxScore = 0.0;

    scores.forEach((cat, score) {
      if (score > maxScore) {
        maxScore = score;
        topCategory = cat;
      }
    });

    // Provide a threshold to prevent completely anomalous assignments
    if (maxScore >= 0.75) {
      return topCategory;
    }

    return null;
  }

  /// Cleans the transcription by stripping out amounts, currency names, and command keywords.
  static String extractCleanNote(String text, String? amountToRemove) {
    String refinedNote = text.toLowerCase();

    // 1. Strips out the spoken digit sequence
    if (amountToRemove != null) {
      refinedNote = refinedNote.replaceFirst(amountToRemove.toLowerCase(), '');
    }

    // 2. We don't remove generic english stops ("for", "on", "the") here because it makes
    // the finalised note string read like ungrammatical caveman-speak. We only remove
    // explicit verbal command triggers and monetary symbols.
    final wordsToStrip = [
      'add',
      'added',
      'spent',
      'received',
      'earned',
      'income',
      'expense',
      'transfer',
      'transferred',
      'pesos',
      'peso',
      'dollars',
      'dollar',
      'bucks',
      'buck',
      'php',
      'usd',
    ];

    for (final word in wordsToStrip) {
      refinedNote = refinedNote.replaceAll(RegExp('\\b$word\\b'), '');
    }

    // 3. Clean up loose spaces and capitalize the first letter smoothly
    refinedNote = refinedNote.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (refinedNote.isNotEmpty) {
      refinedNote = refinedNote[0].toUpperCase() + refinedNote.substring(1);
    }

    return refinedNote.isEmpty ? text : refinedNote;
  }
}
