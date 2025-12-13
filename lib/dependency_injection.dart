import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/ambulances_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/company_admin_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/ratings_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/driver_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/shifts_remote_datasource.dart';
import 'package:medcar_frontend/src/data/repositories/auth_repository_impl.dart';
import 'package:medcar_frontend/src/data/repositories/service_request_repository_impl.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/repositories/service_request_repository.dart';
import 'package:medcar_frontend/src/domain/usecases/create_service_request_usecase.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart';
import 'package:medcar_frontend/src/domain/usecases/register_usecase.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // === EXTERNALS (sin dependencias) ===
  sl.registerLazySingleton(() => http.Client());

  // === DATA SOURCES (dependen de Externals) ===
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ServiceRequestRemoteDataSource>(
    () => ServiceRequestRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ShiftsRemoteDataSource>(
    () => ShiftsRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AmbulancesRemoteDataSource>(
    () => AmbulancesRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<DriverRemoteDataSource>(
    () => DriverRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<CompanyAdminRemoteDataSource>(
    () => CompanyAdminRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<RatingsRemoteDataSource>(
    () => RatingsRemoteDataSourceImpl(client: sl()),
  );

  // === REPOSITORIES (dependen de Data Sources) ===
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ServiceRequestRepository>(
    () => ServiceRequestRepositoryImpl(
      remoteDataSource: sl(),
      authRepository: sl(),
    ),
  );

  // === USE CASES (dependen de Repositories) ===
  sl.registerFactory(() => LoginUseCase(sl()));
  sl.registerFactory(() => RegisterUseCase(sl()));
  sl.registerFactory(() => CreateServiceRequestUseCase(sl()));

  // === BLOCS (dependen de Use Cases/Repositories) ===
  sl.registerFactory(() => LoginBloc(loginUseCase: sl()));
  sl.registerFactory(() => RegisterBloc(registerUseCase: sl()));
  sl.registerFactory(() => ClientHomeBloc(authRepository: sl()));
}
