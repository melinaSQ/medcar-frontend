// lib/src/utils/pdf_service.dart

// ignore_for_file: unnecessary_import

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:medcar_frontend/src/utils/date_utils.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Genera un PDF del historial de servicios
  static Future<void> generateServiceHistoryPdf({
    required List<Map<String, dynamic>> services,
    required String title,
    required String userName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MedCar',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Usuario: $userName',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabla de servicios
            if (services.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Text(
                    'No hay servicios registrados',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Encabezado de la tabla
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Tipo', isHeader: true),
                      _buildTableCell('Estado', isHeader: true),
                      _buildTableCell('Ambulancia', isHeader: true),
                    ],
                  ),
                  // Filas de datos
                  ...services.map((service) {
                    final createdAt = service['createdAt'] != null
                        ? formatDateString(service['createdAt'])
                        : 'N/A';
                    final emergencyType = _getEmergencyTypeText(
                      service['emergencyType'] ?? 'N/A',
                    );
                    final status = _getStatusText(service['status'] ?? 'N/A');
                    final ambulance =
                        service['ambulance'] as Map<String, dynamic>?;
                    final plate = ambulance?['plate'] ?? 'N/A';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(createdAt),
                        _buildTableCell(emergencyType),
                        _buildTableCell(status),
                        _buildTableCell(plate),
                      ],
                    );
                  }).toList(),
                ],
              ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Total de servicios: ${services.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Guardar y compartir PDF
    await _saveAndSharePdf(
      pdf,
      'historial_turnos_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Genera un PDF del historial de turnos
  static Future<void> generateShiftsHistoryPdf({
    required List<Map<String, dynamic>> shifts,
    required String userName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MedCar',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Historial de Turnos',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Conductor: $userName',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabla de turnos
            if (shifts.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Text(
                    'No hay turnos registrados',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Encabezado de la tabla
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('ID', isHeader: true),
                      _buildTableCell('Inicio', isHeader: true),
                      _buildTableCell('Fin', isHeader: true),
                      _buildTableCell('Duración', isHeader: true),
                      _buildTableCell('Ambulancia', isHeader: true),
                      _buildTableCell('Servicios', isHeader: true),
                    ],
                  ),
                  // Filas de datos
                  ...shifts.map((shift) {
                    final startTime = shift['startTime'] != null
                        ? formatDateString(shift['startTime'])
                        : 'N/A';
                    final endTime = shift['endTime'] != null
                        ? formatDateString(shift['endTime'])
                        : 'N/A';
                    final duration = _calculateDuration(
                      shift['startTime'],
                      shift['endTime'],
                    );
                    final ambulance =
                        shift['ambulance'] as Map<String, dynamic>?;
                    final plate = ambulance?['plate'] ?? 'N/A';
                    final serviceRequests =
                        shift['serviceRequests'] as List<dynamic>?;
                    final serviceCount = serviceRequests?.length ?? 0;

                    return pw.TableRow(
                      children: [
                        _buildTableCell('#${shift['id']}'),
                        _buildTableCell(startTime),
                        _buildTableCell(endTime),
                        _buildTableCell(duration),
                        _buildTableCell(plate),
                        _buildTableCell('$serviceCount'),
                      ],
                    );
                  }).toList(),
                ],
              ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Total de turnos: ${shifts.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Mostrar diálogo de impresión/guardado
    // Guardar y compartir PDF
    await _saveAndSharePdf(
      pdf,
      'historial_turnos_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Genera un PDF de calificaciones
  static Future<void> generateRatingsPdf({
    required List<Map<String, dynamic>> ratings,
    required String userName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MedCar',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Mis Calificaciones',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Conductor: $userName',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabla de calificaciones
            if (ratings.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Text(
                    'No hay calificaciones registradas',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Encabezado de la tabla
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Calificación', isHeader: true),
                      _buildTableCell('Comentario', isHeader: true),
                      _buildTableCell('Cliente', isHeader: true),
                    ],
                  ),
                  // Filas de datos
                  ...ratings.map((rating) {
                    final createdAt = rating['createdAt'] != null
                        ? formatDateString(rating['createdAt'])
                        : 'N/A';
                    final score = rating['score'] ?? 0;
                    final comment = rating['comment'] ?? 'Sin comentario';
                    final rater = rating['rater'] as Map<String, dynamic>?;
                    final raterName = rater != null
                        ? '${rater['name']} ${rater['lastname']}'
                        : 'N/A';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(createdAt),
                        _buildTableCell('⭐ $score/5'),
                        _buildTableCell(comment, maxLines: 2),
                        _buildTableCell(raterName),
                      ],
                    );
                  }).toList(),
                ],
              ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Total de calificaciones: ${ratings.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Guardar y compartir PDF
    await _saveAndSharePdf(
      pdf,
      'calificaciones_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Guarda el PDF y permite compartirlo
  static Future<void> _saveAndSharePdf(pw.Document pdf, String fileName) async {
    try {
      // Generar bytes del PDF
      final pdfBytes = await pdf.save();

      // Obtener directorio temporal (más confiable para compartir)
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Guardar PDF en directorio temporal
      await file.writeAsBytes(pdfBytes);

      // Compartir el archivo usando XFile
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        text: 'Reporte MedCar',
        subject: 'Historial de servicios',
      );
    } catch (e) {
      throw Exception('Error al compartir PDF: ${e.toString()}');
    }
  }

  // Helpers
  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    int maxLines = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: maxLines,
      ),
    );
  }

  static String _getEmergencyTypeText(String type) {
    switch (type) {
      case 'TRAFFIC_ACCIDENT':
        return 'Accidente';
      case 'MEDICAL_EMERGENCY':
        return 'Emergencia Médica';
      case 'OTHER':
        return 'Otro';
      default:
        return type;
    }
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'SEARCHING':
        return 'Buscando';
      case 'ASSIGNED':
        return 'Asignado';
      case 'ON_THE_WAY':
        return 'En Camino';
      case 'ON_SITE':
        return 'En el Lugar';
      case 'TRAVELLING':
        return 'En Traslado';
      case 'COMPLETED':
        return 'Completado';
      case 'CANCELED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  static String _calculateDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return 'N/A';
    try {
      final start = parseToLocal(startTime);
      final end = parseToLocal(endTime);
      final duration = end.difference(start);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      return 'N/A';
    }
  }
}
