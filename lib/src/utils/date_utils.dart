// lib/src/utils/date_utils.dart

import 'package:intl/intl.dart';

/// Convierte una fecha string del backend (UTC) a DateTime en hora local
/// Bolivia está en UTC-4, así que esta función asegura la conversión correcta
DateTime parseToLocal(String dateStr) {
  try {
    // Si la fecha termina en 'Z', es UTC explícito
    if (dateStr.endsWith('Z')) {
      final utcDate = DateTime.parse(dateStr);
      return utcDate.toLocal();
    }

    // Si tiene offset (+/-), parsear directamente
    if (dateStr.contains('+') || dateStr.contains('-', 10)) {
      final date = DateTime.parse(dateStr);
      // Si no tiene 'Z' pero viene del backend, asumir UTC
      if (date.isUtc) {
        return date.toLocal();
      }
      return date;
    }

    // Si no tiene indicador de zona horaria, el backend siempre envía UTC
    // Parsear como si fuera UTC y luego convertir a local
    // Formato típico: "2025-12-16T17:57:00.000" (sin Z)
    final parsed = DateTime.parse(dateStr);

    // Si el parseo no detectó UTC pero viene del backend, forzar como UTC
    if (!parsed.isUtc) {
      // Crear una fecha UTC explícita con los mismos valores
      final utcDate = DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
      return utcDate.toLocal();
    }

    // Si ya es UTC, convertir a local
    return parsed.toLocal();
  } catch (e) {
    // Si falla el parsing, intentar parsear directamente
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      rethrow;
    }
  }
}

/// Formatea una fecha DateTime a string en formato dd/MM/yyyy HH:mm
String formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  // Asegurar que la fecha esté en hora local
  final localDate = date.isUtc ? date.toLocal() : date;
  return DateFormat('dd/MM/yyyy HH:mm').format(localDate);
}

/// Formatea una fecha string del backend directamente a string local
String formatDateString(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'N/A';
  try {
    final localDate = parseToLocal(dateStr);
    return formatDate(localDate);
  } catch (e) {
    return dateStr;
  }
}
