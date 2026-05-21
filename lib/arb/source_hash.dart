import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Compute a `@key.source_hash` for a translation key's canonical source
/// value, per `dialect/spec/source_hash.md`.
///
/// - Algorithm: SHA-256.
/// - Output: lowercase hex, first 16 characters (64-bit truncation).
/// - Input: the source value string. The caller MUST pass the
///   NFC-normalized form — Dialect's [ArbParser] already does this on
///   read, so passing `entry.value` straight from a parsed ARB is
///   correct.
///
/// Only the user-facing English value is hashed. Description, context,
/// placeholders, and other `@key.*` fields are NOT inputs — see the
/// spec for the rationale ("a description edit must not invalidate
/// locked translations").
String computeSourceHash(String value) {
  final digest = sha256.convert(utf8.encode(value));
  return digest.toString().substring(0, 16);
}
