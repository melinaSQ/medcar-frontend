import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';

List<BlocProvider> blocProviders = [
  BlocProvider<LoginBloc>(create: (context) => sl<LoginBloc>()),
  BlocProvider<RegisterBloc>(create: (context) => sl<RegisterBloc>()),
  BlocProvider<ClientHomeBloc>(create: (context) => sl<ClientHomeBloc>()),
];