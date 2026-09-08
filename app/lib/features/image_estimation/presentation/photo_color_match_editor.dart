import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;
import '../../../core/images/bounded_image.dart';
import '../domain/card_color_match.dart';

(img.Image, Uint8List) _decodePhoto((Uint8List, int) input) {
  final decoded = decodeBoundedImage(input.$1);
  final upright = img.bakeOrientation(decoded);
  final rotated = input.$2 == 0
      ? upright
      : img.copyRotate(upright, angle: input.$2);
  return (rotated, img.encodePng(rotated));
}

(List<ColorPatch>, ColorMatchResult) _analyze(
  (img.Image, SampleRect, SampleRect, List<ColorPatch>, String) input,
) {
  final patches = input.$4.isEmpty
      ? pickCardPatches(input.$1, input.$2, input.$5)
      : input.$4;
  return (
    patches,
    compareCardColors(sampleRegion(input.$1, input.$3), patches, input.$5),
  );
}

class PhotoColorMatchEditor extends StatefulWidget {
  const PhotoColorMatchEditor({
    super.key,
    required this.path,
    required this.parameter,
    required this.onConfirm,
    required this.onRetake,
    required this.onManual,
  });
  final String path, parameter;
  final ValueChanged<ColorMatchResult> onConfirm;
  final VoidCallback onRetake, onManual;
  @override
  State<PhotoColorMatchEditor> createState() => _PhotoColorMatchEditorState();
}

