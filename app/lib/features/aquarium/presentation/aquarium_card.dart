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
    final speciesSummary = items.isEmpty
        ? '点击添加第一条鱼'
        : items.map((item) => '${item.species} × ${item.quantity}').join(' · ');
    return Semantics(
      button: true,
      label: '$tankName 的鱼缸，$speciesSummary',
      child: Card(
        key: const Key('home-aquarium-card'),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 232,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  aquariumBackgroundAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x5507233F),
                        Colors.transparent,
                        Color(0x6607182A),
                      ],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                ),
                Positioned.fill(child: _AnimatedFishLayer(items: items)),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('edit-tank-start-date'),
                          onTap: onManageTank,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '我的鱼缸 · $tankName',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                              Text(
                                runningDays == null
                                    ? '设置开缸日期'
                                    : '已运行 $runningDays 天',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('edit-fish-stock'),
                        tooltip: '编辑鱼类档案',
                        onPressed: onTap,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: Text(
                      speciesSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

class _AnimatedFishLayerState extends State<_AnimatedFishLayer> {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  AquariumBounds? _bounds;
  List<_FishEntry> _entries = const [];
  Map<String, Uint8List> _customArtwork = const {};

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
    _syncArtwork();
    if (_fishCount(widget.items) > 0) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _AnimatedFishLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The homepage clock rebuilds every second. Equivalent stock is not a
    // new scene: keep positions, velocities and the ticker's elapsed time.
    if (_sameStock(oldWidget.items, widget.items)) return;
    _syncArtwork();
    _entries = const [];
    _bounds = null;
    _lastElapsed = null;
    if (_fishCount(widget.items) > 0) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticker.muted = !TickerMode.valuesOf(context).enabled;
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
        // The repository codec already rejects invalid data. This fallback
        // keeps a damaged legacy record from crashing the animation layer.
      }
    }
    _customArtwork = result;
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _entries.isEmpty || _bounds == null) {
      _lastElapsed = elapsed;
      return;
    }
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;
    final delta = (elapsed - previous).inMicroseconds / 1000000;
    for (final entry in _entries) {
      stepFishMotion(entry.motion, delta, _bounds!, entry.size);
      entry.facing = fishFacing(entry.motion.vx, entry.facing);
    }
    setState(() {});
  }

  void _prepareEntries(AquariumBounds bounds) {
    if (_entries.isNotEmpty &&
        _bounds?.width == bounds.width &&
        _bounds?.height == bounds.height) {
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
        final seed = fishSeed(key);
        final size = 38.0 + (seed % 17);
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
  Widget build(BuildContext context) {
    if (_fishCount(widget.items) == 0) {
      return const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x66071B2D),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text('点击鱼缸添加鱼', style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = AquariumBounds(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        _prepareEntries(bounds);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
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
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
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

int _fishCount(List<FishStockItem> items) =>
    items.fold(0, (sum, item) => sum + item.quantity);

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
