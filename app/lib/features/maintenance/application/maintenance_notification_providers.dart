import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/flutter_local_notification_gateway.dart';
import '../../../core/notifications/local_notification.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../tanks/application/tank_providers.dart';
import 'maintenance_notification_coordinator.dart';
import 'maintenance_providers.dart';
import '../../calculators/application/maintenance_cycle_providers.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return createLocalNotificationService();
});

final notificationsEnabledProvider = Provider<bool>((ref) => true);

final localNotificationTapProvider = StreamProvider<LocalNotificationTap>((
  ref,
) {
  return ref.watch(localNotificationServiceProvider).taps;
});

final notificationPermissionStatusProvider =
    FutureProvider<NotificationPermissionStatus>((ref) async {
      final service = ref.watch(localNotificationServiceProvider);
      final initialization = await service.initialize();
      if (!initialization.succeeded) {
        return NotificationPermissionStatus.unavailable;
      }
      return service.permissionStatus();
    });

final maintenanceNotificationCoordinatorProvider =
    Provider<MaintenanceNotificationCoordinator>((ref) {
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: RepositoryMaintenanceNotificationTaskStore(
          ref.watch(maintenanceRepositoryProvider),
          cycles: ref.watch(maintenanceCycleRepositoryProvider),
        ),
        notificationService: ref.watch(localNotificationServiceProvider),
        notificationsEnabled: ref
            .watch(tankRepositoryProvider)
            .watchMaintenanceNotificationsEnabled(),
      );
      if (ref.watch(notificationsEnabledProvider)) {
        unawaited(coordinator.start());
      }
      ref.listen(maintenanceDateProvider, (previous, next) {
        if (previous != null && previous != next) {
          unawaited(coordinator.reconcileNow());
        }
      });
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });

final maintenanceNotificationSyncStateProvider =
    StreamProvider<MaintenanceNotificationSyncState>((ref) async* {
      final coordinator = ref.watch(maintenanceNotificationCoordinatorProvider);
      yield coordinator.currentState;
      yield* coordinator.states;
    });
