// Normaliza payloads de misión: la API devuelve la solicitud "plana";
// el WebSocket envía { message, requestDetails: <solicitud> }.

import 'package:medcar_frontend/src/utils/map_coercion.dart';

export 'package:medcar_frontend/src/utils/map_coercion.dart';

/// Detalle de solicitud unificado para UI y rutas (origen, cliente, etc.).
Map<String, dynamic> missionRequestDetails(Map<String, dynamic> mission) {
  final nested = coerceMap(mission['requestDetails']);
  if (nested != null) return nested;
  return mission;
}
