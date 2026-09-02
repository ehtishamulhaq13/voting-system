import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

final RegExp _base64Urlish = RegExp(r'^[A-Za-z0-9+/=_-]+$');

/// Candidate symbol → [MemoryImage].
///
/// Supports `data:image/...;base64,...` and plain base64 payloads (no URL
/// loading). Returns null on invalid data.
MemoryImage? memoryImageFromSymbol(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.startsWith('data:')) {
    return _memoryImageFromDataUri(s);
  }

  // Plain base64 (some APIs omit the data: prefix)
  final compact = s.replaceAll(RegExp(r'\s+'), '');
  if (compact.length >= 32 && _base64Urlish.hasMatch(compact)) {
    try {
      final normalized = compact.replaceAll('-', '+').replaceAll('_', '/');
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  return null;
}

MemoryImage? _memoryImageFromDataUri(String s) {
  try {
    final comma = s.indexOf(',');
    if (comma <= 0 || comma >= s.length - 1) return null;
    final payload =
        (s.substring(comma + 1).trim()).replaceAll(RegExp(r'\s+'), '');
    if (payload.isEmpty) return null;

    Uint8List bytes;
    if (s.substring(0, comma).contains(';base64')) {
      bytes = base64Decode(payload);
    } else {
      bytes = Uint8List.fromList(Uri.decodeComponent(payload).codeUnits);
    }

    if (bytes.isEmpty) return null;
    return MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}
