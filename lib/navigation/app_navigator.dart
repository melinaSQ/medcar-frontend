import 'package:flutter/material.dart';

/// Clave global del navegador (evita dependencias circulares con [main.dart]).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
