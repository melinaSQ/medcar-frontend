/// Normaliza el estado que viene del API (enum, mayúsculas, espacios).
String normalizeServiceRequestStatus(
  String? raw, {
  required bool hasAssignedShift,
}) {
  var s = raw?.toString().trim().toUpperCase().replaceAll(' ', '_') ?? '';
  if (s.isEmpty) {
    return hasAssignedShift ? 'ASSIGNED' : 'SEARCHING';
  }
  return s;
}

int? parseServiceRequestId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// Estados en los que ya no debe mostrarse la tarjeta de “emergencia en curso”.
bool isTerminalClientActiveStatus(String normalizedStatus) {
  switch (normalizedStatus) {
    case 'CANCELED':
    case 'CANCELLED':
    case 'COMPLETED':
      return true;
    default:
      return false;
  }
}
