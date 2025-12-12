import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';

List<BlocProvider> blocProviders = [
  // Pide a 'get_it' (sl) que cree una instancia de LoginBloc
  BlocProvider<LoginBloc>(create: (context) => sl<LoginBloc>()),
  // Pide a 'get_it' (sl) que cree una instancia de RegisterBloc
  BlocProvider<RegisterBloc>(create: (context) => sl<RegisterBloc>()),
];