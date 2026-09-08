import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/settings/presentation/settings_page.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';

void main() {
  for (final custom in [false, true]) {
    for (final save in [false, true]) {
      testWidgets(
        '${custom ? "parameter" : "tank"} focused dialog ${save ? "save" : "cancel"} survives reverse transition',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          final tank = await db.select(db.tanks).getSingle();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                notificationsEnabledProvider.overrideWithValue(false),
                notificationPermissionStatusProvider.overrideWith(
                  (ref) async => NotificationPermissionStatus.denied,
                ),
                maintenanceNotificationSyncStateProvider.overrideWith(
                  (ref) => const Stream.empty(),
                ),
              ],
              child: MaterialApp(
                home: custom
                    ? ParameterSettingsPage(tank: tank)
                    : const SettingsPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(custom ? '自定义参数' : '添加海缸'));
          await tester.pumpAndSettle();
          final fields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(fields.at(0), custom ? 'AUDIT' : 'Audit tank');
          if (custom) {
            await tester.enterText(fields.at(1), 'Audit parameter');
            await tester.enterText(fields.at(2), 'mg/L');
          }
          await tester.tap(find.text(save ? '保存' : '取消'));
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(tester.takeException(), isNull);
          expect(find.byType(AlertDialog), findsNothing);
          if (custom) {
            final params = await db.select(db.waterParameters).get();
            expect(params.any((p) => p.code == 'AUDIT'), save);
          } else {
            final tanks = await db.select(db.tanks).get();
            expect(tanks.any((t) => t.name == 'Audit tank'), save);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
        },
      );
    }
  }
}
