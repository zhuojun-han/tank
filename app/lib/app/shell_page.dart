import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/presentation/settings_menu_sheet.dart';
import '../features/tanks/application/tank_providers.dart';

class ShellPage extends ConsumerWidget {
  const ShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tank = ref.watch(currentTankProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: math.max(
          76,
          MediaQuery.textScalerOf(context).scale(30) * 1.5 + 16,
        ),
        titleSpacing: 18,
        title: InkWell(
          key: const Key('shell-tank-switcher'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => showTankSwitcher(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary,
                        scheme.primary.withValues(alpha: .68),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(Icons.waves, color: scheme.onPrimary, size: 23),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '我的海缸',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        tank.value?.name ?? (tank.isLoading ? '加载中' : '选择海缸'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          const SizedBox(width: 8),
          IconButton(
            tooltip: '设置',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surface,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            onPressed: () => showSettingsMenu(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              label: '检测',
            ),
            NavigationDestination(icon: Icon(Icons.show_chart), label: '趋势'),
            NavigationDestination(icon: Icon(Icons.task_alt), label: '任务'),
          ],
        ),
      ),
    );
  }
}
