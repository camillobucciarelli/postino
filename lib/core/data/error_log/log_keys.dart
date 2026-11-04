import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../attachment_crypto.dart';

/// The log's two keys (#116), derived from the database key (hex) with HMAC-SHA256, one label per half:
/// the log is readable only with the database's key, and never shares a key with it.
AttachmentKeys logKeysFrom(String databaseKeyHex) {
  final key = Hmac(sha256, bytesFromHex(databaseKeyHex));
  Uint8List half(String label) => Uint8List.fromList(key.convert(utf8.encode(label)).bytes);
  return (enc: half('postino-log-enc'), mac: half('postino-log-mac'));
}
