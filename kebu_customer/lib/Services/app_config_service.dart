import 'package:flutter/foundation.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class AppConfigService {
  static const String _cachePrefix = 'app_config_';
  static const String _cacheTimestampKey = 'app_config_cached_at';
  static const int _cacheTtlMs = 24 * 60 * 60 * 1000; // 24 hours

  static final Map<String, String> _memoryCache = {};

  /// Fetch all public keys from backend and store in SharedPreferences.
  /// Called on app startup.
  static Future<void> initialize() async {
    try {
      // Check if cache is still fresh
      final cachedAt = Prefs.getInt(_cacheTimestampKey, def: 0);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedAt > 0 && (now - cachedAt) < _cacheTtlMs) {
        _loadFromPrefs();
        if (_memoryCache.isNotEmpty) {
          debugPrint('AppConfigService: Loaded ${_memoryCache.length} keys from cache');
          return;
        }
      }

      // Fetch from backend
      await fetchAndCacheKeys();
    } catch (e) {
      debugPrint('AppConfigService: Init error: $e');
      // Fallback to cached values
      _loadFromPrefs();
    }
  }

  /// Force fetch keys from backend and update cache.
  static Future<void> fetchAndCacheKeys() async {
    try {
      final response = await ApiClient.get('/settings/keys', auth: false);

      if (response.success && response.data != null) {
        final keys = response.data['keys'];
        if (keys is Map) {
          _memoryCache.clear();
          for (final entry in keys.entries) {
            final k = entry.key.toString();
            final v = entry.value.toString();
            _memoryCache[k] = v;
            await Prefs.setString('$_cachePrefix$k', v);
          }
          await Prefs.setInt(
            _cacheTimestampKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          debugPrint('AppConfigService: Cached ${_memoryCache.length} keys from backend');
        }
      }
    } catch (e) {
      debugPrint('AppConfigService: Fetch error: $e');
    }
  }

  /// Load cached values from SharedPreferences into memory.
  static void _loadFromPrefs() {
    _memoryCache.clear();
    final knownKeys = [
      'google_maps_api_key',
      'razorpay_key_id',
      'firebase_project_id',
    ];
    for (final key in knownKeys) {
      final val = Prefs.getString('$_cachePrefix$key');
      if (val.isNotEmpty) {
        _memoryCache[key] = val;
      }
    }
  }

  /// Get a config value by key. Returns empty string if not found.
  static String get(String key) {
    return _memoryCache[key] ?? Prefs.getString('$_cachePrefix$key');
  }

  /// Shortcut for Google Maps API key.
  static String get googleMapsApiKey => get('google_maps_api_key');

  /// Shortcut for Razorpay Key ID.
  static String get razorpayKeyId => get('razorpay_key_id');

  /// Clear all cached config data.
  static Future<void> clearCache() async {
    _memoryCache.clear();
    for (final key in ['google_maps_api_key', 'razorpay_key_id', 'firebase_project_id']) {
      await Prefs.setString('$_cachePrefix$key', '');
    }
    await Prefs.setInt(_cacheTimestampKey, 0);
  }
}