class _PhotoColorMatchEditorState extends State<PhotoColorMatchEditor> {
  Uint8List? _original;
  MemoryImage? _preview;
  img.Image? _pixels;
  int _rotation = 0, _selection = -2;
  bool _busy = true;
  bool _workActive = false;
  SampleRect? _card, _liquid, _drag;
  Offset? _start;
  List<ColorPatch> _patches = [];
  ColorMatchResult? _result;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final original = await readBoundedImageFile(widget.path);
      if (!mounted) return;
      _original = original;
      await _rotate(0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '无法读取图片：$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _rotate(int delta) async {
    if (_original == null || _workActive || !mounted) return;
    _workActive = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final angle = (_rotation + delta) % 360;
      final decoded = await compute(_decodePhoto, (_original!, angle));
      if (!mounted) return;
      final previousPreview = _preview;
      setState(() {
        _rotation = angle;
        _pixels = decoded.$1;
        _preview = MemoryImage(decoded.$2);
        _card = null;
        _liquid = null;
        _patches = [];
        _result = null;
        _selection = -2;
      });
      if (previousPreview != null) unawaited(previousPreview.evict());
    } catch (e) {
      if (mounted) setState(() => _error = '旋转失败：$e');
    } finally {
      _workActive = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _calculate() async {
    if (_workActive ||
        !mounted ||
        _pixels == null ||
        _card == null ||
        _liquid == null) {
      return;
    }
    _workActive = true;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final value = await compute(_analyze, (
        _pixels!,
        _card!,
        _liquid!,
        _patches,
        widget.parameter,
      ));
      if (mounted) {
        setState(() {
          _patches = value.$1;
          _result = value.$2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : '取色失败，请重新框选。',
        );
      }
    } finally {
      _workActive = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(Offset end, Size size) {
    final start = _start;
    if (start == null) return;
    final left = (start.dx < end.dx ? start.dx : end.dx).clamp(0.0, size.width),
        top = (start.dy < end.dy ? start.dy : end.dy).clamp(0.0, size.height);
    final right = (start.dx > end.dx ? start.dx : end.dx).clamp(
          0.0,
          size.width,
        ),
        bottom = (start.dy > end.dy ? start.dy : end.dy).clamp(
          0.0,
          size.height,
        );
    setState(
      () => _drag = SampleRect(
        left / size.width,
        top / size.height,
        (right - left) / size.width,
        (bottom - top) / size.height,
      ),
    );
  }

  void _finish() {
    final rect = _drag;
    _start = null;
    if (rect == null || !rect.valid) {
      setState(() {
        _drag = null;
        _error = '选区太小，请重新框选。';
      });
      return;
    }
    setState(() {
      _result = null;
      _error = null;
      _drag = null;
      if (_selection == -2) {
        _card = rect;
        _patches = [];
        _selection = -1;
      } else if (_selection == -1) {
        _liquid = rect;
      } else {
        try {
          final old = _patches[_selection];
          _patches = [..._patches]
            ..[_selection] = ColorPatch(
              old.level,
              rect,
              sampleRegion(_pixels!, rect),
            );
        } on FormatException catch (e) {
          _error = e.message;
        }
      }
    });
  }

  String n(double value) => value.toString().replaceFirst(RegExp(r'\.0$'), '');
  Widget _judgment(String title, String? value, List<String> reasons) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title · ${value ?? '暂无法给出'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (value == null && reasons.isNotEmpty) Text(reasons.first),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${widget.parameter} 拍照检测',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('将照片旋转至文字正向、色块两行四列，再框选色卡和测试液。'),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _rotate(-90),
              icon: const Icon(Icons.rotate_left),
              label: const Text('逆时针90°'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _rotate(90),
              icon: const Icon(Icons.rotate_right),
              label: const Text('顺时针90°'),
            ),
          ],
        ),
        DropdownButton<int>(
          value: _selection,
          isExpanded: true,
          onChanged: _busy ? null : (v) => setState(() => _selection = v!),
          items: [
            const DropdownMenuItem(value: -2, child: Text('框选完整色卡')),
            const DropdownMenuItem(value: -1, child: Text('框选测试液')),
            for (var i = 0; i < _patches.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text('调整色块 ${i + 1} · ${n(_patches[i].level)} mg/L'),
              ),
          ],
        ),
        if (_preview != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxWidth * _pixels!.height / _pixels!.width,
              );
              return RawGestureDetector(
                gestures: {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(() => EagerGestureRecognizer(), (_) {}),
                },
                child: Listener(
                  key: const Key('color-match-image'),
                  onPointerDown: _busy
                      ? null
                      : (d) {
                          _start = d.localPosition;
                        },
                  onPointerMove: _busy
                      ? null
                      : (d) => _select(d.localPosition, size),
                  onPointerUp: _busy ? null : (_) => _finish(),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: _preview!,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                        CustomPaint(
                          painter: _BoxesPainter([
                            if (_card != null) (_card!, Colors.blue),
                            if (_liquid != null) (_liquid!, Colors.green),
                            for (final p in _patches) (p.rect, Colors.orange),
                            if (_drag != null) (_drag!, Colors.red),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: _busy || _card == null || _liquid == null
              ? null
              : _calculate,
          child: const Text('取色比较'),
        ),
        if (result != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _judgment(
                    '颜色更接近',
                    result.nearest == null
                        ? null
                        : '${n(result.nearest!)} mg/L 档',
                    result.nearestReasons,
                  ),
                  _judgment(
                    '候选范围',
                    result.low == null
                        ? null
                        : '${n(result.low!)}–${n(result.high!)} mg/L',
                    result.rangeReasons,
                  ),
                  _judgment(
                    '插值参考值',
                    result.interpolation == null
                        ? null
                        : '${result.interpolation!.round()} mg/L',
                    result.interpolationReasons,
                  ),
                  const Text('仅供参考'),
                  FilledButton(
                    onPressed: () => widget.onConfirm(result),
                    child: const Text('修改结果 / 选择是否记录'),
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : widget.onRetake,
          child: const Text('重新拍摄'),
        ),
        TextButton(
          onPressed: _busy ? null : widget.onManual,
          child: const Text('手动录入'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    final preview = _preview;
    _preview = null;
    _original = null;
    _pixels = null;
    if (preview != null) unawaited(preview.evict());
    super.dispose();
  }
}

class _BoxesPainter extends CustomPainter {
  _BoxesPainter(this.boxes);
  final List<(SampleRect, Color)> boxes;
  @override
  void paint(Canvas canvas, Size size) {
    for (final item in boxes) {
      final r = item.$1;
      canvas.drawRect(
        Rect.fromLTWH(
          r.x * size.width,
          r.y * size.height,
          r.w * size.width,
          r.h * size.height,
        ),
        Paint()
          ..color = item.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxesPainter oldDelegate) => true;
}
