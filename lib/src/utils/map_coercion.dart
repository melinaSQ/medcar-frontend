/// Socket.IO / JSON anidado suele ser Map<dynamic, dynamic>; los casts a
/// Map<String, dynamic> fallan sin esto.
Map<String, dynamic>? coerceMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
