import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/navigation/app_navigator.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

/// Cierra sesión y vuelve al login cuando una petición autenticada recibe 401
/// (token inválido, expirado o cuenta bloqueada).
class UnauthorizedSessionHandler {
  UnauthorizedSessionHandler._();

  static bool _busy = false;

  static Future<void> handle() async {
    if (_busy) return;
    _busy = true;
    try {
      await di.sl<AuthRepository>().logout();
      final nav = appNavigatorKey.currentState;
      if (nav != null && nav.mounted) {
        nav.pushNamedAndRemoveUntil('login', (route) => false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showDialog<void>(
              context: ctx,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                icon: const Icon(Icons.lock_outline, color: Colors.red, size: 40),
                title: const Text('Sesión cerrada'),
                content: const SingleChildScrollView(
                  child: Text(
                    'Tu sesión ya no es válida o tu cuenta fue bloqueada por un administrador. '
                    'Mientras esté bloqueada no podrás usar la app; si el acceso se restaura, '
                    'podrás iniciar sesión de nuevo. Si tu cuenta fue eliminada, deberás registrarte otra vez.',
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } finally {
      _busy = false;
    }
  }
}
