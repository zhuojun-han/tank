import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tanks/application/tank_providers.dart';
import '../data/test_record_repository.dart';
import '../data/local_photo_storage.dart';

final testRecordRepositoryProvider = Provider<TestRecordRepository>((ref) {
  return TestRecordRepository(ref.watch(appDatabaseProvider));
});

final localPhotoStorageProvider = Provider<LocalPhotoStorage>(
  (ref) => const LocalPhotoStorage(),
);

final latestTestRecordsProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(testRecordRepositoryProvider).watchLatestForTank(tankId);
});

typedef TestRecordScope = ({String tankId, String recordId});

final testRecordProvider = FutureProvider.family((ref, TestRecordScope scope) {
  return ref
      .watch(testRecordRepositoryProvider)
      .readById(tankId: scope.tankId, id: scope.recordId);
});

final reagentProfilesProvider = StreamProvider.family((
  ref,
  String parameterId,
) {
  return ref
      .watch(testRecordRepositoryProvider)
      .watchReagentsForParameter(parameterId, includeDisabled: true);
});

final enabledReagentProfilesProvider = StreamProvider.family((
  ref,
  String parameterId,
) {
  return ref
      .watch(testRecordRepositoryProvider)
      .watchReagentsForParameter(parameterId);
});
