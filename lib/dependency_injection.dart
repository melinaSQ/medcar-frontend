import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';
import 'package:medcar_frontend/src/data/repositories/auth_repository_impl.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart';
import 'package:medcar_frontend/src/domain/usecases/register_usecase.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Blocs
  sl.registerFactory(() => LoginBloc(loginUseCase: sl()));
  sl.registerFactory(() => RegisterBloc(registerUseCase: sl()));

  // Use Cases
  sl.registerFactory(() => LoginUseCase(sl()));
  sl.registerFactory(() => RegisterUseCase(sl()));
  
  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remoteDataSource: sl()));

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(client: sl()));

  // Externals
  sl.registerLazySingleton(() => http.Client());
}