import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanjiao_water_quality/features/image_estimation/data/captured_photo_processor.dart';
import 'package:lanjiao_water_quality/features/image_estimation/domain/photo_capture_models.dart';

void main() {
  const inspector = PhotoQualityInspector();

  test('拒绝尺寸过小且不可解释为可估值照片', () {
    final image = img.Image(width: 320, height: 480);
    _fillCheckerboard(image);

    final report = inspector.inspect(image);

    expect(report.passed, isFalse);
    expect(
      report.issues.map((item) => item.code),
      contains(PhotoQualityIssueCode.tooSmall),
    );
  });

  test('分别解释画面过暗和过曝', () {
    final dark = img.Image(width: 800, height: 1200);
    final bright = img.Image(width: 800, height: 1200);
    _fill(dark, 4);
    _fill(bright, 252);

    final darkReport = inspector.inspect(dark);
    final brightReport = inspector.inspect(bright);

    expect(
      darkReport.issues.map((item) => item.code),
      contains(PhotoQualityIssueCode.tooDark),
    );
    expect(
      brightReport.issues.map((item) => item.code),
      contains(PhotoQualityIssueCode.tooBright),
    );
  });

  test('足够大的中性高频图通过基础尺寸亮度清晰度预检', () {
    final image = img.Image(width: 800, height: 1200);
    _fillCheckerboard(image);

    final report = inspector.inspect(image);

    expect(report.passed, isTrue);
    expect(report.meanLuminance, inInclusiveRange(80, 180));
    expect(report.laplacianVariance, greaterThan(80));
  });

  test('人工范围只接受相邻的已知 NO3 色卡档位', () {
    final selection = ManualColorSelection.adjacentRange(
      10,
      25,
      PhotoCaptureRequest.no3Levels,
    );

    expect(selection.minimum, 10);
    expect(selection.maximum, 25);
    expect(
      () => ManualColorSelection.adjacentRange(
        5,
        25,
        PhotoCaptureRequest.no3Levels,
      ),
      throwsArgumentError,
    );
  });
}

void _fill(img.Image image, int value) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, value, value, value, 255);
    }
  }
}

void _fillCheckerboard(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final value = ((x ~/ 6) + (y ~/ 6)).isEven ? 48 : 208;
      image.setPixelRgba(x, y, value, value, value, 255);
    }
  }
}
