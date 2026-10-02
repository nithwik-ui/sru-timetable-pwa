import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Handles secure storage of the minimum SRAAP session state.
/// 
/// NEVER stores: password, CAPTCHA, raw PHPSESSID in logs.
/// Only stores the minimum cookie header required to probe/restore session.
class SraapStorage {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kSessionKey = 'sraap_session_v1';
  static const _kConnectedFlagKey = 'sraap_connected';
  static const _kLastSyncKey = 'sraap_last_sync';

  /// Save the minimum session state needed for restore attempts.
  /// [data] must only contain non-secret, minimal identifiers.
  static Future<void> saveSessionState(Map<String, dynamic> data) async {
    final encoded = jsonEncode(data);
    await _secureStorage.write(key: _kSessionKey, value: encoded);
    await _secureStorage.write(key: _kConnectedFlagKey, value: 'true');
  }

  /// Load stored session state. Returns null if nothing is stored.
  static Future<Map<String, dynamic>?> loadSessionState() async {
    final raw = await _secureStorage.read(key: _kSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Clear all SRAAP session data from secure storage.
  static Future<void> clearSessionState() async {
    await _secureStorage.delete(key: _kSessionKey);
    await _secureStorage.write(key: _kConnectedFlagKey, value: 'false');
  }

  /// Quick non-secure flag to determine if SRAAP has ever been connected.
  /// Used by StorageService (non-sensitive boolean, not the session itself).
  static Future<bool> isConnected() async {
    final val = await _secureStorage.read(key: _kConnectedFlagKey);
    return val == 'true';
  }

  /// Save the last academic sync timestamp.
  static Future<void> saveLastSync(DateTime dt) async {
    await _secureStorage.write(key: _kLastSyncKey, value: dt.toIso8601String());
  }

  /// Load the last academic sync timestamp.
  static Future<DateTime?> loadLastSync() async {
    final raw = await _secureStorage.read(key: _kLastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
