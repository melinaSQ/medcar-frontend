
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

abstract class LoginEvent {}

//evento para inicializar el formulario
class LoginInitEvent extends LoginEvent {}


//evento para cambiar el email
class EmailChanged extends LoginEvent {
  final BlocFormItem email;
  EmailChanged({ required this.email });
}

//evento para cambiar la contraseña
class PasswordChanged extends LoginEvent {
  final BlocFormItem password;
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

//evento para resetear el estado del formulario
class ResetFormStatus extends LoginEvent {}

//evento para limpiar todos los campos del formulario
class ResetLoginForm extends LoginEvent {}