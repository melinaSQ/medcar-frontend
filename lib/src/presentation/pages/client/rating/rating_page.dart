// lib/src/presentation/pages/client/rating/rating_page.dart

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/ratings_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class RatingPage extends StatefulWidget {
  final int serviceRequestId;
  final String? driverName;
  final String? ambulancePlate;

  const RatingPage({
    super.key,
    required this.serviceRequestId,
    this.driverName,
    this.ambulancePlate,
  });

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasAlreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated();
  }

  Future<void> _checkIfAlreadyRated() async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final ratingsDs = sl<RatingsRemoteDataSource>();
        final result = await ratingsDs.checkIfRated(
          serviceRequestId: widget.serviceRequestId,
          token: session.accessToken,
        );
        if (mounted) {
          setState(() {
            _hasAlreadyRated = result['hasRated'] == true;
            if (_hasAlreadyRated && result['rating'] != null) {
              _selectedRating = result['rating']['score'] ?? 0;
            }
          });
        }
      }
    } catch (e) {
      // Ignorar error
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una calificación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final ratingsDs = sl<RatingsRemoteDataSource>();
        await ratingsDs.createRating(
          serviceRequestId: widget.serviceRequestId,
          score: _selectedRating,
          comment: _commentController.text.isNotEmpty
              ? _commentController.text
              : null,
          token: session.accessToken,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Gracias por tu calificación!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            'client/home',
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Calificar Servicio'),
        backgroundColor: const Color(0xFF652580),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icono de éxito
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // Título
            const Text(
              '¡Servicio Completado!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF652580),
              ),
            ),
            const SizedBox(height: 8),

            // Subtítulo
            Text(
              widget.driverName != null
                  ? 'Tu ambulancia llegó con ${widget.driverName}'
                  : 'Tu servicio de ambulancia ha sido completado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (widget.ambulancePlate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Placa: ${widget.ambulancePlate}',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],

            const SizedBox(height: 32),

            // Card de calificación
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      '¿Cómo fue tu experiencia?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Estrellas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        return GestureDetector(
                          onTap: _hasAlreadyRated
                              ? null
                              : () {
                                  setState(() => _selectedRating = starNumber);
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              starNumber <= _selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 48,
                              color: starNumber <= _selectedRating
                                  ? Colors.amber
                                  : Colors.grey[400],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),

                    // Texto de calificación
                    Text(
                      _getRatingText(),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedRating > 0
                            ? Colors.amber[800]
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Comentario
                    if (!_hasAlreadyRated)
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Comentario (opcional)',
                          hintText: 'Cuéntanos más sobre tu experiencia...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Botón de enviar
                    if (!_hasAlreadyRated)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF652580),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Enviar Calificación',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Ya calificaste este servicio',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de saltar
            if (!_hasAlreadyRated)
              TextButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    'client/home',
                    (route) => false,
                  );
                },
                child: const Text(
                  'Omitir por ahora',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    'client/home',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF652580),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Volver al inicio'),
              ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_selectedRating) {
      case 1:
        return 'Muy malo 😞';
      case 2:
        return 'Malo 😕';
      case 3:
        return 'Regular 😐';
      case 4:
        return 'Bueno 🙂';
      case 5:
        return 'Excelente 🤩';
      default:
        return 'Toca las estrellas para calificar';
    }
  }
}
