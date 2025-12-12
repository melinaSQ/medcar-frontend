import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/domain/entities/service_request_entity.dart';
import 'package:medcar_frontend/src/domain/usecases/create_service_request_usecase.dart';

class ClientMapPage extends StatefulWidget {
  const ClientMapPage({super.key});

  @override
  State<ClientMapPage> createState() => _ClientMapPageState();
}

class _ClientMapPageState extends State<ClientMapPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _selectedPosition; // Posición seleccionada por el usuario
  bool _isLoading = true;
  String? _errorMessage;
  
  // Ubicación por defecto: Cochabamba, Bolivia
  static const LatLng _defaultLocation = LatLng(-17.3935, -66.1570);
  
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verificar y solicitar permisos
      final permissionStatus = await Permission.location.request();
      
      if (permissionStatus.isDenied) {
        setState(() {
          _errorMessage = 'Permiso de ubicación denegado';
          _isLoading = false;
        });
        return;
      }

      if (permissionStatus.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Permiso de ubicación denegado permanentemente. Habilítalo en configuración.';
          _isLoading = false;
        });
        return;
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'El servicio de ubicación está deshabilitado';
          _isLoading = false;
        });
        return;
      }

      // Obtener la ubicación actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        _updateMarker();
      });

      // Mover cámara a la ubicación actual
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener ubicación: $e';
        _isLoading = false;
      });
    }
  }

  void _updateMarker() {
    if (_selectedPosition == null) return;
    
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedPosition!,
          infoWindow: const InfoWindow(title: 'Ubicación de emergencia'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true, // Permite arrastrar el marcador
          onDragEnd: (newPosition) {
            setState(() {
              _selectedPosition = newPosition;
            });
          },
        ),
      };
    });
  }

  // Mover marcador cuando el usuario toca el mapa
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _updateMarker();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16,
        ),
      );
    }
  }

  EmergencyType _selectedEmergencyType = EmergencyType.medicalEmergency;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSending = false;

  void _requestAmbulance() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo con opciones
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Solicitar Ambulancia'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tipo de emergencia:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Opciones de tipo de emergencia
                ...EmergencyType.values.map((type) => RadioListTile<EmergencyType>(
                  title: Text(type.displayName),
                  value: type,
                  groupValue: _selectedEmergencyType,
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedEmergencyType = value!;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                
                const SizedBox(height: 16),
                const Text(
                  'Descripción (opcional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Describe brevemente la situación...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${_selectedPosition!.latitude.toStringAsFixed(5)}\nLng: ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSending ? null : () {
                _descriptionController.clear();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isSending ? null : () {
                Navigator.pop(dialogContext);
                _sendAmbulanceRequest();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('¡Enviar solicitud!', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAmbulanceRequest() async {
    setState(() => _isSending = true);

    try {
      final useCase = sl<CreateServiceRequestUseCase>();
      
      await useCase.call(
        emergencyType: _selectedEmergencyType,
        latitude: _selectedPosition!.latitude,
        longitude: _selectedPosition!.longitude,
        originDescription: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
      );

      _descriptionController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud enviada. Una ambulancia está en camino.'),
            backgroundColor: Color(0xFF652580),
            duration: Duration(seconds: 4),
          ),
        );
        
        // Volver a la página principal después de un momento
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Solicitar Ambulancia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : _defaultLocation,
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: _onMapTap, // Permite mover el marcador tocando el mapa
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Obteniendo ubicación...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          // Error message
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),
          
          // Botón de centrar ubicación
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              heroTag: 'center_location',
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Color(0xFF652580)),
            ),
          ),
          
          // Instrucción para el usuario
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Color(0xFF652580)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toca el mapa o arrastra el marcador para ajustar la ubicación',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Botón de emergencia
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: ElevatedButton(
              onPressed: _selectedPosition != null ? _requestAmbulance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'SOLICITAR AMBULANCIA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

