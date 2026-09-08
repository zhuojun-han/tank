import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/images/bounded_image.dart';

import '../application/aquarium_providers.dart';
import '../data/fish_artwork_processor.dart';
import '../domain/fish_stock.dart';
import 'fish_artwork_view.dart';

enum _AddMode { builtin, custom }

class FishManagerSheet extends ConsumerStatefulWidget {
  const FishManagerSheet({
    required this.tankId,
    required this.tankName,
    required this.initialItems,
    super.key,
  });

  final String tankId;
  final String tankName;
  final List<FishStockItem> initialItems;

  @override
  ConsumerState<FishManagerSheet> createState() => _FishManagerSheetState();
}

class _FishManagerSheetState extends ConsumerState<FishManagerSheet> {
  final _speciesController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _artworkProcessor = const FishArtworkProcessor();
  late List<FishStockItem> _draft;
  _AddMode _mode = _AddMode.builtin;
  FishArtworkKind _selectedBuiltinKind = FishArtworkKind.builtinClownfish;
  DateTime _newDate = _dateOnly(DateTime.now());
  PreparedFishArtwork? _newArtwork;
  String? _processingItemId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = [...widget.initialItems];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: availableHeight * 0.92,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tankName,
                            style: theme.textTheme.labelLarge,
                          ),
                          Text('鱼类档案', style: theme.textTheme.headlineSmall),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const Key('fish-manager-list'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Text(
                      '每条档案都保存鱼种、真实数量、入缸日期和立绘。鱼缸最多同时渲染 $maximumAnimatedFish 条，但不会截断库存数据。',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (_draft.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.set_meal_outlined),
                          title: Text('当前还没有鱼'),
                          subtitle: Text('可从下方选择内置鱼种，或上传其他鱼种立绘。'),
                        ),
                      ),
                    for (final item in _draft) _existingItemCard(item),
                    const SizedBox(height: 10),
                    Text('添加鱼种', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<_AddMode>(
                      segments: const [
                        ButtonSegment(
                          value: _AddMode.builtin,
                          icon: Icon(Icons.auto_awesome_outlined),
                          label: Text('内置鱼种'),
                        ),
                        ButtonSegment(
                          value: _AddMode.custom,
                          icon: Icon(Icons.add_photo_alternate_outlined),
                          label: Text('其他鱼种'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (value) {
                        setState(() {
                          _mode = value.single;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_mode == _AddMode.builtin)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${builtinFishCatalog.length} 个内置鱼种 · 点击立绘选择',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 148,
                            child: ListView.separated(
                              key: const Key('builtin-fish-catalog'),
                              scrollDirection: Axis.horizontal,
                              itemCount: builtinFishCatalog.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final species = builtinFishCatalog[index];
                                final selected =
                                    species.kind == _selectedBuiltinKind;
                                return SizedBox(
                                  width: 158,
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    clipBehavior: Clip.antiAlias,
                                    color: selected
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surfaceContainerLow,
                                    child: InkWell(
                                      key: Key(
                                        'builtin-fish-${species.kind.name}',
                                      ),
                                      onTap: () => setState(() {
                                        _selectedBuiltinKind = species.kind;
                                        _error = null;
                                      }),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  FishArtworkView(
                                                    kind: species.kind,
                                                  ),
                                                  if (selected)
                                                    const Align(
                                                      alignment:
                                                          Alignment.topRight,
                                                      child: Icon(
                                                        Icons.check_circle,
                                                        size: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              species.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            Text(
                                              species.note,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TextField(
                        key: const Key('custom-fish-species-field'),
                        controller: _speciesController,
                        maxLength: 24,
                        decoration: const InputDecoration(
                          labelText: '鱼种名称',
                          hintText: '例如：蓝吊',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const Key('pick-custom-fish-artwork'),
                          onTap: _processingItemId == null
                              ? () => _pickArtwork()
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 88,
                                  height: 58,
                                  child: _newArtwork == null
                                      ? const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xFFE3F1EE),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(12),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                          ),
                                        )
                                      : FishArtworkView(
                                          kind: FishArtworkKind.custom,
                                          customBytes: base64Decode(
                                            _newArtwork!.base64Data,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _processingItemId == 'new'
                                            ? '正在处理立绘…'
                                            : _newArtwork == null
                                            ? '上传鱼的立绘'
                                            : '重新选择立绘',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const Text(
                                        'PNG、JPG 或 WebP，原图不超过 8 MB；鱼头朝右、透明背景效果最好。',
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('new-fish-quantity-field'),
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '数量'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateButton(
                            value: _newDate,
                            onPressed: () async {
                              final selected = await _pickDate(_newDate);
                              if (selected != null) {
                                setState(() => _newDate = selected);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      key: const Key('add-fish-stock-item'),
                      onPressed: _processingItemId == null ? _addItem : null,
                      icon: const Icon(Icons.add),
                      label: const Text('加入鱼类档案'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        key: const Key('fish-manager-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save-fish-stock'),
                    onPressed: _saving || _processingItemId != null
                        ? null
                        : _save,
                    child: Text(_saving ? '正在保存…' : '保存鱼类档案'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _existingItemCard(FishStockItem item) {
    final bytes = item.artworkKind == FishArtworkKind.custom
        ? item.customArtworkBytes
        : null;
    return Card(
      key: Key('fish-stock-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 46,
                  child: FishArtworkView(
                    kind: item.artworkKind,
                    customBytes: bytes,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.species,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text('入缸 ${_formatDate(item.introducedOn)}'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => setState(
                    () => _draft.removeWhere((entry) => entry.id == item.id),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text('数量'),
                IconButton(
                  tooltip: '减少数量',
                  onPressed: item.quantity > 1
                      ? () => _updateItem(
                          item.copyWith(quantity: item.quantity - 1),
                        )
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${item.quantity}'),
                IconButton(
                  tooltip: '增加数量',
                  onPressed: item.quantity < maximumFishQuantity
                      ? () => _updateItem(
                          item.copyWith(quantity: item.quantity + 1),
                        )
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await _pickDate(item.introducedOn);
                    if (selected != null) {
                      _updateItem(item.copyWith(introducedOn: selected));
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('修改日期'),
                ),
              ],
            ),
            if (item.artworkKind == FishArtworkKind.custom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _processingItemId == null
                      ? () => _pickArtwork(itemId: item.id)
                      : null,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _processingItemId == item.id ? '正在处理…' : '更换该鱼种立绘',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _updateItem(FishStockItem updated) {
    setState(() {
      final index = _draft.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _draft[index] = updated;
    });
  }

  Future<void> _pickArtwork({String? itemId}) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '鱼类立绘',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
          mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    setState(() {
      _processingItemId = itemId ?? 'new';
      _error = null;
    });
    try {
      final prepared = await _artworkProcessor.prepare(
        await readBoundedImageFile(
          file.path,
          maximumBytes: maximumFishArtworkInputBytes,
        ),
      );
      if (!mounted) return;
      if (itemId == null) {
        setState(() {
          _newArtwork = prepared;
        });
      } else {
        final current = _draft.firstWhere((item) => item.id == itemId);
        _updateItem(
          current.copyWith(
            artworkMimeType: prepared.mimeType,
            artworkBase64: prepared.base64Data,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  void _addItem() {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1 || quantity > maximumFishQuantity) {
      setState(() => _error = '数量必须是 1–$maximumFishQuantity 的整数');
      return;
    }
    final custom = _mode == _AddMode.custom;
    final builtin = builtinFishSpeciesFor(_selectedBuiltinKind);
    final species = custom ? _speciesController.text.trim() : builtin.name;
    if (species.isEmpty || species.length > 24) {
      setState(() => _error = '鱼种名称不能为空且不能超过 24 个字符');
      return;
    }
    if (custom && _newArtwork == null) {
      setState(() => _error = '请先上传该鱼种的立绘');
      return;
    }
    final repository = ref.read(fishStockRepositoryProvider);
    final item = FishStockItem(
      id: repository.createId(),
      tankId: widget.tankId,
      species: species,
      quantity: quantity,
      introducedOn: _newDate,
      artworkKind: custom ? FishArtworkKind.custom : builtin.kind,
      artworkMimeType: custom ? _newArtwork!.mimeType : null,
      artworkBase64: custom ? _newArtwork!.base64Data : null,
    );
    setState(() {
      _draft.add(item);
      _error = null;
      _quantityController.text = '1';
      _speciesController.clear();
      _newArtwork = null;
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.toLocal(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择入缸日期',
    );
    return selected == null
        ? null
        : DateTime.utc(selected.year, selected.month, selected.day);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(fishStockRepositoryProvider)
          .replaceForTank(tankId: widget.tankId, items: _draft);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败：$error';
        });
      }
    }
  }

  @override
  void dispose() {
    _speciesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.value, required this.onPressed});

  final DateTime value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('入缸 ${_formatDate(value)}'),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String _formatDate(DateTime value) {
  final date = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
