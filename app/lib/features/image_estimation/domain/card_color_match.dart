import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Port of web-demo/app/color-match/color-analysis.ts. Auxiliary estimates only.
class SampleRect {
  const SampleRect(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  bool get valid =>
      [x, y, w, h].every((v) => v.isFinite) &&
      x >= 0 &&
      y >= 0 &&
      w >= .006 &&
      h >= .006 &&
      x + w <= 1.00001 &&
      y + h <= 1.00001;
}

class ColorSample {
  const ColorSample(
    this.rgb, {
    this.spread = 0,
    this.rejected = 0,
    this.count = 16,
  });
  final List<double> rgb;
  final double spread, rejected;
  final int count;
}

class ColorPatch {
  const ColorPatch(this.level, this.rect, this.sample);
  final double level;
  final SampleRect rect;
  final ColorSample sample;
}

class ColorMatchResult {
  const ColorMatchResult({
    this.nearest,
    this.low,
    this.high,
    this.interpolation,
    required this.nearestReasons,
    required this.rangeReasons,
    required this.interpolationReasons,
  });
  final double? nearest, low, high, interpolation;
  final List<String> nearestReasons, rangeReasons, interpolationReasons;
}

const no3Template = <double>[100, 50, 25, 10, 10, 5, 1, 0];
const po4Template = <double>[3, 1, .5, .25, 0, .03, .1, .25];
List<double> cardTemplate(String parameter) =>
    parameter == 'PO4' ? po4Template : no3Template;
double _median(List<double> values) {
  values.sort();
  return values.isEmpty ? 0 : values[values.length ~/ 2];
}

List<double> rgbToLab(List<double> rgb) {
  final c = rgb.map((v) {
    final n = v / 255;
    return n <= .04045
        ? n / 12.92
        : math.pow((n + .055) / 1.055, 2.4).toDouble();
  }).toList();
  double f(double v) =>
      v > .008856 ? math.pow(v, 1 / 3).toDouble() : 7.787 * v + 16 / 116;
  final x = f((c[0] * .4124564 + c[1] * .3575761 + c[2] * .1804375) / .95047);
  final y = f(c[0] * .2126729 + c[1] * .7151522 + c[2] * .072175);
  final z = f((c[0] * .0193339 + c[1] * .119192 + c[2] * .9503041) / 1.08883);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

double labDistance(List<double> a, List<double> b) => math.sqrt(
  List.generate(
    3,
    (i) => math.pow(a[i] - b[i], 2),
  ).fold<double>(0, (s, v) => s + v),
);
ColorSample sampleRegion(img.Image image, SampleRect rect) {
  if (!rect.valid) throw const FormatException('选区太小或超出照片，请重新框选。');
  final colors = <List<double>>[];
  var total = 0;
  final stride = math.max(
    1,
    math.sqrt(rect.w * image.width * rect.h * image.height / 1600).floor(),
  );
  for (
    var y = (rect.y * image.height).floor();
    y < math.min(image.height, ((rect.y + rect.h) * image.height).ceil());
    y += stride
  ) {
    for (
      var x = (rect.x * image.width).floor();
      x < math.min(image.width, ((rect.x + rect.w) * image.width).ceil());
      x += stride
    ) {
      final p = image.getPixel(x, y);
      final rgb = [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
      total++;
      final max = rgb.reduce(math.max);
      if (max < 25 || max > 250 || p.a < 250) continue;
      colors.add(rgb);
    }
  }
  if (colors.length < 16) {
    throw const FormatException('有效颜色像素不足，请避开黑框、高光和过小选区。');
  }
  final rgb = List.generate(
    3,
    (i) => _median(colors.map((p) => p[i]).toList()),
  );
  final center = rgbToLab(rgb);
  return ColorSample(
    rgb,
    count: colors.length,
    rejected: 1 - colors.length / total,
    spread: _median(
      colors.map((p) => labDistance(rgbToLab(p), center)).toList(),
    ),
  );
}

List<ColorPatch> pickCardPatches(
  img.Image image,
  SampleRect card,
  String parameter,
) {
  if (!card.valid || card.w < .15 || card.h < .08) {
    throw const FormatException('请框选完整的两行四色块区域。');
  }
  return List.generate(8, (i) {
    final x = card.x + card.w * ((i % 4 + .5) / 4),
        y = card.y + card.h * ((i ~/ 4 + .5) / 2);
    ColorPatch? best;
    var bestScore = double.infinity;
    for (final dx in [-.025, 0.0, .025]) {
      for (final dy in [-.03, 0.0, .03]) {
        final rect = SampleRect(
          x + card.w * (dx - .26 / 4),
          y + card.h * (dy - .2 / 2),
          card.w * .52 / 4,
          card.h * .4 / 2,
        );
        try {
          final sample = sampleRegion(image, rect);
          final score =
              sample.spread + sample.rejected * 30 + (dx.abs() + dy.abs()) * 8;
          if (score < bestScore) {
            best = ColorPatch(cardTemplate(parameter)[i], rect, sample);
            bestScore = score;
          }
        } on FormatException {
          /* Try the remaining centers. */
        }
      }
    }
    if (best == null) {
      throw FormatException('${cardTemplate(parameter)[i]} mg/L 色块无法取色，请调整选区。');
    }
    return best;
  });
}

ColorMatchResult compareCardColors(
  ColorSample liquid,
  List<ColorPatch> patches,
  String parameter,
) {
  final levels = cardTemplate(parameter).toSet().toList()..sort();
  final ranked = levels.map((level) {
    final entries = patches.where((p) => p.level == level).toList();
    if (entries.isEmpty) throw const FormatException('色卡档位不完整，请重新取色。');
    final rgb = List.generate(
      3,
      (i) =>
          entries.fold<double>(0, (s, p) => s + p.sample.rgb[i]) /
          entries.length,
    );
    return (
      level: level,
      rgb: rgb,
      delta: labDistance(rgbToLab(liquid.rgb), rgbToLab(rgb)),
    );
  }).toList()..sort((a, b) => a.delta.compareTo(b.delta));
  final warnings = <String>[];
  if (liquid.spread > 12 || liquid.rejected > .25) {
    warnings.add('液体区域颜色不均，请避开反光与瓶壁。');
  }
  if (patches.any((p) => p.sample.spread > 12 || p.sample.rejected > .25)) {
    warnings.add('色卡取色框可能含边缘或遮挡，请调整。');
  }
  final repeated = patches
      .where((p) => p.level == (parameter == 'PO4' ? .25 : 10))
      .toList();
  if (repeated.length == 2 &&
      labDistance(
            rgbToLab(repeated[0].sample.rgb),
            rgbToLab(repeated[1].sample.rgb),
          ) >
          15) {
    warnings.add('重复色块颜色差异较大，请检查阴影或选区。');
  }
  final a = ranked[0], b = ranked[1];
  final nearest = [...warnings], range = [...warnings];
  if (a.delta > 30) nearest.add('测试液与最近色档色差过大。');
  if ((a.delta - b.delta).abs() <= 1e-6) nearest.add('两档同样接近，无法确定唯一最近档。');
  if (a.delta > 30 || b.delta > 38) range.add('测试液与候选色档色差过大。');
  if ((levels.indexOf(a.level) - levels.indexOf(b.level)).abs() != 1) {
    range.add('相近色档不相邻，请调整取色框。');
  }
  final l = rgbToLab(liquid.rgb), p = rgbToLab(a.rgb), q = rgbToLab(b.rgb);
  final v = List.generate(3, (i) => q[i] - p[i]);
  final denom = v.fold<double>(0, (s, x) => s + x * x);
  final t = denom > .01
      ? List.generate(
              3,
              (i) => v[i] * (l[i] - p[i]),
            ).fold<double>(0, (s, x) => s + x) /
            denom
      : -1;
  final interpolation = range.isNotEmpty ? ['候选范围无法确定，暂不能计算插值。'] : <String>[];
  if (range.isEmpty && denom <= .01) {
    interpolation.add('候选两档颜色无法区分，不能插值。');
  } else if (range.isEmpty && (t < 0 || t > 1)) {
    interpolation.add('颜色超出两档之间，暂不能计算插值。');
  }
  return ColorMatchResult(
    nearest: nearest.isEmpty ? a.level : null,
    low: range.isEmpty ? math.min(a.level, b.level) : null,
    high: range.isEmpty ? math.max(a.level, b.level) : null,
    interpolation: interpolation.isEmpty
        ? a.level + t * (b.level - a.level)
        : null,
    nearestReasons: nearest,
    rangeReasons: range,
    interpolationReasons: interpolation,
  );
}
