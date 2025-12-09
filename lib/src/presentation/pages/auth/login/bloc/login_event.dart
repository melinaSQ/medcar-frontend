
abstract class LoginEvent {}

//evento para inicializar el formulario
class LoginInitEvent extends LoginEvent {}


//evento para cambiar el email
class EmailChanged extends LoginEvent {
  final String email;
  EmailChanged({ required this.email });
}

//evento para cambiar la contraseña
class PasswordChanged extends LoginEvent {
  final String password;
  PasswordChanged({ required this.password });
}

/*

class SaveUserSession extends LoginEvent {
  final AuthResponse authResponse;
  SaveUserSession({ required this.authResponse });
}

class UpdateNotificationToken extends LoginEvent {
  final int id;
  UpdateNotificationToken({required this.id});
}
*/

//evento para enviar el formulario
class FormSubmit extends LoginEvent {}