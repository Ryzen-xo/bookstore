import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 password hashing. Format: `<saltHex>:<hashHex>`.
///
/// This is a teaching project; a production app would use Argon2/scrypt via a
/// backend. We never store plaintext and we use a fresh random salt per hash.
class PasswordHasher {
  PasswordHasher._();
  static final Random _rng = Random.secure();

  static String hash(String password) {
    final salt = List<int>.generate(16, (_) => _rng.nextInt(256));
    final saltHex = salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final digest = sha256.convert(utf8.encode('$saltHex:$password')).toString();
    return '$saltHex:$digest';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final digest = sha256.convert(utf8.encode('${parts[0]}:$password')).toString();
    // Constant-time-ish comparison.
    if (digest.length != parts[1].length) return false;
    var diff = 0;
    for (var i = 0; i < digest.length; i++) {
      diff |= digest.codeUnitAt(i) ^ parts[1].codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Returns null when acceptable, otherwise a human-readable reason.
  static String? checkStrength(String password) {
    if (password.length < 8) return 'Use at least 8 characters.';
    if (!password.contains(RegExp(r'[A-Za-z]'))) return 'Include at least one letter.';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Include at least one number.';
    return null;
  }

  /// 8-character uppercase hex reset code.
  static String resetCode() {
    final bytes = List<int>.generate(4, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }
}
