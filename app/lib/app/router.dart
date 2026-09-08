import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/tanks/application/tank_providers.dart';
import '../features/calculators/domain/calculator_session.dart';

import '../features/home/presentation/home_page.dart';
import '../features/calculators/presentation/lanthanum_calculator_page.dart';
import '../features/calculators/presentation/salinity_calculator_page.dart';
import '../features/image_estimation/domain/photo_capture_models.dart';
import '../features/image_estimation/presentation/photo_capture_page.dart';
import '../features/maintenance/presentation/maintenance_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/privacy_and_limits_page.dart';
import '../features/test_records/presentation/test_records_page.dart';
import '../features/test_timer/presentation/test_workflow_page.dart';
import '../features/trends/presentation/trends_page.dart';
import 'shell_page.dart';
import '../features/calculators/presentation/alkalinity_calculator_page.dart';
import '../features/calculators/presentation/maintenance_dosing_page.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/test', builder: (_, _) => const TestRecordsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trends',
              builder: (_, state) => TrendsPage(
                initialParameterId: state.uri.queryParameters['parameterId'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/maintenance',
              builder: (_, state) => MaintenancePage(
                initialTaskId: state.uri.queryParameters['taskId'],
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/alkalinity-calculator',
      builder: (_, _) => const AlkalinityCalculatorPage(),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    GoRoute(
      path: '/maintenance-dosing',
      builder: (_, _) => Consumer(
        builder: (context, ref, child) {
          final tank = ref.watch(currentTankProvider);
          return tank.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                const Scaffold(body: Center(child: Text('无法读取当前海缸'))),
            data: (value) => MaintenanceDosingPage(
              key: ValueKey(value?.id),
              tankName: value?.name,
              previousKh: value == null
                  ? null
                  : ref.read(calculatorSessionProvider).khPlanFor(value.id),
            ),
          );
        },
      ),
    ),
    GoRoute(
      path: '/salinity-calculator',
      builder: (_, _) => const SalinityCalculatorPage(),
    ),
    GoRoute(
      path: '/lanthanum-calculator',
      builder: (_, _) => const LanthanumCalculatorPage(),
    ),
    GoRoute(
      path: '/privacy-and-limits',
      builder: (_, _) => const PrivacyAndLimitsPage(),
    ),
    GoRoute(
      path: '/photo-capture',
      builder: (_, state) => PhotoCapturePage(
        request: PhotoCaptureRequest.fromQueryParameters(
          state.uri.queryParameters,
        ),
      ),
    ),
    GoRoute(
      path: '/test-flow',
      builder: (_, state) => TestWorkflowPage(
        initialSessionId: state.uri.queryParameters['sessionId'],
      ),
    ),
  ],
);

final appRouter = createAppRouter();
