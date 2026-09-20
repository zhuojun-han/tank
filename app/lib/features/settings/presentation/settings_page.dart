import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import 'settings_entry_dialog.dart';
import '../../../core/errors/app_error_view.dart';
import '../../../core/notifications/local_notification.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../data/backup/backup_providers.dart';
import '../../../data/backup/backup_transfer_gateway.dart';
import '../../../data/backup/complete_backup_service.dart';
import '../../../data/database/app_database.dart';
import '../../maintenance/application/maintenance_notification_coordinator.dart';
import '../../maintenance/application/maintenance_notification_providers.dart';
import '../../maintenance/application/maintenance_providers.dart';
import '../../tanks/application/tank_providers.dart';
import '../../tanks/domain/tank_age.dart';

enum SettingsSection { all, tanks, reminders, data }

class SettingsPage extends ConsumerWidget {
  const SettingsPage({this.section = SettingsSection.all, super.key});

  final SettingsSection section;

  bool _shows(SettingsSection value) =>
      section == SettingsSection.all || section == value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanks = ref.watch(activeTanksProvider);
    final currentTank = ref.watch(currentTankProvider).value;
    final today = ref.watch(maintenanceDateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (section) {
          SettingsSection.all => '设置',
          SettingsSection.tanks => '海缸管理',
          SettingsSection.reminders => '任务提醒',
          SettingsSection.data => '备份与数据',
        }),
        actions: [
          if (_shows(SettingsSection.tanks))
            IconButton(
              tooltip: '添加海缸',
              onPressed: () => showTankEditor(context),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: tanks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: '无法读取海缸：$error'),
        data: (items) => RadioGroup<String>(
          groupValue: currentTank?.id,
          onChanged: (value) async {
            if (value != null) {
              await _run(
                context,
                () => ref.read(tankRepositoryProvider).switchTank(value),
              );
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              if (_shows(SettingsSection.tanks)) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('海缸管理'),
                ),
                for (final tank in items)
                  RadioListTile<String>(
                    value: tank.id,
                    title: Text(tank.name),
                    subtitle: Text(
                      [
                        if (tank.notes?.isNotEmpty ?? false) tank.notes!,
                        if (tank.volumeLiters != null)
                          '${tank.volumeLiters.toString().replaceFirst(RegExp(r'\.0$'), '')} L',
                        formatTankAge(tank.startedOn, today),
                        if (tank.startedOn != null) '开缸 ${tank.startedOn}',
                      ].join(' · '),
                    ),
                    secondary: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await showTankEditor(context, tank: tank);
                        } else if (action == 'parameters') {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ParameterSettingsPage(tank: tank),
                            ),
                          );
                        } else if (action == 'archive') {
                          await _run(
                            context,
                            () => ref
                                .read(tankRepositoryProvider)
                                .archiveTank(tank.id),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'parameters', child: Text('参数')),
                        PopupMenuItem(value: 'archive', child: Text('归档')),
                      ],
                    ),
                  ),
              ],
              if (section == SettingsSection.all) ...[
                const Divider(),
                ListTile(
                  key: const Key('open-maintenance-dosing'),
                  leading: const Icon(Icons.opacity),
                  title: const Text('稳定滴定'),
                  subtitle: const Text('PO₄ / KH 每日平衡与补液'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/maintenance-dosing'),
                ),
                ListTile(
                  key: const Key('open-salinity-calculator'),
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('海盐配制计算器'),
                  subtitle: const Text('按初始比重、目标比重和水量估算海盐'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/salinity-calculator'),
                ),
                ListTile(
                  title: const Text('碳酸氢钠补 KH'),
                  subtitle: const Text('母液配制与分日计划'),
                  leading: const Icon(Icons.science_outlined),
                  onTap: () => context.push('/alkalinity-calculator'),
                ),
                ListTile(
                  key: const Key('open-lanthanum-calculator'),
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('PO4 氯化镧理论计划'),
                  subtitle: const Text('母液配制与分日计划'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/lanthanum-calculator'),
                ),
                const Divider(),
              ],
              if (_shows(SettingsSection.reminders)) ...[
                const _NotificationPermissionSection(),
              ],
              if (_shows(SettingsSection.data)) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('导出完整数据备份'),
                  subtitle: const Text('保存本机全部数据，不含检测照片'),
                  onTap: () async {
                    try {
                      final report = await ref
                          .read(completeBackupServiceProvider)
                          .exportToPrivateFile();
                      final status = await ref
                          .read(backupTransferGatewayProvider)
                          .shareCompleteBackup(report.file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _shareResultMessage(
                                status,
                                success: '完整数据备份已交给系统分享面板',
                                privatePath: report.file.path,
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) _showError(context, error);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('导入完整数据备份'),
                  subtitle: const Text('以备份替换本机数据'),
                  onTap: () => _pickAndConfirmRestore(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('导出当前海缸检测记录 CSV'),
                  subtitle: Text(
                    currentTank == null ? '请先选择海缸' : currentTank.name,
                  ),
                  onTap: currentTank == null
                      ? null
                      : () => _exportCsv(context, ref, currentTank.id),
                ),
                ListTile(
                  key: const Key('privacy-and-limits'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私与已知限制'),
                  subtitle: const Text('本地数据与权限'),
                  onTap: () => context.push('/privacy-and-limits'),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('深色模式'),
                  value: ref.watch(themeModeProvider).value == ThemeMode.dark,
                  onChanged: (enabled) => _run(context, () async {
                    await ref
                        .read(tankRepositoryProvider)
                        .setThemeMode(enabled ? 'dark' : 'light');
                    ref.invalidate(themeModeProvider);
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _NotificationPermissionSection extends ConsumerStatefulWidget {
  const _NotificationPermissionSection();

  @override
  ConsumerState<_NotificationPermissionSection> createState() =>
      _NotificationPermissionSectionState();
}

final class _NotificationPermissionSectionState
    extends ConsumerState<_NotificationPermissionSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationPermission(ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationPermission = ref.watch(
      notificationPermissionStatusProvider,
    );
    final notificationSync = ref.watch(
      maintenanceNotificationSyncStateProvider,
    );
    final enabledPreference = ref.watch(
      maintenanceNotificationsEnabledPreferenceProvider,
    );
    final notificationsEnabled = enabledPreference.value ?? true;
    final showSystemSettings = notificationPermission.when(
      data: (status) => status == NotificationPermissionStatus.denied,
      error: (_, _) => false,
      loading: () => false,
    );
    return Column(
      children: [
        SwitchListTile(
          key: const Key('maintenance-notification-toggle'),
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('维护任务弹窗提醒'),
          subtitle: Text(notificationsEnabled ? '到期及未完成提醒' : '已关闭提醒'),
          value: notificationsEnabled,
          onChanged: enabledPreference.isLoading
              ? null
              : (enabled) async {
                  await ref
                      .read(tankRepositoryProvider)
                      .setMaintenanceNotificationsEnabled(enabled);
                  if (!context.mounted) return;
                  if (enabled) {
                    await _requestNotificationPermission(context, ref);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已关闭维护任务系统提醒')),
                    );
                  }
                },
        ),
        ListTile(
          key: const Key('notification-permission'),
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('维护任务通知'),
          subtitle: Text(
            '${_notificationPermissionLabel(notificationPermission)}\n'
            '${_notificationSyncLabel(notificationSync)}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: notificationsEnabled
              ? () => _requestNotificationPermission(context, ref)
              : null,
        ),
        if (showSystemSettings)
          ListTile(
            key: const Key('open-notification-settings'),
            leading: const Icon(Icons.settings_outlined),
            title: const Text('打开系统通知设置'),
            subtitle: const Text('若系统不再弹出授权窗口，请在系统设置中允许通知'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openNotificationSettings(context, ref),
          ),
      ],
    );
  }
}

Future<void> _requestNotificationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(localNotificationServiceProvider);
  final initialization = await service.initialize();
  final status = initialization.succeeded
      ? await service.requestPermission()
      : NotificationPermissionStatus.unavailable;
  ref.invalidate(notificationPermissionStatusProvider);
  if (status == NotificationPermissionStatus.granted) {
    await ref.read(maintenanceNotificationCoordinatorProvider).reconcileNow();
  }
  if (!context.mounted) return;
  final message = switch (status) {
    NotificationPermissionStatus.granted => '通知权限已开启，维护提醒正在同步。',
    NotificationPermissionStatus.denied => '通知权限未开启；任务仍会正常保存在本机。',
    NotificationPermissionStatus.unsupported => '当前平台不支持此通知能力；任务不受影响。',
    NotificationPermissionStatus.unavailable => '暂时无法访问通知服务；任务不受影响，可稍后重试。',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _openNotificationSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(localNotificationServiceProvider);
  final initialization = await service.initialize();
  final result = initialization.succeeded
      ? await service.openAppNotificationSettings()
      : const NotificationOperationResult.unavailable();
  if (!context.mounted) return;
  final message = switch (result.status) {
    NotificationOperationStatus.succeeded => '已打开系统通知设置；返回 App 后会重新检查并同步提醒。',
    NotificationOperationStatus.unsupported => '当前平台不支持从 App 打开通知设置。',
    NotificationOperationStatus.unavailable => '暂时无法打开系统通知设置，请稍后重试。',
    NotificationOperationStatus.permissionDenied => '系统未允许打开通知设置，请手动进入系统设置。',
    NotificationOperationStatus.invalidRequest => '通知设置请求无效，请手动进入系统设置。',
    NotificationOperationStatus.failed => '打开系统通知设置失败，请手动进入系统设置。',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _refreshNotificationPermission(WidgetRef ref) async {
  ref.invalidate(notificationPermissionStatusProvider);
  final permission = ref.read(notificationPermissionStatusProvider.future);
  final coordinator = ref.read(maintenanceNotificationCoordinatorProvider);
  if (await permission == NotificationPermissionStatus.granted) {
    await coordinator.reconcileNow();
  }
}

String _notificationPermissionLabel(
  AsyncValue<NotificationPermissionStatus> permission,
) {
  return permission.when(
    loading: () => '通知权限：正在检查',
    error: (_, _) => '通知权限：暂时无法检查',
    data: (status) => switch (status) {
      NotificationPermissionStatus.granted => '通知权限：已开启',
      NotificationPermissionStatus.denied => '通知权限：未开启，点此请求',
      NotificationPermissionStatus.unsupported => '通知权限：当前平台不支持',
      NotificationPermissionStatus.unavailable => '通知权限：服务暂不可用，点此重试',
    },
  );
}

String _notificationSyncLabel(
  AsyncValue<MaintenanceNotificationSyncState> sync,
) {
  return sync.when(
    loading: () => '提醒同步：准备中',
    error: (_, _) => '提醒同步：暂时失败',
    data: (state) => switch (state.phase) {
      MaintenanceNotificationSyncPhase.idle => '提醒同步：等待任务数据',
      MaintenanceNotificationSyncPhase.syncing => '提醒同步：进行中',
      MaintenanceNotificationSyncPhase.ready => '提醒同步：已完成',
      MaintenanceNotificationSyncPhase.permissionDenied => '提醒同步：等待通知权限',
      MaintenanceNotificationSyncPhase.unavailable => '提醒同步：通知服务不可用',
      MaintenanceNotificationSyncPhase.failed => '提醒同步：部分提醒安排失败，可稍后重试',
    },
  );
}

Future<void> _pickAndConfirmRestore(BuildContext context, WidgetRef ref) async {
  try {
    final file = await ref
        .read(backupTransferGatewayProvider)
        .pickCompleteBackup();
    if (file == null || !context.mounted) return;
    final preview = await ref
        .read(completeBackupServiceProvider)
        .validateFile(file);
    if (!context.mounted) return;
    await _confirmRestore(context, ref, file, preview);
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<void> _confirmRestore(
  BuildContext context,
  WidgetRef ref,
  File file,
  CompleteBackupPreview preview,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('以备份替换本机业务数据？'),
      content: const Text(
        '本机海缸、设置、检测记录、任务及历史将被备份替换，鱼类档案和自定义图片一并恢复。'
        '不导入检测照片；提醒按本机权限重新安排。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认替换并恢复'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final report = await ref
        .read(completeBackupServiceProvider)
        .restoreReplaceFromFile(file);
    ref.invalidate(themeModeProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '数据恢复完成：${report.result.insertedTankCount} 个海缸、'
          '${report.result.insertedRecordCount} 条检测记录、'
          '${report.result.insertedTaskCount} 个每日任务；提醒正在按本机权限重排。',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<void> _exportCsv(
  BuildContext context,
  WidgetRef ref,
  String tankId,
) async {
  try {
    final file = await ref
        .read(testRecordCsvExportServiceProvider)
        .exportToPrivateFile(tankId);
    final status = await ref.read(backupTransferGatewayProvider).shareCsv(file);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _shareResultMessage(
            status,
            success: 'CSV 已交给系统分享面板',
            privatePath: file.path,
          ),
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

String _shareResultMessage(
  BackupShareStatus status, {
  required String success,
  required String privatePath,
}) => switch (status) {
  BackupShareStatus.success => success,
  BackupShareStatus.dismissed => '已取消分享；私有副本保留在 $privatePath',
  BackupShareStatus.unavailable => '系统分享暂不可用；私有副本保留在 $privatePath',
};

class ParameterSettingsPage extends ConsumerWidget {
  const ParameterSettingsPage({required this.tank, super.key});

  final Tank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states = ref.watch(parameterStatesProvider(tank.id));
    return Scaffold(
      appBar: AppBar(
        title: Text('${tank.name} · 参数'),
        actions: [
          IconButton(
            tooltip: '自定义参数',
            onPressed: () => _showParameterDialog(context, ref, tank.id),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: states.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: '无法读取参数：$error'),
        data: (items) => ListView(
          children: [
            for (final state in items)
              SwitchListTile(
                title: Text(
                  '${state.parameter.code} · ${state.parameter.displayName}',
                ),
                subtitle: Text(
                  '${state.parameter.unit}${state.parameter.photoSupported ? ' · 支持拍照辅助' : ''}',
                ),
                value: state.isEnabled,
                onChanged: (enabled) => _run(
                  context,
                  () => ref
                      .read(tankRepositoryProvider)
                      .setParameterEnabled(
                        tankId: tank.id,
                        parameterId: state.parameter.id,
                        enabled: enabled,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showParameterDialog(
  BuildContext context,
  WidgetRef ref,
  String tankId,
) => showDialog<void>(
  context: context,
  builder: (_) => SettingsEntryDialog.parameter(tankId: tankId),
);

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}
