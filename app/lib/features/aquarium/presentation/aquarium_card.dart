import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/aquarium_motion.dart';
import '../domain/fish_stock.dart';
import 'fish_artwork_view.dart';

class AquariumCard extends StatelessWidget {
  const AquariumCard({
    required this.tankName,
    required this.items,
    required this.onTap,
    this.runningDays,
    this.onManageTank,
    super.key,
  });
  final String tankName;
  final List<FishStockItem> items;
  final VoidCallback onTap;
  final int? runningDays;
  final VoidCallback? onManageTank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = items.isEmpty
        ? '还没有鱼，点击鱼缸添加'
        : items.map((item) => '${item.species} × ${item.quantity}').join('、');
    return Semantics(
      container: true,
      label: '$tankName 的鱼缸',
      child: Card(
        key: const Key('home-aquarium-card'),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(color: scheme.primary.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('edit-tank-start-date'),
                      onTap: onManageTank,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '鱼缸运行时长',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.primary),
                            ),
                            Text(
                              runningDays == null
                                  ? '设置开缸日期'
                                  : '已运行 $runningDays 天',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('edit-fish-stock'),
                    onPressed: onTap,
                    child: const Text('编辑鱼只 ›'),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '查看 $tankName 的鱼只',
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  key: const Key('aquarium-water'),
                  height: 190,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        aquariumBackgroundAsset,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -.04),
                        excludeFromSemantics: true,
                      ),
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: _AnimatedFishLayer(items: items),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
                child: Text(
                  summary,
                  key: const Key('aquarium-stock-summary'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedFishLayer extends StatefulWidget {
  const _AnimatedFishLayer({required this.items});
  final List<FishStockItem> items;
  @override
  State<_AnimatedFishLayer> createState() => _AnimatedFishLayerState();
}

class _AnimatedFishLayerState extends State<_AnimatedFishLayer>
    with WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  AquariumBounds? _bounds;
  List<_FishEntry> _entries = const [];
  Map<String, Uint8List> _customArtwork = const {};
  ScrollPosition? _scrollPosition;
  bool _visible = false,
      _visibilityQueued = false,
      _tickerMode = true,
      _reduceMotion = false;
  bool _foreground = true;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _syncArtwork();
  }

  @override
  void didUpdateWidget(covariant _AnimatedFishLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An equivalent stock refresh must not restart the scene or bubble phase.
    if (_sameStock(oldWidget.items, widget.items)) return;
    _syncArtwork();
    _entries = const [];
    _bounds = null;
    _lastElapsed = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_queueVisibilityCheck);
      _scrollPosition = position;
      _scrollPosition?.addListener(_queueVisibilityCheck);
    }
    _updatePlayback();
    _queueVisibilityCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePlayback();
    if (_foreground) _queueVisibilityCheck();
  }

  void _queueVisibilityCheck() {
    if (_visibilityQueued) return;
    _visibilityQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityQueued = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final visibleRect = viewport is RenderBox && viewport.hasSize
          ? viewport.localToGlobal(Offset.zero) & viewport.size
          : Offset.zero & MediaQuery.sizeOf(context);
      _visible = rect.overlaps(visibleRect);
      _updatePlayback();
    });
  }

  void _updatePlayback() {
    final play = _foreground && _tickerMode && !_reduceMotion && _visible;
    if (play == _ticker.isActive) return;
    _lastElapsed = null;
    if (play) {
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _syncArtwork() {
    final result = <String, Uint8List>{};
    for (final item in widget.items) {
      if (item.artworkKind != FishArtworkKind.custom ||
          item.artworkBase64 == null) {
        continue;
      }
      try {
        result[item.id] = base64Decode(item.artworkBase64!);
      } on FormatException {
        // A damaged legacy artwork must not crash the aquarium.
      }
    }
    _customArtwork = result;
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _bounds == null) {
      _lastElapsed = elapsed;
      return;
    }
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;
    final delta = (elapsed - previous).inMicroseconds / 1000000;
    _seconds = (_seconds + delta) % 4.6;
    for (final entry in _entries) {
      stepFishMotion(entry.motion, delta, _bounds!, entry.size);
      entry.facing = fishFacing(entry.motion.vx, entry.facing);
    }
    // Only the bounded fish/bubble layer rebuilds, never the homepage or image.
    setState(() {});
  }

  void _prepareEntries(AquariumBounds bounds) {
    if (_bounds?.width == bounds.width && _bounds?.height == bounds.height) {
      return;
    }
    _bounds = bounds;
    final entries = <_FishEntry>[];
    for (final item in widget.items) {
      for (
        var index = 0;
        index < item.quantity && entries.length < maximumAnimatedFish;
        index++
      ) {
        final key = '${item.id}-$index';
        final size = 38.0 + (fishSeed(key) % 17);
        final motion = createFishMotion(key, bounds, size);
        entries.add(
          _FishEntry(
            key: key,
            item: item,
            size: size,
            motion: motion,
            facing: fishFacing(motion.vx, motion.direction),
          ),
        );
      }
      if (entries.length >= maximumAnimatedFish) break;
    }
    _entries = entries;
    _lastElapsed = null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _prepareEntries(
        AquariumBounds(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        ),
      );
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                key: const Key('aquarium-bubbles'),
                painter: _BubblePainter(_seconds),
              ),
            ),
          ),
          for (final entry in _entries)
            Positioned(
              key: ValueKey(entry.key),
              left: entry.motion.x - entry.size / 2,
              top: entry.motion.y - entry.size * (25 / 88),
              width: entry.size,
              height: entry.size * (50 / 88),
              child: Transform.rotate(
                angle:
                    fishPitchDegrees(entry.motion.vx, entry.motion.vy) *
                    math.pi /
                    180,
                child: Transform.scale(
                  scaleX: entry.facing.toDouble(),
                  child: FishArtworkView(
                    kind: entry.item.artworkKind,
                    customBytes: _customArtwork[entry.item.id],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  void dispose() {
    _scrollPosition?.removeListener(_queueVisibilityCheck);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.seconds);
  final double seconds;
  @override
  void paint(Canvas canvas, Size size) {
    const bubbles = [
      (left: .17, radius: 4.0, delay: 1.0),
      (left: .76, radius: 2.5, delay: 2.7),
      (left: .83, radius: 5.5, delay: 3.8),
    ];
    for (final bubble in bubbles) {
      final progress = ((seconds + bubble.delay) / 4.6) % 1;
      final opacity = progress < .18
          ? progress / .18 * .8
          : (1 - progress) / .82 * .8;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(
        Offset(
          size.width * bubble.left,
          size.height -
              18 -
              math.min(160, size.height - 20) * progress * progress,
        ),
        bubble.radius * (.7 + .5 * progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      seconds != oldDelegate.seconds;
}

class _FishEntry {
  _FishEntry({
    required this.key,
    required this.item,
    required this.size,
    required this.motion,
    required this.facing,
  });

  final String key;
  final FishStockItem item;
  final double size;
  final FishMotionState motion;
  int facing;
}

bool _sameStock(List<FishStockItem> previous, List<FishStockItem> current) {
  if (previous.length != current.length) return false;
  for (var i = 0; i < previous.length; i++) {
    final a = previous[i];
    final b = current[i];
    if (a.id != b.id ||
        a.tankId != b.tankId ||
        a.species != b.species ||
        a.quantity != b.quantity ||
        a.introducedOn != b.introducedOn ||
        a.artworkKind != b.artworkKind ||
        a.artworkMimeType != b.artworkMimeType ||
        a.artworkBase64 != b.artworkBase64) {
      return false;
    }
  }
  return true;
}
