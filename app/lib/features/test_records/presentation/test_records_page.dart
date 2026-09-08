import '../../trends/data/record_history_source.dart';
import '../../trends/presentation/database_record_history_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_view.dart';
import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../application/record_form_draft.dart';
import '../application/test_record_providers.dart';

class TestRecordsPage extends ConsumerWidget {
  const TestRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentTankProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取当前海缸：$error'),
          data: (tank) {
            if (tank == null) return const AppErrorView(message: '请先在设置中创建海缸。');
            return ref
                .watch(enabledParametersProvider(tank.id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取检测参数：$error'),
                  data: (enabled) => ref
                      .watch(parameterStatesProvider(tank.id))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            AppErrorView(message: '无法读取参数资料：$error'),
                        data: (states) => ref
                            .watch(
                              recordHistoryOverviewProvider((
                                tankId: tank.id,
                                parameterId: null,
                              )),
                            )
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, _) =>
                                  AppErrorView(message: '无法读取检测历史：$error'),
                              data: (overview) => ref
                                  .watch(waterQualityTargetsProvider(tank.id))
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (error, _) => AppErrorView(
                                      message: '无法读取目标范围：$error',
                                    ),
                                    data: (targets) => _Content(
                                      tank: tank,
                                      enabledParameters: enabled,
                                      allParameters: {
                                        for (final state in states)
                                          state.parameter.id: state.parameter,
                                      },
                                      overview: overview,
                                      targets: targets,
                                    ),
                                  ),
                            ),
                      ),
                );
          },
        );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.tank,
    required this.enabledParameters,
    required this.allParameters,
    required this.overview,
    required this.targets,
  });

  final Tank tank;
  final List<WaterParameter> enabledParameters;
  final Map<String, WaterParameter> allParameters;
  final RecordHistoryOverview overview;
  final List<WaterQualityTarget> targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetByParameter = {
      for (final target in targets) target.parameterId: target,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '当前海缸：${tank.name}',
                  key: const Key('test-current-tank'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),

                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('start-test-flow'),
                  onPressed: enabledParameters.isEmpty
                      ? null
                      : () => context.push('/test-flow'),
                  icon: const Icon(Icons.science),
                  label: const Text('开始完整检测'),
                ),
                const SizedBox(height: 8),
                if (enabledParameters.any(
                  (parameter) => parameter.id == AppDatabase.khId,
                ))
                  OutlinedButton.icon(
                    key: const Key('start-kh-titration'),
                    onPressed: () => context.push(
                      '/test-flow?parameterId=${AppDatabase.khId}',
                    ),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('KH 滴定检测'),
                  ),
                OutlinedButton.icon(
                  key: const Key('add-test-record'),
                  onPressed: enabledParameters.isEmpty
                      ? null
                      : () => _createRecord(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('添加手动检测记录'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('目标范围', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < enabledParameters.length; index++)
                Builder(
                  builder: (context) {
                    final parameter = enabledParameters[index];
                    final target = targetByParameter[parameter.id];
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${parameter.code} · ${parameter.displayName}',
                          ),
                          subtitle: Text(
                            target == null ||
                                    (target.minValue == null &&
                                        target.maxValue == null)
                                ? '尚未设置 · ${parameter.unit}'
                                : '${_targetNumber(target.minValue)}–${_targetNumber(target.maxValue)} ${target.unit}',
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () =>
                              _editTarget(context, ref, parameter, target),
                        ),
                        if (index < enabledParameters.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('检测历史', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (overview.count == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 40),
                  SizedBox(height: 8),
                  Text('还没有检测记录'),
                  SizedBox(height: 4),
                  Text('添加第一条手动检测结果后会显示在这里。'),
                ],
              ),
            ),
          )
        else
          DatabaseRecordHistory(
            key: ValueKey('records-${tank.id}'),
            scope: (tankId: tank.id, parameterId: null),
            overview: overview,
            onOpen: (record) => _openRecord(
              context,
              ref,
              record,
              allParameters[record.parameterId],
            ),
            rowBuilder: (record) => _RecordTile(
              record: record,
              parameter: allParameters[record.parameterId],
              showDivider: true,
              onTap: () => _openRecord(
                context,
                ref,
                record,
                allParameters[record.parameterId],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _createRecord(BuildContext context, WidgetRef ref) async {
    final key = 'new:${tank.id}';
    var initial = ref.read(recordFormDraftProvider(key));
    final enabledIds = enabledParameters.map((item) => item.id).toSet();
    if (initial == null ||
        initial.tankId != tank.id ||
        !enabledIds.contains(initial.parameterId)) {
      initial = RecordFormDraft(
        tankId: tank.id,
        parameterId: enabledParameters.first.id,
        reagentProfileId: null,
        isRange: false,
        minValueText: '',
        maxValueText: '',
        confirmedAt: DateTime.now().toUtc(),
        notes: '',
      );
      ref.read(recordFormDraftProvider(key).notifier).state = initial;
    }
    final draft = await showDialog<RecordFormDraft>(
      context: context,
      builder: (_) => _RecordEditorDialog(
        draftKey: key,
        initialDraft: initial!,
        sourceTank: tank,
        createParameters: enabledParameters,
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref
          .read(testRecordRepositoryProvider)
          .createManual(
            tankId: tank.id,
            parameterId: draft.parameterId,
            reagentProfileId: draft.reagentProfileId,
            confirmedMinValue: double.parse(draft.minValueText.trim()),
            confirmedMaxValue: draft.isRange
                ? double.parse(draft.maxValueText.trim())
                : null,
            confirmedInterpolation: draft.isRange
                ? double.tryParse(draft.interpolationText)
                : null,
            measuredAt: draft.confirmedAt,
            notes: draft.notes,
          );
      ref.read(recordFormDraftProvider(key).notifier).state = null;
      if (context.mounted) _message(context, '检测记录已保存');
    } catch (error) {
      if (context.mounted) _message(context, '保存失败，草稿仍保留：$error');
    }
  }

  Future<void> _openRecord(
    BuildContext context,
    WidgetRef ref,
    TestRecord record,
    WaterParameter? parameter,
  ) async {
    if (parameter == null) {
      _message(context, '参数资料已不可用，无法打开记录');
      return;
    }
    await showScopedTestRecordDetails(
      context: context,
      ref: ref,
      record: record,
      tank: tank,
      parameter: parameter,
    );
  }

  Future<void> _editTarget(
    BuildContext context,
    WidgetRef ref,
    WaterParameter parameter,
    WaterQualityTarget? target,
  ) async {
    final range = await _showTargetDialog(context, parameter, target);
    if (range == null || !context.mounted) return;
    try {
      await ref
          .read(tankRepositoryProvider)
          .setTarget(
            tankId: tank.id,
            parameterId: parameter.id,
            minValue: range.$1,
            maxValue: range.$2,
          );
      if (context.mounted) _message(context, '目标范围已保存');
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }
}

/// Opens one record only after resolving it through the supplied tank scope.
///
/// Both the detection history and trend history use this entry point so a
/// stale list item can never fall back to an id-only lookup in another tank.
Future<void> showScopedTestRecordDetails({
  required BuildContext context,
  required WidgetRef ref,
  required TestRecord record,
  required Tank tank,
  required WaterParameter parameter,
}) async {
  TestRecord? scopedRecord;
  try {
    scopedRecord = await ref.read(
      testRecordProvider((tankId: tank.id, recordId: record.id)).future,
    );
  } catch (error) {
    if (context.mounted) _message(context, '无法读取检测记录：$error');
    return;
  }
  if (!context.mounted) return;
  if (scopedRecord == null || scopedRecord.parameterId != parameter.id) {
    _message(context, '记录已不在当前海缸，无法打开');
    return;
  }

  final action = await _showRecordDetailsDialog(
    context,
    record: scopedRecord,
    tank: tank,
    parameter: parameter,
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _RecordDetailsAction.edit:
      await _editScopedRecord(context, ref, tank, scopedRecord);
      return;
    case _RecordDetailsAction.clearPhoto:
      final confirmed = await _confirm(
        context,
        title: '删除旧版本留档照片？',
        message: '检测数值、算法元数据和备注会保留；旧版本照片文件将从本机删除。',
        confirmLabel: '删除照片',
      );
      if (!confirmed || !context.mounted) return;
      await _clearScopedRecordPhoto(context, ref, scopedRecord);
      return;
    case _RecordDetailsAction.delete:
      final confirmed = await _confirm(
        context,
        title: '永久删除这条记录？',
        message: '检测数值与可能存在的旧版本照片都会删除，此操作无法撤销。',
        confirmLabel: '删除记录',
      );
      if (!confirmed || !context.mounted) return;
      await _deleteScopedRecord(context, ref, scopedRecord);
      return;
  }
}

Future<void> _editScopedRecord(
  BuildContext context,
  WidgetRef ref,
  Tank sourceTank,
  TestRecord record,
) async {
  final key = 'edit:${record.id}';
  var initial = ref.read(recordFormDraftProvider(key));
  initial ??= RecordFormDraft(
    tankId: record.tankId,
    parameterId: record.parameterId,
    reagentProfileId: record.reagentProfileId,
    isRange: record.confirmedMaxValue != null,
    minValueText: _number(record.confirmedMinValue),
    maxValueText: record.confirmedMaxValue == null
        ? ''
        : _number(record.confirmedMaxValue!),
    confirmedAt: (record.confirmedAt ?? record.measuredAt).toUtc(),
    notes: record.notes ?? '',
    interpolationText: record.confirmedInterpolation?.toString() ?? '',
  );
  ref.read(recordFormDraftProvider(key).notifier).state = initial;
  final draft = await showDialog<RecordFormDraft>(
    context: context,
    builder: (_) => _RecordEditorDialog(
      draftKey: key,
      initialDraft: initial!,
      sourceTank: sourceTank,
      createParameters: const [],
      record: record,
    ),
  );
  if (draft == null || !context.mounted) return;
  try {
    await ref
        .read(testRecordRepositoryProvider)
        .editRecord(
          id: record.id,
          sourceTankId: record.tankId,
          targetTankId: draft.tankId,
          parameterId: draft.parameterId,
          reagentProfileId: draft.reagentProfileId,
          confirmedMinValue: double.parse(draft.minValueText.trim()),
          confirmedMaxValue: draft.isRange
              ? double.parse(draft.maxValueText.trim())
              : null,
          confirmedInterpolation: draft.isRange
              ? double.tryParse(draft.interpolationText)
              : null,
          confirmedAt: draft.confirmedAt,
          notes: draft.notes,
        );
    ref.read(recordFormDraftProvider(key).notifier).state = null;
    if (context.mounted) _message(context, '检测记录已更新');
  } catch (error) {
    if (context.mounted) _message(context, '更新失败，草稿仍保留：$error');
  }
}

Future<void> _clearScopedRecordPhoto(
  BuildContext context,
  WidgetRef ref,
  TestRecord record,
) async {
  try {
    await ref
        .read(testRecordRepositoryProvider)
        .clearPhoto(id: record.id, tankId: record.tankId);
    var fileDeleted = false;
    try {
      fileDeleted = await ref
          .read(localPhotoStorageProvider)
          .deletePrivatePhoto(record.photoPath);
    } catch (_) {
      // The database association is already cleared. Report the orphaned
      // file without pretending the numeric record was rolled back.
    }
    if (!context.mounted) return;
    _message(
      context,
      fileDeleted ? '照片已删除，检测数值已保留' : '数值已保留并解除照片关联，但照片文件删除失败，请检查本机存储',
    );
  } catch (error) {
    if (context.mounted) _message(context, '无法解除照片与记录的关联：$error');
  }
}

Future<void> _deleteScopedRecord(
  BuildContext context,
  WidgetRef ref,
  TestRecord record,
) async {
  try {
    final deleted = await ref
        .read(testRecordRepositoryProvider)
        .deleteRecord(id: record.id, tankId: record.tankId);
    ref.read(recordFormDraftProvider('edit:${record.id}').notifier).state =
        null;
    var fileDeleted = false;
    try {
      fileDeleted = await ref
          .read(localPhotoStorageProvider)
          .deletePrivatePhoto(deleted.photoPath);
    } catch (_) {
      // The row is already deleted. A remaining private file is reported to
      // the user and can be cleaned by a later storage-maintenance pass.
    }
    if (!context.mounted) return;
    _message(context, fileDeleted ? '检测记录已删除' : '记录已删除，但照片文件清理失败，请检查本机存储');
  } catch (error) {
    if (context.mounted) _message(context, '删除记录失败：$error');
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.parameter,
    required this.showDivider,
    required this.onTap,
  });

  final TestRecord record;
  final WaterParameter? parameter;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = _confirmedValue(record);
    return Column(
      children: [
        ListTile(
          key: Key('record-${record.id}'),
          title: Text('${parameter?.code ?? '未知参数'}  $value ${record.unit}'),
          subtitle: Text(
            _dateTime(record.confirmedAt ?? record.measuredAt).substring(0, 10),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

enum _RecordDetailsAction { edit, clearPhoto, delete }

Future<_RecordDetailsAction?> _showRecordDetailsDialog(
  BuildContext context, {
  required TestRecord record,
  required Tank tank,
  required WaterParameter parameter,
}) {
  return showDialog<_RecordDetailsAction>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final reagents = ref.watch(reagentProfilesProvider(record.parameterId));
        return AlertDialog(
          title: Text('${parameter.code} 检测详情'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailRow(label: '所属海缸', value: tank.name),
                  _DetailRow(
                    label: '最终确认结果',
                    value: _confirmedValue(record),
                    emphasized: true,
                  ),
                  _DetailRow(label: '单位', value: record.unit),
                  _DetailRow(
                    label: '检测时间',
                    value: _dateTime(record.confirmedAt ?? record.measuredAt),
                  ),
                  _DetailRow(
                    label: '试剂配置',
                    value: reagents.when(
                      loading: () => '读取中…',
                      error: (_, _) => '读取失败',
                      data: (items) =>
                          items
                              .where(
                                (item) => item.id == record.reagentProfileId,
                              )
                              .map(
                                (item) =>
                                    '${item.brand}${item.cardVersion == null ? '' : ' · ${item.cardVersion}'}${item.isEnabled ? '' : '（已停用）'}',
                              )
                              .firstOrNull ??
                          '未选择',
                    ),
                  ),
                  _DetailRow(label: '备注', value: record.notes ?? '无'),
                  const Divider(height: 28),
                  Text(
                    '算法原始结果（只读）',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(label: '算法原始估值', value: _estimatedValue(record)),
                  _DetailRow(
                    label: '原始拍摄时间',
                    value: record.capturedAt == null
                        ? '无拍摄记录'
                        : _dateTime(record.capturedAt!),
                  ),
                  _DetailRow(label: '置信度', value: record.confidence ?? '未提供'),
                  _DetailRow(
                    label: '图像质量分',
                    value: record.qualityScore == null
                        ? '未提供'
                        : _number(record.qualityScore!),
                  ),
                  _DetailRow(
                    label: '估值方法',
                    value:
                        [
                          record.estimationMethod,
                          record.estimationVersion,
                        ].whereType<String>().join(' · ').trim().isEmpty
                        ? '未提供'
                        : [
                            record.estimationMethod,
                            record.estimationVersion,
                          ].whereType<String>().join(' · '),
                  ),
                  if (record.failureReason != null)
                    _DetailRow(label: '估值失败原因', value: record.failureReason!),
                  const Divider(height: 28),
                  _DetailRow(
                    label: '编辑状态',
                    value: record.wasManuallyEdited ? '已手动修改' : '尚未手动修改',
                  ),
                  _DetailRow(
                    label: '最后修改时间',
                    value: _dateTime(record.updatedAt),
                  ),
                  _DetailRow(
                    label: '旧版本本机照片',
                    value: record.photoPath == null ? '无' : '旧版本曾保存（应用私有目录）',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
            if (record.photoPath != null)
              TextButton(
                key: const Key('clear-record-photo'),
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _RecordDetailsAction.clearPhoto,
                ),
                child: const Text('删除照片'),
              ),
            TextButton(
              key: const Key('delete-test-record'),
              onPressed: () =>
                  Navigator.pop(dialogContext, _RecordDetailsAction.delete),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除记录'),
            ),
            FilledButton(
              key: const Key('edit-test-record'),
              onPressed: () =>
                  Navigator.pop(dialogContext, _RecordDetailsAction.edit),
              child: const Text('编辑检测记录'),
            ),
          ],
        );
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: emphasized
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordEditorDialog extends ConsumerStatefulWidget {
  const _RecordEditorDialog({
    required this.draftKey,
    required this.initialDraft,
    required this.sourceTank,
    required this.createParameters,
    this.record,
  });

  final String draftKey;
  final RecordFormDraft initialDraft;
  final Tank sourceTank;
  final List<WaterParameter> createParameters;
  final TestRecord? record;

  bool get isEditing => record != null;

  @override
  ConsumerState<_RecordEditorDialog> createState() =>
      _RecordEditorDialogState();
}

class _RecordEditorDialogState extends ConsumerState<_RecordEditorDialog> {
  late RecordFormDraft _draft;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _notesController;
  String? _errorText;
  bool _changingTank = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _minController = TextEditingController(text: _draft.minValueText);
    _maxController = TextEditingController(text: _draft.maxValueText);
    _notesController = TextEditingController(text: _draft.notes);
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _update(RecordFormDraft value, {bool rebuild = true}) {
    if (rebuild) {
      setState(() {
        _draft = value;
        _errorText = null;
      });
    } else {
      _draft = value;
    }
    ref.read(recordFormDraftProvider(widget.draftKey).notifier).state = value;
  }

  Future<void> _changeTank(String tankId) async {
    setState(() {
      _changingTank = true;
      _errorText = null;
    });
    try {
      final states = await ref
          .read(tankRepositoryProvider)
          .readParameterStates(tankId);
      final associated = states.where((item) => item.isAssociated).toList();
      if (associated.isEmpty) throw StateError('目标海缸没有可用的历史参数关联');
      final parameterId =
          associated.any((item) => item.parameter.id == _draft.parameterId)
          ? _draft.parameterId
          : associated.first.parameter.id;
      if (!mounted) return;
      _update(
        _draft.copyWith(
          tankId: tankId,
          parameterId: parameterId,
          reagentProfileId: parameterId == _draft.parameterId
              ? _draft.reagentProfileId
              : null,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _errorText = '切换海缸失败：$error');
    } finally {
      if (mounted) setState(() => _changingTank = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return _withParameters(
        context,
        tanks: [widget.sourceTank],
        options: [
          for (final parameter in widget.createParameters)
            _ParameterOption(parameter: parameter, isEnabled: true),
        ],
      );
    }
    return ref
        .watch(activeTanksProvider)
        .when(
          loading: () => _loadingDialog(context, '正在读取海缸…'),
          error: (error, _) => _errorDialog(context, '无法读取活动海缸：$error'),
          data: (tanks) {
            if (!tanks.any((item) => item.id == _draft.tankId)) {
              return _errorDialog(context, '草稿中的目标海缸已归档，请放弃草稿后重试。');
            }
            return ref
                .watch(parameterStatesProvider(_draft.tankId))
                .when(
                  loading: () => _loadingDialog(context, '正在读取目标海缸参数…'),
                  error: (error, _) =>
                      _errorDialog(context, '无法读取目标海缸参数：$error'),
                  data: (states) => _withParameters(
                    context,
                    tanks: tanks,
                    options: [
                      for (final state in states)
                        if (state.isAssociated)
                          _ParameterOption(
                            parameter: state.parameter,
                            isEnabled: state.isEnabled,
                          ),
                    ],
                  ),
                );
          },
        );
  }

  Widget _withParameters(
    BuildContext context, {
    required List<Tank> tanks,
    required List<_ParameterOption> options,
  }) {
    if (options.isEmpty ||
        !options.any((item) => item.parameter.id == _draft.parameterId)) {
      return _errorDialog(context, '此海缸没有可用于当前表单的参数。');
    }
    final AsyncValue<List<ReagentProfile>> reagentState = widget.isEditing
        ? ref.watch(reagentProfilesProvider(_draft.parameterId))
        : ref.watch(enabledReagentProfilesProvider(_draft.parameterId));
    return reagentState.when(
      loading: () => _loadingDialog(context, '正在读取试剂配置…'),
      error: (error, _) => _errorDialog(context, '无法读取试剂配置：$error'),
      data: (reagents) => _loadedDialog(
        context,
        tanks: tanks,
        options: options,
        reagents: reagents,
      ),
    );
  }

  AlertDialog _loadedDialog(
    BuildContext context, {
    required List<Tank> tanks,
    required List<_ParameterOption> options,
    required List<ReagentProfile> reagents,
  }) {
    final parameter = options
        .firstWhere((item) => item.parameter.id == _draft.parameterId)
        .parameter;
    final selectedReagent =
        reagents.any((item) => item.id == _draft.reagentProfileId)
        ? _draft.reagentProfileId
        : null;
    return AlertDialog(
      title: Text(widget.isEditing ? '编辑检测记录' : '添加手动检测'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEditing)
                DropdownButtonFormField<String>(
                  key: Key('record-tank-${_draft.tankId}'),
                  initialValue: _draft.tankId,
                  decoration: const InputDecoration(labelText: '所属海缸'),
                  items: [
                    for (final item in tanks)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: _changingTank
                      ? null
                      : (value) {
                          if (value != null && value != _draft.tankId) {
                            _changeTank(value);
                          }
                        },
                )
              else
                InputDecorator(
                  key: const Key('record-fixed-current-tank'),
                  decoration: const InputDecoration(labelText: '所属海缸（当前）'),
                  child: Text(widget.sourceTank.name),
                ),
              if (_changingTank) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: Key('record-parameter-${_draft.parameterId}'),
                initialValue: _draft.parameterId,
                decoration: const InputDecoration(labelText: '检测参数'),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.parameter.id,
                      child: Text(
                        '${option.parameter.code} · ${option.parameter.unit}'
                        '${option.isEnabled ? '' : '（已停用，历史可编辑）'}',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null || value == _draft.parameterId) return;
                  _update(
                    _draft.copyWith(parameterId: value, reagentProfileId: null),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: Key('record-reagent-${parameter.code.toLowerCase()}'),
                initialValue: selectedReagent ?? '',
                decoration: const InputDecoration(labelText: '试剂配置（可选）'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('未选择试剂')),
                  for (final reagent in reagents)
                    DropdownMenuItem(
                      value: reagent.id,
                      child: Text(
                        '${reagent.brand}${reagent.cardVersion == null ? '' : ' · ${reagent.cardVersion}'}'
                        '${reagent.isEnabled ? '' : '（已停用）'}',
                      ),
                    ),
                ],
                onChanged: (value) => _update(
                  _draft.copyWith(
                    reagentProfileId: value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
              ),
              if (reagents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('此参数没有可选试剂，可继续手动录入。'),
                ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('单值')),
                  ButtonSegment(value: true, label: Text('范围')),
                ],
                selected: {_draft.isRange},
                onSelectionChanged: (value) {
                  final range = value.single;
                  if (!range) _maxController.clear();
                  _update(
                    _draft.copyWith(
                      isRange: range,
                      maxValueText: range ? _maxController.text : '',
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('record-min-value'),
                controller: _minController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _draft.isRange ? '最终确认下限' : '最终确认值',
                  suffixText: parameter.unit,
                ),
                onChanged: (value) => _update(
                  _draft.copyWith(minValueText: value),
                  rebuild: false,
                ),
              ),
              if (_draft.isRange) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('record-max-value'),
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '最终确认上限',
                    suffixText: parameter.unit,
                  ),
                  onChanged: (value) => _update(
                    _draft.copyWith(maxValueText: value),
                    rebuild: false,
                  ),
                ),
              ],
              if (_draft.isRange &&
                  const ['NO3', 'PO4'].contains(parameter.code))
                TextFormField(
                  key: const Key('record-interpolation'),
                  initialValue: _draft.interpolationText,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '插值（可选）',
                    suffixText: parameter.unit,
                  ),
                  onChanged: (value) => _update(
                    _draft.copyWith(interpolationText: value),
                    rebuild: false,
                  ),
                ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('record-confirmed-at'),
                contentPadding: EdgeInsets.zero,
                title: const Text('检测时间'),
                subtitle: Text('最终确认：${_dateTime(_draft.confirmedAt)}'),
                trailing: const Icon(Icons.schedule),
                onTap: _pickConfirmedAt,
              ),
              TextField(
                key: const Key('record-notes'),
                controller: _notesController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '备注（可选）'),
                onChanged: (value) =>
                    _update(_draft.copyWith(notes: value), rebuild: false),
              ),
              if (widget.record != null) ...[
                const SizedBox(height: 8),
                _AlgorithmReadOnlyCard(record: widget.record!),
              ],
              const SizedBox(height: 8),

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _actions(context, reagents),
    );
  }

  List<Widget> _actions(
    BuildContext context, [
    List<ReagentProfile> reagents = const [],
  ]) {
    return [
      TextButton(
        key: const Key('record-discard-draft'),
        onPressed: () async {
          final discard = await _confirm(
            context,
            title: '放弃这个草稿？',
            message: '尚未保存的输入会被清除，此操作无法撤销。',
            confirmLabel: '放弃草稿',
          );
          if (!discard || !context.mounted) return;
          ref.read(recordFormDraftProvider(widget.draftKey).notifier).state =
              null;
          Navigator.pop(context);
        },
        child: const Text('放弃草稿'),
      ),
      TextButton(
        key: const Key('record-keep-draft'),
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('save-test-record'),
        onPressed: reagents.isEmpty && _draft.reagentProfileId != null
            ? null
            : () => _save(context, reagents),
        child: const Text('保存'),
      ),
    ];
  }

  AlertDialog _loadingDialog(BuildContext context, String message) {
    return AlertDialog(
      title: Text(widget.isEditing ? '编辑检测记录' : '添加手动检测'),
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
      actions: _actions(context),
    );
  }

  AlertDialog _errorDialog(BuildContext context, String message) {
    return AlertDialog(
      title: Text(widget.isEditing ? '编辑检测记录' : '添加手动检测'),
      content: Text(message),
      actions: _actions(context),
    );
  }

  Future<void> _pickConfirmedAt() async {
    final local = _draft.confirmedAt.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;
    _update(
      _draft.copyWith(
        confirmedAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      ),
    );
  }

  void _save(BuildContext context, List<ReagentProfile> reagents) {
    final min = double.tryParse(_minController.text.trim());
    final max = _draft.isRange
        ? double.tryParse(_maxController.text.trim())
        : null;
    if (min == null ||
        !min.isFinite ||
        min < 0 ||
        (_draft.isRange && (max == null || !max.isFinite || max < min))) {
      setState(() => _errorText = '请输入有效的非负数，且上限不能小于下限');
      return;
    }
    final point = double.tryParse(_draft.interpolationText.trim());
    if (_draft.isRange &&
        _draft.interpolationText.trim().isNotEmpty &&
        (point == null || !point.isFinite || point < min || point > max!)) {
      setState(() => _errorText = '插值必须在范围内');
      return;
    }
    final reagentId = reagents.any((item) => item.id == _draft.reagentProfileId)
        ? _draft.reagentProfileId
        : null;
    final result = _draft.copyWith(
      reagentProfileId: reagentId,
      minValueText: _minController.text,
      maxValueText: _draft.isRange ? _maxController.text : '',
      notes: _notesController.text,
    );
    _update(result, rebuild: false);
    Navigator.pop(context, result);
  }
}

class _AlgorithmReadOnlyCard extends StatelessWidget {
  const _AlgorithmReadOnlyCard({required this.record});

  final TestRecord record;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 6),
                Text('算法与拍摄原始信息（只读）'),
              ],
            ),
            const SizedBox(height: 8),
            Text('算法原始估值：${_estimatedValue(record)}'),
            Text(
              '原始拍摄时间：${record.capturedAt == null ? '无拍摄记录' : _dateTime(record.capturedAt!)}',
            ),
            Text('置信度：${record.confidence ?? '未提供'}'),
            const SizedBox(height: 4),
            const Text('这些字段不会被本次人工编辑覆盖。'),
          ],
        ),
      ),
    );
  }
}

class _ParameterOption {
  const _ParameterOption({required this.parameter, required this.isEnabled});

  final WaterParameter parameter;
  final bool isEnabled;
}

Future<(double?, double?)?> _showTargetDialog(
  BuildContext context,
  WaterParameter parameter,
  WaterQualityTarget? target,
) {
  return showDialog<(double?, double?)>(
    context: context,
    builder: (_) => _TargetRangeDialog(parameter: parameter, target: target),
  );
}

class _TargetRangeDialog extends StatefulWidget {
  const _TargetRangeDialog({required this.parameter, required this.target});

  final WaterParameter parameter;
  final WaterQualityTarget? target;

  @override
  State<_TargetRangeDialog> createState() => _TargetRangeDialogState();
}

class _TargetRangeDialogState extends State<_TargetRangeDialog> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final target = widget.target;
    _minController = TextEditingController(
      text: target?.minValue?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: target?.maxValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _submit() {
    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());
    if ((_minController.text.trim().isNotEmpty && min == null) ||
        (_maxController.text.trim().isNotEmpty && max == null) ||
        (min != null && (!min.isFinite || min < 0)) ||
        (max != null && (!max.isFinite || max < 0)) ||
        (min != null && max != null && max < min)) {
      setState(() => _errorText = '请输入有效的非负范围');
      return;
    }
    Navigator.pop(context, (min, max));
  }

  @override
  Widget build(BuildContext context) {
    final parameter = widget.parameter;
    return AlertDialog(
      title: Text('${parameter.code} 目标范围'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('target-min-value'),
            controller: _minController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '下限',
              suffixText: parameter.unit,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('target-max-value'),
            controller: _maxController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '上限',
              suffixText: parameter.unit,
            ),
          ),
          if (_errorText != null)
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('save-target-range'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: Key('confirm-$confirmLabel'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

String _confirmedValue(TestRecord record) {
  if (record.parameterId == AppDatabase.khId &&
      record.khTitrationJson != null) {
    final min = record.confirmedMinValue.toStringAsFixed(1);
    final max = record.confirmedMaxValue;
    return max == null || max == record.confirmedMinValue
        ? min
        : '$min–${max.toStringAsFixed(1)}';
  }
  return record.confirmedMaxValue == null
      ? _number(record.confirmedMinValue)
      : '${_number(record.confirmedMinValue)}–${_number(record.confirmedMaxValue!)}';
}

String _estimatedValue(TestRecord record) {
  final min = record.estimatedMinValue;
  if (min == null) return '未进行算法辅助估算';
  final max = record.estimatedMaxValue;
  return max == null
      ? '${_number(min)} ${record.unit}'
      : '${_number(min)}–${_number(max)} ${record.unit}';
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _targetNumber(double? value) => value == null
    ? '未设'
    : value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
