import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tanks/application/tank_providers.dart';
import 'backup_transfer_gateway.dart';
import 'complete_backup_service.dart';
import 'test_record_csv_export_service.dart';

final completeBackupServiceProvider = Provider<CompleteBackupService>((ref) {
  return CompleteBackupService(ref.watch(localBackupServiceProvider));
});

final testRecordCsvExportServiceProvider = Provider<TestRecordCsvExportService>(
  (ref) {
    return TestRecordCsvExportService(ref.watch(appDatabaseProvider));
  },
);

final backupTransferGatewayProvider = Provider<BackupTransferGateway>((ref) {
  return const FlutterBackupTransferGateway();
});
