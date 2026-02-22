import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to fetch configuration values from Firestore
/// Stores sensitive keys like API keys in a secure Firestore collection
class ConfigService {
  final FirebaseFirestore _firestore;

  ConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Cache for configuration values to avoid repeated fetches
  static final Map<String, String> _cache = {};

  /// Fetch a configuration value from Firestore
  /// 
  /// The config collection structure in Firestore:
  /// - Collection: 'config'
  /// - Document: 'api_keys'
  /// - Fields: { openai_key: "your-key-here" }
  Future<String> getConfigValue(String key, {String defaultValue = ''}) async {
    // Return cached value if available
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      // Fetch from Firestore
      final doc = await _firestore
          .collection('config')
          .doc('api_keys')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey(key)) {
          final value = data[key] as String;
          _cache[key] = value;
          return value;
        }
      }

      print('⚠️ Config key "$key" not found in Firestore, using default');
      return defaultValue;
    } catch (e) {
      print('❌ Error fetching config from Firestore: $e');
      return defaultValue;
    }
  }

  /// Get OpenAI API Key from Firestore
  Future<String> getOpenAiKey() async {
    return getConfigValue('openai_key', defaultValue: '');
  }

  /// Clear the configuration cache
  /// Call this if you update values in Firestore and need to refresh
  static void clearCache() {
    _cache.clear();
  }
}
