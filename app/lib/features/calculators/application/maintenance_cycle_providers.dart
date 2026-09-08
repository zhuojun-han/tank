import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tanks/application/tank_providers.dart';
import '../data/maintenance_cycle_repository.dart';

final maintenanceCycleRepositoryProvider = Provider<MaintenanceCycleRepository>(
  (ref) => MaintenanceCycleRepository(ref.watch(appDatabaseProvider)),
);

final maintenanceCyclesProvider = StreamProvider.autoDispose.family(
  (ref, String tankId) =>
      ref.watch(maintenanceCycleRepositoryProvider).watchCycles(tankId: tankId),
);

final allMaintenanceCyclesProvider = StreamProvider(
  (ref) => ref.watch(maintenanceCycleRepositoryProvider).watchCycles(),
);
