import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../../maintenance/application/maintenance_notification_providers.dart';
import '../../test_records/application/test_record_providers.dart';
import '../data/test_session_repository.dart';
import 'test_workflow_controller.dart';

typedef TestSessionScope = ({String tankId, String parameterId});

final testWorkflowNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final testSessionRepositoryProvider = Provider<TestSessionRepository>((ref) {
  return TestSessionRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(testWorkflowNowProvider),
  );
});

final testWorkflowControllerProvider = Provider<TestWorkflowController>((ref) {
  return TestWorkflowController(
    repository: ref.watch(testSessionRepositoryProvider),
    notifications: ref.watch(localNotificationServiceProvider),
    photoStorage: ref.watch(localPhotoStorageProvider),
    now: ref.watch(testWorkflowNowProvider),
  );
});

final testTimerDefaultProvider = StreamProvider.family<int, TestSessionScope>((
  ref,
  scope,
) {
  return ref
      .watch(testSessionRepositoryProvider)
      .watchDefaultDurationSeconds(
        tankId: scope.tankId,
        parameterId: scope.parameterId,
      );
});

final activeTestDraftProvider =
    StreamProvider.family<ActiveTestSession?, TestSessionScope>((ref, scope) {
      return ref
          .watch(testSessionRepositoryProvider)
          .watchDraft(tankId: scope.tankId, parameterId: scope.parameterId);
    });

final activeTestSessionByIdProvider =
    StreamProvider.family<ActiveTestSession?, String>((ref, sessionId) {
      return ref.watch(testSessionRepositoryProvider).watchDraftById(sessionId);
    });
