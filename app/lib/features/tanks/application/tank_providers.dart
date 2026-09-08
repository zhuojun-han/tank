import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/backup/local_backup_service.dart';
import '../../../data/database/app_database.dart';
import '../data/tank_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final tankRepositoryProvider = Provider<TankRepository>((ref) {
  return TankRepository(ref.watch(appDatabaseProvider));
});

final maintenanceNotificationsEnabledPreferenceProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(tankRepositoryProvider).watchMaintenanceNotificationsEnabled(),
);

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(ref.watch(appDatabaseProvider));
});

final activeTanksProvider = StreamProvider((ref) {
  return ref.watch(tankRepositoryProvider).watchActiveTanks();
});

final currentTankProvider = StreamProvider((ref) {
  return ref.watch(tankRepositoryProvider).watchCurrentTank();
});

final enabledParametersProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(tankRepositoryProvider).watchEnabledParameters(tankId);
});

final parameterStatesProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(tankRepositoryProvider).watchParameterStates(tankId);
});

final waterQualityTargetsProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(tankRepositoryProvider).watchTargets(tankId);
});
