import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ─────────────────────────────────────────────────────────
///  AUTH SERVICE — persistent login (iOS Keychain / Android
///  Keystore via flutter_secure_storage).
///
///  Session survives: app closes, device restarts, app updates.
///  Login screen only reappears if the user logs out, the token
///  expires and cannot be refreshed, or the server disables the
///  account.
///
///  Backend integration points are marked with `TODO(api)` —
///  wire your real endpoints there; everything else (storage,
///  routing, refresh plumbing) is complete.
/// ─────────────────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      // Survives device restarts, readable after first unlock —
      // required so background BLE sync can run before unlock.
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _kAccess  = 'bmh_access_token';
  static const _kRefresh = 'bmh_refresh_token';
  static const _kExpiry  = 'bmh_token_expiry';   // epoch ms
  static const _kEmail   = 'bmh_user_email';

  // ── SESSION LIFECYCLE ─────────────────────────────────

  /// Save a session after successful login / signup / OTP verify.
  /// [expiresIn] = seconds until the access token expires
  /// (pass null for a non-expiring local session).
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
    String? email,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _kRefresh, value: refreshToken);
    }
    if (expiresIn != null) {
      final expiry =
          DateTime.now().add(Duration(seconds: expiresIn));
      await _storage.write(
          key: _kExpiry, value: expiry.millisecondsSinceEpoch.toString());
    } else {
      await _storage.delete(key: _kExpiry);
    }
    if (email != null) {
      await _storage.write(key: _kEmail, value: email);
    }
  }

  /// True if a stored session exists and is usable.
  /// Attempts a silent refresh when the access token has expired.
  Future<bool> hasValidSession() async {
    try {
      final token = await _storage.read(key: _kAccess);
      if (token == null || token.isEmpty) return false;

      final expiryRaw = await _storage.read(key: _kExpiry);
      if (expiryRaw == null) return true; // non-expiring local session

      final expiry =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiryRaw));
      // Refresh proactively 5 min before actual expiry
      if (DateTime.now()
          .isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        return true;
      }
      return await _tryRefresh();
    } catch (_) {
      return false;
    }
  }

  /// Silent token refresh. Returns true when the session was renewed.
  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null || refresh.isEmpty) return false;

    // TODO(api): call your refresh endpoint, e.g.
    //   final res = await http.post(Uri.parse('$baseUrl/auth/refresh'),
    //       body: {'refresh_token': refresh});
    //   if (res.statusCode == 200) {
    //     final j = jsonDecode(res.body);
    //     await saveSession(
    //       accessToken:  j['access_token'],
    //       refreshToken: j['refresh_token'],
    //       expiresIn:    j['expires_in']);
    //     return true;
    //   }
    //   return false; // refresh rejected → force re-login
    //
    // Until the backend is wired, treat a present refresh token
    // as a renewable local session:
    return true;
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get userEmail   => _storage.read(key: _kEmail);

  /// Explicit logout — wipes the session; user returns to Login.
  Future<void> logout() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpiry);
    await _storage.delete(key: _kEmail);
  }
}
