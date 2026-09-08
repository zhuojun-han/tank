import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_view.dart';
import '../../../core/notifications/local_notification.dart';
import '../../../data/database/app_database.dart';
import '../../image_estimation/domain/photo_capture_models.dart';
import '../../tanks/application/tank_providers.dart';
import '../../test_records/application/test_record_providers.dart';
import '../application/test_session_providers.dart';
import '../application/test_workflow_controller.dart';
import '../data/test_session_repository.dart';
import '../domain/test_timer.dart';
import 'kh_titration_panel.dart';

class TestWorkflowPage extends ConsumerStatefulWidget {
  const TestWorkflowPage({
    this.initialSessionId,
    this.initialParameterId,
    super.key,
  });

  final String? initialSessionId;
  final String? initialParameterId;

  @override
  ConsumerState<TestWorkflowPage> createState() => _TestWorkflowPageState();
}

class _TestWorkflowPageState extends ConsumerState<TestWorkflowPage>
    with WidgetsBindingObserver {
  String? _autoPhotoSessionId;
  final _interpolationController = TextEditingController();
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  final _notesController = TextEditingController();

  Timer? _ticker;
  bool _resumed = false;
  ({String id, DateTime endsAt})? _elapsedAttempt;
  DateTime _nowUtc = DateTime.now().toUtc();
  String? _selectedTankId;
  String? _selectedParameterId;
  String? _selectedReagentId;
  String? _hydratedSessionId;
  ActiveTestSession? _visibleSession;
  DateTime _confirmedAt = DateTime.now();
  bool _rangeResult = false;
  bool _busy = false;
  bool _completingElapsed = false;
  Future<void> _reviewSaveChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _selectedParameterId = widget.initialParameterId;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _nowUtc = ref.read(testWorkflowNowProvider)().toUtc();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _minimumController.dispose();
    _interpolationController.dispose();
    _maximumController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _ticker?.cancel();
    _ticker = null;
    if (_resumed) {
      // The OS notification keeps its deadline while the UI is suspended.
      _elapsedAttempt = null;
      _tick();
      _syncTicker();
    }
  }

  void _setVisibleSession(ActiveTestSession? session) {
    _visibleSession = session;
    if (session?.stage != ActiveTestStage.timerRunning.name) {
      _elapsedAttempt = null;
    }
    _syncTicker();
  }

  void _syncTicker() {
    final session = _visibleSession;
    final running =
        session?.stage == ActiveTestStage.timerRunning.name &&
        session?.timerEndsAt != null;
    final attempted =
        running &&
        _elapsedAttempt == (id: session!.id, endsAt: session.timerEndsAt!);
    if (!_resumed || !running || attempted || _completingElapsed) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_resumed) return;
    final now = ref.read(testWorkflowNowProvider)().toUtc();
    setState(() => _nowUtc = now);
    final session = _visibleSession;
    if (session != null &&
        session.stage == ActiveTestStage.timerRunning.name &&
        session.timerEndsAt != null &&
        !session.timerEndsAt!.isAfter(now) &&
        !_completingElapsed &&
        _elapsedAttempt != (id: session.id, endsAt: session.timerEndsAt!)) {
      _elapsedAttempt = (id: session.id, endsAt: session.timerEndsAt!);
      _ticker?.cancel();
      _ticker = null;
      unawaited(_completeElapsed(session));
    }
  }

  Future<void> _completeElapsed(ActiveTestSession session) async {
    _completingElapsed = true;
    try {
      await ref.read(testWorkflowControllerProvider).completeElapsed(session);
    } catch (error) {
      if (mounted) _showMessage('无法完成计时：$error');
    } finally {
      _completingElapsed = false;
      if (mounted) _syncTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialSessionId = widget.initialSessionId?.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('完整检测'),
        actions: [
          if (_visibleSession != null)
            IconButton(
              tooltip: '放弃并删除草稿',
              onPressed: _busy ? null : () => _confirmDiscard(_visibleSession!),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: initialSessionId != null && initialSessionId.isNotEmpty
          ? ref
                .watch(activeTestSessionByIdProvider(initialSessionId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法恢复检测草稿：$error'),
                  data: (session) {
                    if (session == null) {
                      _setVisibleSession(null);
                      return const AppErrorView(message: '该检测草稿已保存、已放弃或不存在。');
                    }
                    return _buildResolvedSession(session);
                  },
                )
          : _buildNewOrScopedDraft(),
    );
  }

  Widget _buildNewOrScopedDraft() {
    return ref
        .watch(activeTanksProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取海缸：$error'),
          data: (tanks) {
            if (tanks.isEmpty) {
              _setVisibleSession(null);
              return const AppErrorView(message: '请先在设置中创建海缸。');
            }
            return ref
                .watch(currentTankProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取当前海缸：$error'),
                  data: (currentTank) {
                    final selectedTankId =
                        tanks.any((tank) => tank.id == _selectedTankId)
                        ? _selectedTankId!
                        : currentTank?.id ?? tanks.first.id;
                    return ref
                        .watch(enabledParametersProvider(selectedTankId))
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              AppErrorView(message: '无法读取已启用参数：$error'),
                          data: (parameters) {
                            if (parameters.isEmpty) {
                              _setVisibleSession(null);
                              return const AppErrorView(
                                message: '当前海缸没有已启用的检测参数。',
                              );
                            }
                            final selectedParameterId =
                                parameters.any(
                                  (item) => item.id == _selectedParameterId,
                                )
                                ? _selectedParameterId!
                                : parameters.first.id;
                            final parameter = parameters.firstWhere(
                              (item) => item.id == selectedParameterId,
                            );
                            final scope = (
                              tankId: selectedTankId,
                              parameterId: selectedParameterId,
                            );
                            return ref
                                .watch(activeTestDraftProvider(scope))
                                .when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (error, _) =>
                                      AppErrorView(message: '无法读取检测草稿：$error'),
                                  data: (session) {
                                    if (session != null) {
                                      return _buildSession(
                                        session: session,
                                        tankName: tanks
                                            .firstWhere(
                                              (tank) =>
                                                  tank.id == selectedTankId,
                                            )
                                            .name,
                                        parameter: parameter,
                                      );
                                    }
                                    _setVisibleSession(null);
                                    return _buildSetup(
                                      tanks: tanks,
                                      tankId: selectedTankId,
                                      parameters: parameters,
                                      parameter: parameter,
                                    );
                                  },
                                );
                          },
                        );
                  },
                );
          },
        );
  }

  Widget _buildResolvedSession(ActiveTestSession session) {
    return ref
        .watch(parameterStatesProvider(session.tankId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取草稿参数：$error'),
          data: (states) {
            final matches = states.where(
              (state) => state.parameter.id == session.parameterId,
            );
            if (matches.isEmpty) {
              _setVisibleSession(session);
              return const AppErrorView(message: '草稿关联的检测参数已不存在。');
            }
            return ref
                .watch(activeTanksProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取海缸：$error'),
                  data: (tanks) {
                    final tankName = tanks
                        .where((tank) => tank.id == session.tankId)
                        .map((tank) => tank.name)
                        .firstOrNull;
                    return _buildSession(
                      session: session,
                      tankName: tankName ?? '已归档海缸',
                      parameter: matches.first.parameter,
                    );
                  },
                );
          },
        );
  }

  Widget _buildSetup({
    required List<Tank> tanks,
    required String tankId,
    required List<WaterParameter> parameters,
    required WaterParameter parameter,
  }) {
    final scope = (tankId: tankId, parameterId: parameter.id);
    final defaultSeconds = ref.watch(testTimerDefaultProvider(scope));
    final reagents = ref.watch(reagentProfilesProvider(parameter.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('选择检测项', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: Key('workflow-tank-$tankId'),
          initialValue: tankId,
          decoration: const InputDecoration(
            labelText: '海缸',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final tank in tanks)
              DropdownMenuItem(value: tank.id, child: Text(tank.name)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _selectedTankId = value;
                  _selectedParameterId = null;
                  _selectedReagentId = null;
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: Key('workflow-parameter-${parameter.id}'),
          initialValue: parameter.id,
          decoration: const InputDecoration(
            labelText: '参数',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final item in parameters)
              DropdownMenuItem(
                value: item.id,
                child: Text('${item.code} · ${item.displayName}'),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _selectedParameterId = value;
                  _selectedReagentId = null;
                }),
        ),
        const SizedBox(height: 12),
        if (parameter.id == AppDatabase.khId)
          _khPanel(tankId)
        else ...[
          reagents.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('无法读取试剂：$error'),
            data: (items) {
              final enabled = items.where((item) => item.isEnabled).toList();
              final effectiveReagentId = _selectedReagentId == ''
                  ? null
                  : enabled.any((item) => item.id == _selectedReagentId)
                  ? _selectedReagentId
                  : enabled.length == 1
                  ? enabled.first.id
                  : null;
              return DropdownButtonFormField<String>(
                key: Key('workflow-reagent-${effectiveReagentId ?? 'none'}'),
                initialValue: effectiveReagentId ?? '',
                decoration: const InputDecoration(
                  labelText: '试剂资料（可选）',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('不指定试剂'),
                  ),
                  for (final item in enabled)
                    DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        '${item.brand} · ${item.defaultDevelopmentSeconds} 秒',
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _selectedReagentId = value ?? ''),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('默认等待时长', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          defaultSeconds.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('无法读取默认时长：$error'),
            data: (seconds) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final quick in TestTimerSnapshot.quickDurationSeconds)
                      ChoiceChip(
                        label: Text('${quick ~/ 60} 分钟'),
                        selected: seconds == quick,
                        onSelected: _busy
                            ? null
                            : (_) => _setDuration(scope, quick),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.tune, size: 18),
                      label: Text('自定义·${_formatDuration(seconds)}'),
                      onPressed: _busy
                          ? null
                          : () => _chooseCustomDuration(scope, seconds),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('自定义范围为 10 秒至 60 分钟，按海缸和参数分别保存。'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('create-test-draft'),
            onPressed: _busy
                ? null
                : () async {
                    final reagentItems =
                        reagents.value ?? const <ReagentProfile>[];
                    final enabled = reagentItems
                        .where((item) => item.isEnabled)
                        .toList();
                    final reagentId = _selectedReagentId == ''
                        ? null
                        : enabled.any((item) => item.id == _selectedReagentId)
                        ? _selectedReagentId
                        : enabled.length == 1
                        ? enabled.first.id
                        : null;
                    await _createDraft(scope, reagentId);
                  },
            icon: const Icon(Icons.science_outlined),
            label: const Text('创建检测草稿'),
          ),
          const SizedBox(height: 12),
          const Text('返回保留草稿，放弃则删除。'),
        ],
      ],
    );
  }

  Widget _buildSession({
    required ActiveTestSession session,
    required String tankName,
    required WaterParameter parameter,
  }) {
    if (parameter.id == AppDatabase.khId &&
        session.stage != ActiveTestStage.review.name) {
      _setVisibleSession(null);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tankName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _khPanel(session.tankId),
        ],
      );
    }
    _setVisibleSession(session);
    if (session.stage == ActiveTestStage.review.name) {
      _hydrateReview(session);
    } else {
      _hydratedSessionId = null;
    }
    final stage = ActiveTestStage.values.firstWhere(
      (candidate) => candidate.name == session.stage,
      orElse: () => ActiveTestStage.preparation,
    );
    final remaining = _remainingSeconds(session);
    if (stage == ActiveTestStage.timerCompleted &&
        !_busy &&
        const ['NO3', 'PO4'].contains(parameter.code) &&
        _autoPhotoSessionId != session.id) {
      _autoPhotoSessionId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy) _openPhoto(session, parameter);
      });
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tankName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${parameter.code} · ${parameter.displayName} · ${parameter.unit}',
                ),
                const SizedBox(height: 8),
                const Text('可稍后继续'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stage != ActiveTestStage.review)
          _buildTimerCard(session, stage, remaining, parameter),
        if (stage == ActiveTestStage.timerCompleted ||
            stage == ActiveTestStage.photoReady) ...[
          const SizedBox(height: 16),
          _buildResultChoice(session, parameter),
        ],
        if (stage == ActiveTestStage.review) _buildReview(session, parameter),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _khPanel(String tankId) => KhTitrationPanel(
    key: ValueKey('kh-$tankId'),
    tankId: tankId,
    onSaved: () {
      _showMessage('检测记录已保存');
      context.go('/test');
    },
    onCancel: () => context.go('/test'),
    onManual: () async {
      final repository = ref.read(testSessionRepositoryProvider);
      final controller = ref.read(testWorkflowControllerProvider);
      var session = await repository.readDraft(
        tankId: tankId,
        parameterId: AppDatabase.khId,
      );
      if (session == null) {
        final id = await controller.createDraft(
          tankId: tankId,
          parameterId: AppDatabase.khId,
        );
        session = await repository.readDraftById(id);
      }
      if (!mounted || session == null) return;
      await controller.useManualEntry(session);
    },
  );

  Widget _buildTimerCard(
    ActiveTestSession session,
    ActiveTestStage stage,
    int remaining,
    WaterParameter parameter,
  ) {
    final isRunning = stage == ActiveTestStage.timerRunning;
    final isPaused = stage == ActiveTestStage.timerPaused;
    final isCompleted =
        stage == ActiveTestStage.timerCompleted ||
        stage == ActiveTestStage.photoReady;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('显色计时', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: isCompleted ? '计时已完成' : '剩余 ${_formatDuration(remaining)}',
              child: Text(
                isCompleted ? '已完成' : _formatClock(remaining),
                key: const Key('test-timer-countdown'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '本次设定 ${_formatDuration(session.timerDurationSeconds)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (stage == ActiveTestStage.preparation) ...[
              FilledButton.icon(
                key: const Key('start-test-timer'),
                onPressed: _busy
                    ? null
                    : () => _timerAction(
                        () => ref
                            .read(testWorkflowControllerProvider)
                            .start(session),
                        warnIfNotificationUnavailable: true,
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始计时'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('skip-test-timer'),
                onPressed: _busy
                    ? null
                    : () => const ['NO3', 'PO4'].contains(parameter.code)
                          ? _openPhoto(session, parameter)
                          : _useManualEntry(session),
                icon: const Icon(Icons.skip_next_outlined),
                label: Text(
                  const ['NO3', 'PO4'].contains(parameter.code)
                      ? '跳过计时，直接拍照'
                      : '跳过计时，直接录入',
                ),
              ),
            ],
            if (isRunning)
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _timerAction(
                        () => ref
                            .read(testWorkflowControllerProvider)
                            .pause(session),
                      ),
                icon: const Icon(Icons.pause),
                label: const Text('暂停'),
              ),
            if (isPaused)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _timerAction(
                        () => ref
                            .read(testWorkflowControllerProvider)
                            .resume(session),
                        warnIfNotificationUnavailable: true,
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('继续'),
              ),
            if (isRunning || isPaused || isCompleted) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _timerAction(
                        () => ref
                            .read(testWorkflowControllerProvider)
                            .reset(session),
                      ),
                icon: const Icon(Icons.replay),
                label: const Text('重置本次计时'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultChoice(
    ActiveTestSession session,
    WaterParameter parameter,
  ) {
    final photoAllowed =
        parameter.photoSupported &&
        const ['NO3', 'PO4'].contains(parameter.code.trim().toUpperCase());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('记录结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (photoAllowed) ...[
              FilledButton.icon(
                key: const Key('open-photo-flow'),
                onPressed: _busy ? null : () => _openPhoto(session, parameter),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('拍照检测'),
              ),
              const SizedBox(height: 8),
            ] else
              const Text('请手动录入结果。'),
            OutlinedButton.icon(
              key: const Key('use-manual-result'),
              onPressed: _busy ? null : () => _useManualEntry(session),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('手动录入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(ActiveTestSession session, WaterParameter parameter) {
    final estimate = _formatRange(
      session.draftEstimatedMinValue,
      session.draftEstimatedMaxValue,
      parameter.unit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.draftEstimationVersion != null)
          ExpansionTile(
            title: const Text('原始拍照结果 · 仅供参考'),
            children: [
              ListTile(
                title: Text(estimate ?? '范围暂无法给出'),
                subtitle: Text(
                  session.draftEstimatedInterpolation == null
                      ? '插值暂无法给出'
                      : '插值 ${session.draftEstimatedInterpolation!.round()} ${parameter.unit}',
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('修改结果', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('以范围保存'),
                  subtitle: const Text('关闭时保存单值'),
                  value: _rangeResult,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _rangeResult = value;
                            if (!value) _maximumController.clear();
                          });
                          _queueReviewPersistence(session);
                        },
                ),
                TextField(
                  key: const Key('confirmed-minimum'),
                  controller: _minimumController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalFormatter],
                  decoration: InputDecoration(
                    labelText: _rangeResult ? '最小值' : '最终确认值',
                    suffixText: parameter.unit,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _queueReviewPersistence(session),
                ),
                if (_rangeResult) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('confirmed-maximum'),
                    controller: _maximumController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_decimalFormatter],
                    decoration: InputDecoration(
                      labelText: '最大值',
                      suffixText: parameter.unit,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _queueReviewPersistence(session),
                  ),
                ],
                const SizedBox(height: 12),
                if (_rangeResult &&
                    const ['NO3', 'PO4'].contains(parameter.code))
                  TextField(
                    key: const Key('confirmed-interpolation'),
                    controller: _interpolationController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '插值（可选）',
                      suffixText: parameter.unit,
                    ),
                    onChanged: (_) => _queueReviewPersistence(session),
                  ),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _queueReviewPersistence(session),
                ),
                const SizedBox(height: 12),
                Text(
                  '拍摄时间：${_formatDateTime(session.draftCapturedAt)}\n'
                  '确认时间：${_formatDateTime(_confirmedAt)}',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => _chooseConfirmedAt(session),
                    icon: const Icon(Icons.schedule),
                    label: const Text('修改确认时间'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('save-test-workflow'),
                  onPressed: _busy ? null : () => _save(session),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('确认并保存'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setDuration(TestSessionScope scope, int seconds) async {
    await _guarded(() async {
      await ref
          .read(testWorkflowControllerProvider)
          .setDefaultDuration(
            tankId: scope.tankId,
            parameterId: scope.parameterId,
            seconds: seconds,
          );
    });
  }

  Future<void> _chooseCustomDuration(
    TestSessionScope scope,
    int currentSeconds,
  ) async {
    final controller = TextEditingController(text: '$currentSeconds');
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义默认时长'),
        content: TextField(
          key: const Key('custom-duration-seconds'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '秒数',
            helperText: '10–3600 秒',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value == null ||
                  value < TestTimerSnapshot.minimumDurationSeconds ||
                  value > TestTimerSnapshot.maximumDurationSeconds) {
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (seconds != null && mounted) await _setDuration(scope, seconds);
  }

  Future<void> _createDraft(
    TestSessionScope scope,
    String? reagentProfileId,
  ) async {
    await _guarded(() async {
      await ref
          .read(testWorkflowControllerProvider)
          .createDraft(
            tankId: scope.tankId,
            parameterId: scope.parameterId,
            reagentProfileId: reagentProfileId,
          );
    });
  }

  Future<void> _timerAction(
    Future<TestWorkflowOperationResult> Function() operation, {
    bool warnIfNotificationUnavailable = false,
  }) async {
    await _guarded(() async {
      final result = await operation();
      if (warnIfNotificationUnavailable && result.notificationUnavailable) {
        _showMessage(_notificationWarning(result.notificationResult!.status));
      }
    });
  }

  Future<void> _openPhoto(
    ActiveTestSession session,
    WaterParameter parameter,
  ) async {
    if (_busy) return;
    _autoPhotoSessionId = session.id;
    setState(() => _busy = true);
    try {
      await ref.read(testWorkflowControllerProvider).preparePhoto(session);
      if (!mounted) return;
      final location = Uri(
        path: '/photo-capture',
        queryParameters: <String, String>{
          'tankId': session.tankId,
          'parameterId': session.parameterId,
          'parameterCode': parameter.code,
          'parameterName': parameter.displayName,
          'unit': parameter.unit,
        },
      ).toString();
      final result = await context.push<PhotoEstimationDraft>(location);
      if (!mounted) return;
      if (result == null) {
        // Back/cancel keeps the resumable draft at the result-choice stage.
        await ref
            .read(testSessionRepositoryProvider)
            .updateStage(
              tankId: session.tankId,
              sessionId: session.id,
              stage: ActiveTestStage.timerCompleted,
            );
        return;
      }
      await ref
          .read(testWorkflowControllerProvider)
          .applyPhotoDraft(session: session, draft: result);
    } catch (error) {
      if (mounted) _showMessage('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useManualEntry(ActiveTestSession session) async {
    await _guarded(() async {
      await ref.read(testWorkflowControllerProvider).useManualEntry(session);
    });
  }

  void _hydrateReview(ActiveTestSession session) {
    if (_hydratedSessionId == session.id) return;
    _hydratedSessionId = session.id;
    _minimumController.text = _numberInput(session.draftConfirmedMinValue);
    _maximumController.text = _numberInput(session.draftConfirmedMaxValue);
    _interpolationController.text = _numberInput(
      session.draftConfirmedInterpolation == null
          ? null
          : double.parse(
              session.draftConfirmedInterpolation!.toStringAsFixed(3),
            ),
    );
    _notesController.text = session.draftNotes ?? '';
    _rangeResult = session.draftConfirmedMaxValue != null;
    _confirmedAt = session.draftConfirmedAt?.toLocal() ?? DateTime.now();
  }

  void _queueReviewPersistence(ActiveTestSession session) {
    final values = _readReviewValues(requireMinimum: false);
    if (values == null) return;
    final notes = _notesController.text;
    final point = _rangeResult
        ? double.tryParse(_interpolationController.text)
        : null;
    final controller = ref.read(testWorkflowControllerProvider);
    _reviewSaveChain = _reviewSaveChain.then<void>((_) async {
      try {
        await controller.persistReview(
          session: session,
          confirmedMinValue: values.minimum,
          confirmedMaxValue: values.maximum,
          confirmedInterpolation: point,
          confirmedAt: _confirmedAt,
          notes: notes,
        );
      } catch (_) {
        // The explicit save action retries and surfaces persistence errors.
        // Background writes remain non-disruptive while the user is typing.
      }
    });
  }

  Future<void> _save(ActiveTestSession session) async {
    final values = _readReviewValues(requireMinimum: true);
    if (values == null || values.minimum == null) {
      _showMessage('请输入有效的非负最终值，范围上限不得小于下限。');
      return;
    }
    final point = double.tryParse(_interpolationController.text.trim());
    if (_rangeResult &&
        _interpolationController.text.trim().isNotEmpty &&
        (point == null ||
            !point.isFinite ||
            point < values.minimum! ||
            point > values.maximum!)) {
      _showMessage('插值必须在范围内');
      return;
    }
    await _guarded(() async {
      await _reviewSaveChain;
      await ref
          .read(testWorkflowControllerProvider)
          .persistReview(
            session: session,
            confirmedMinValue: values.minimum,
            confirmedMaxValue: values.maximum,
            confirmedInterpolation: _rangeResult
                ? double.tryParse(_interpolationController.text)
                : null,
            confirmedAt: _confirmedAt,
            notes: _notesController.text,
          );
      await ref
          .read(testWorkflowControllerProvider)
          .save(
            session: session,
            confirmedMinValue: values.minimum!,
            confirmedMaxValue: values.maximum,
            confirmedInterpolation: _rangeResult
                ? double.tryParse(_interpolationController.text)
                : null,
            confirmedAt: _confirmedAt,
            notes: _notesController.text,
          );
      if (!mounted) return;
      _showMessage('检测记录已保存');
      context.go('/test');
    });
  }

  Future<void> _confirmDiscard(ActiveTestSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃检测草稿？'),
        content: const Text('未保存的结果将被删除，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃并删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _guarded(() async {
      final photoDeleted = await ref
          .read(testWorkflowControllerProvider)
          .discard(session);
      if (!mounted) return;
      if (!photoDeleted) {
        _showMessage('草稿已删除，但旧版本本地照片清理失败。');
      } else {
        _showMessage('草稿已删除');
      }
      context.go('/test');
    });
  }

  Future<void> _chooseConfirmedAt(ActiveTestSession session) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _confirmedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_confirmedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _confirmedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _queueReviewPersistence(session);
  }

  Future<void> _guarded(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) _showMessage('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ({double? minimum, double? maximum})? _readReviewValues({
    required bool requireMinimum,
  }) {
    final minimumText = _minimumController.text.trim();
    final maximumText = _rangeResult ? _maximumController.text.trim() : '';
    final minimum = minimumText.isEmpty ? null : double.tryParse(minimumText);
    final maximum = maximumText.isEmpty ? null : double.tryParse(maximumText);
    if ((requireMinimum && minimum == null) ||
        (minimumText.isNotEmpty && minimum == null) ||
        (maximumText.isNotEmpty && maximum == null) ||
        (minimum != null && (!minimum.isFinite || minimum < 0)) ||
        (maximum != null &&
            (!maximum.isFinite ||
                maximum < 0 ||
                minimum == null ||
                maximum < minimum))) {
      return null;
    }
    return (minimum: minimum, maximum: maximum);
  }

  int _remainingSeconds(ActiveTestSession session) {
    if (session.stage == ActiveTestStage.timerPaused.name) {
      return session.pausedRemainingSeconds ?? 0;
    }
    if (session.stage == ActiveTestStage.timerRunning.name) {
      final end = session.timerEndsAt;
      if (end == null) return 0;
      final milliseconds = end.difference(_nowUtc).inMilliseconds;
      return milliseconds <= 0
          ? 0
          : (milliseconds / Duration.millisecondsPerSecond).ceil();
    }
    if (session.stage == ActiveTestStage.preparation.name) {
      return session.timerDurationSeconds;
    }
    return 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*(?:\.\d*)?$'),
);

String _formatClock(int seconds) {
  final safe = seconds
      .clamp(0, TestTimerSnapshot.maximumDurationSeconds)
      .toInt();
  final minutes = safe ~/ 60;
  final remainder = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '$seconds 秒';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0 ? '$minutes 分钟' : '$minutes 分 $remainder 秒';
}

String _numberInput(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String? _formatRange(double? minimum, double? maximum, String unit) {
  if (minimum == null) return null;
  final minimumText = _numberInput(minimum);
  if (maximum == null || maximum == minimum) return '$minimumText $unit';
  return '$minimumText–${_numberInput(maximum)} $unit';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '无';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _notificationWarning(NotificationOperationStatus status) {
  return switch (status) {
    NotificationOperationStatus.permissionDenied =>
      '计时已开始，但通知权限未授予；请在 App 内查看倒计时。',
    NotificationOperationStatus.unsupported => '计时已开始，但当前平台不支持本地通知。',
    NotificationOperationStatus.unavailable => '计时已开始，但本地通知暂不可用。',
    NotificationOperationStatus.invalidRequest ||
    NotificationOperationStatus.failed => '计时已开始，但本次结束通知安排失败。',
    NotificationOperationStatus.succeeded => '',
  };
}
