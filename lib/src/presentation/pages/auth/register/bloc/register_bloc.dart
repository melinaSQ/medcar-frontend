import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/usecases/register_usecase.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_state.dart';
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  // 1. Declara la dependencia del caso de uso
  final RegisterUseCase registerUseCase;

  // El formKey se puede quedar, es útil
  final formKey = GlobalKey<FormState>();

  // 2. Modifica el constructor para que requiera el caso de uso
  RegisterBloc({required this.registerUseCase}) : super(const RegisterState()) {
    on<RegisterInitEvent>((event, emit) {
      emit(state.copyWith(formKey: formKey));
    });


    on<NameChanged>((event, emit) {
      emit(state.copyWith(
          name: BlocFormItem(
              value: event.name.value,
              error: event.name.value.isEmpty ? 'Ingresa el nombre' : null),
          formKey: formKey));
    });

    on<LastnameChanged>((event, emit) {
      emit(state.copyWith(
          lastname: BlocFormItem(
              value: event.lastname.value,
              error:
                  event.lastname.value.isEmpty ? 'Ingresa el apellido' : null),
          formKey: formKey));
    });

    on<EmailChanged>((event, emit) {
      emit(state.copyWith(
          email: BlocFormItem(
              value: event.email.value,
              error: event.email.value.isEmpty ? 'Ingresa el correo electrónico' : null),
          formKey: formKey));
    });

    on<PhoneChanged>((event, emit) {
      emit(state.copyWith(
          phone: BlocFormItem(
              value: event.phone.value,
              error: event.phone.value.isEmpty ? 'Ingresa el telefono' : null),
          formKey: formKey));
    });

    on<PasswordChanged>((event, emit) {
      emit(state.copyWith(
          password: BlocFormItem(
              value: event.password.value,
              error: event.password.value.isEmpty
                  ? 'Ingresa la contraseña'
                  : event.password.value.length < 6
                      ? 'Mas de 6 caracteres'
                      : null),
          formKey: formKey));
    });

    on<ConfirmPasswordChanged>((event, emit) {
      emit(state.copyWith(
          confirmPassword: BlocFormItem(
              value: event.confirmPassword.value,
              error: event.confirmPassword.value.isEmpty
                  ? 'Confirma la contraseña'
                  : event.confirmPassword.value.length < 6
                      ? 'Mas de 6 caracteres'
                      : event.confirmPassword.value != state.password.value
                          ? 'Las contraseñas no coinciden'
                          : null),
          formKey: formKey));
    });

    on<FormSubmit>((event, emit) async {
      if (state.password.value != state.confirmPassword.value) {
        emit(state.copyWith(
          formStatus: RegisterFormStatus.failure,
          errorMessage: 'Las contraseñas no coinciden',
        ));
        return; 
      }

      emit(state.copyWith(formStatus: RegisterFormStatus.loading));

      try {
        await registerUseCase.call(
          name: state.name.value,
          lastname: state.lastname.value,
          email: state.email.value,
          phone: state.phone.value,
          password: state.password.value,
        );
        emit(state.copyWith(formStatus: RegisterFormStatus.success));
      } catch (e) {
        emit(state.copyWith(
          formStatus: RegisterFormStatus.failure,
          errorMessage: e.toString(),
        ));
      }
    });

    on<FormReset>((event, emit) {
      state.formKey?.currentState?.reset();
    });

    on<ResetFormStatus>((event, emit) {
      emit(state.copyWith(formStatus: RegisterFormStatus.initial));
    });
  }
}
