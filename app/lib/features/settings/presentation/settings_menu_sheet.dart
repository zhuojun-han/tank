import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_error_view.dart';
import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../../test_records/presentation/test_records_page.dart';
import 'settings_entry_dialog.dart';
import 'settings_page.dart';

Future<void> showSettingsMenu(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SettingsMenu(appContext: context),
    );

class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.appContext});
  final BuildContext appContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tank = ref.watch(currentTankProvider).value;
    void openPage(Widget page) {
      Navigator.pop(context);
      Navigator.of(
        appContext,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    void openRoute(String route) {
      Navigator.pop(context);
      appContext.push(route);
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '设置与工具',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭设置',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                _MenuItem(
                  icon: Icons.water,
                  title: '海缸管理',
                  subtitle: tank?.name,
                  onTap: () => openPage(
                    const SettingsPage(section: SettingsSection.tanks),
                  ),
                ),
                _MenuItem(
                  icon: Icons.tune,
                  title: '关注指标管理',
                  onTap: tank == null
                      ? null
                      : () => openPage(ParameterSettingsPage(tank: tank)),
                ),
                _MenuItem(
                  icon: Icons.track_changes,
                  title: '水质目标范围',
                  onTap: tank == null
                      ? null
                      : () => openPage(TargetSettingsPage(tank: tank)),
                ),
                _MenuItem(
                  icon: Icons.opacity,
                  title: '稳定滴定配方',
                  onTap: () => openRoute('/maintenance-dosing'),
                ),
                _MenuItem(
                  icon: Icons.trending_down,
                  title: 'PO4 理论计划',
                  onTap: () => openRoute('/lanthanum-calculator'),
                ),
                _MenuItem(
                  icon: Icons.trending_up,
                  title: 'KH 理论计划',
                  onTap: () => openRoute('/alkalinity-calculator'),
                ),
                _MenuItem(
                  icon: Icons.water_drop_outlined,
                  title: '海盐计算',
                  onTap: () => openRoute('/salinity-calculator'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: '任务提醒',
                  onTap: () => openPage(
                    const SettingsPage(section: SettingsSection.reminders),
                  ),
                ),
                _MenuItem(
                  icon: Icons.brightness_6_outlined,
                  title: '外观',
                  subtitle: switch (ref.watch(themeModeProvider).value) {
                    ThemeMode.light => '浅色',
                    ThemeMode.dark => '深色',
                    _ => '跟随系统',
                  },
                  onTap: () => _showAppearance(context),
                ),
                _MenuItem(
                  icon: Icons.backup_outlined,
                  title: '备份与数据',
                  onTap: () => openPage(
                    const SettingsPage(section: SettingsSection.data),
                  ),
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私与已知限制',
                  onTap: () => openRoute('/privacy-and-limits'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: scheme.primary),
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}

Future<void> showTankSwitcher(BuildContext context, WidgetRef ref) async {
  final appContext = context;
  final selected = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final tanks = sheetRef.watch(activeTanksProvider);
        final current = sheetRef.watch(currentTankProvider).value?.id;
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '切换海缸',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        showTankEditor(appContext);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tanks.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取海缸：$error'),
                  data: (items) => ListView(
                    children: [
                      for (final tank in items)
                        ListTile(
                          title: Text(tank.name),
                          leading: Icon(
                            tank.id == current
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          selected: tank.id == current,
                          onTap: () => Navigator.pop(sheetContext, tank.id),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    await ref.read(tankRepositoryProvider).switchTank(selected);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

Future<void> _showAppearance(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AppearanceDialog(),
);

class _AppearanceDialog extends ConsumerStatefulWidget {
  const _AppearanceDialog();

  @override
  ConsumerState<_AppearanceDialog> createState() => _AppearanceDialogState();
}

class _AppearanceDialogState extends ConsumerState<_AppearanceDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _select(ThemeMode? mode) async {
    if (mode == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tankRepositoryProvider).setThemeMode(mode.name);
      if (!mounted) return;
      ref.invalidate(themeModeProvider);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('外观'),
      content: SingleChildScrollView(
        child: RadioGroup<ThemeMode>(
          groupValue: ref.watch(themeModeProvider).value ?? ThemeMode.system,
          onChanged: _select,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                value: ThemeMode.system,
                title: const Text('跟随系统'),
                enabled: !_saving,
              ),
              RadioListTile(
                value: ThemeMode.light,
                title: const Text('浅色'),
                enabled: !_saving,
              ),
              RadioListTile(
                value: ThemeMode.dark,
                title: const Text('深色'),
                enabled: !_saving,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TargetSettingsPage extends ConsumerWidget {
  const TargetSettingsPage({required this.tank, super.key});
  final Tank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parameters = ref.watch(enabledParametersProvider(tank.id));
    final targets = ref.watch(waterQualityTargetsProvider(tank.id));
    return Scaffold(
      appBar: AppBar(title: const Text('水质目标范围')),
      body: parameters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: '无法读取指标：$error'),
        data: (items) => targets.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取目标：$error'),
          data: (ranges) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(tank.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              for (final parameter in items)
                Builder(
                  builder: (context) {
                    final target = ranges
                        .where((t) => t.parameterId == parameter.id)
                        .firstOrNull;
                    final text = target == null
                        ? '未设置'
                        : '${target.minValue ?? '—'}–${target.maxValue ?? '—'} ${parameter.unit}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          title: Text(
                            '${parameter.code} · ${parameter.displayName}',
                          ),
                          subtitle: Text(text),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showWaterQualityTargetEditor(
                            context,
                            ref,
                            tankId: tank.id,
                            parameter: parameter,
                            target: target,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
