import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/first_launch_service.dart';
import '../../data/services/library_form_draft_service.dart';
import 'registrars/blocs_registrar.dart';
import 'registrars/external_registrar.dart';
import 'registrars/repositories_registrar.dart';
import 'registrars/services_registrar.dart';
import 'registrars/use_cases_registrar.dart';
import 'service_locator.dart';

export 'service_locator.dart' show sl;

/// Initializes all dependencies. Call this before [runApp].
Future<void> initDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  final packageInfo = await PackageInfo.fromPlatform();
  sl.registerLazySingleton<PackageInfo>(() => packageInfo);

  sl.registerLazySingleton<FirstLaunchService>(() => FirstLaunchService(sl()));
  sl.registerLazySingleton<LibraryFormDraftService>(
    () => LibraryFormDraftService(sl()),
  );

  registerExternalDependencies(sl);
  registerDataLayerServices(sl);
  registerRepositories(sl);
  registerUseCases(sl);
  registerBlocsAndFeatureModules(sl);
}
