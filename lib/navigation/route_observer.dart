import 'package:flutter/material.dart';

/// Observador global para refrescar pantallas al volver de otra ruta.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
