import 'dart:convert';
import 'package:flutter/material.dart';

/// Resuelve el `ImageProvider` correcto para un avatar guardado como:
/// - Data URI Base64 (`data:image/jpeg;base64,...`) — foto subida por el
///   usuario y guardada directo en Firestore (no usamos Storage).
/// - URL http(s) normal — por si en el futuro se migra a Firebase Storage
///   o similar.
///
/// Devuelve `null` si no hay avatar o si el valor está corrupto, para que
/// el caller pueda mostrar el fallback (iniciales).
ImageProvider? avatarImageProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:')) {
    try {
      final base64Part = avatarUrl.substring(avatarUrl.indexOf(',') + 1);
      return MemoryImage(base64Decode(base64Part));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}
