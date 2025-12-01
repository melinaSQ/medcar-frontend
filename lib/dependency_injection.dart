// lib/dependency_injection.dart

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';
import 'package:medcar_frontend/src/data/repositories/auth_repository_impl.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart';
import 'package:medcar_frontend/src/domain/usecases/register_usercase.dart';

// Creamos una instancia global de GetIt
final sl = GetIt.instance; // sl = Service Locator

Future<void> init() async {
  
  // #############################
  // ## Use Cases (Casos de Uso)
  // #############################
  // Los Use Cases son 'factory' porque podrían ser instanciados de nuevo si fuera necesario,
  // aunque generalmente se comportan como singletons.
  sl.registerFactory(() => LoginUseCase(sl()));
  sl.registerFactory(() => RegisterUseCase(sl()));
  
  // #############################
  // ## Repositories (Repositorios)
  // #############################
  // Los repositorios se registran como 'lazySingleton'. Esto significa que se creará una
  // única instancia la PRIMERA vez que se necesite, y luego se reutilizará.
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // #############################
  // ## Data Sources (Fuentes de Datos)
  // #############################
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );

  // #############################
  // ## Externals (Dependencias Externas)
  // #############################
  // Registramos el cliente HTTP como un singleton para que toda la app reutilice la misma conexión.
  sl.registerLazySingleton(() => http.Client());

}