import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../domain/photo_capture_models.dart';

enum PhotoProcessingStatus { accepted, rejected, failed }

class PhotoProcessingResult {
  const PhotoProcessingResult._({
    required this.status,
    this.storedPhoto,
    this.qualityReport,
    this.retainedSourcePath,
    this.failureMessage,
  });

  factory PhotoProcessingResult.accepted(StoredPhoto photo) =>
      PhotoProcessingResult._(
        status: PhotoProcessingStatus.accepted,
        storedPhoto: photo,
        qualityReport: photo.qualityReport,
      );

  factory PhotoProcessingResult.rejected({
    required PhotoQualityReport qualityReport,
    required String retainedSourcePath,
  }) => PhotoProcessingResult._(
    status: PhotoProcessingStatus.rejected,
    qualityReport: qualityReport,
    retainedSourcePath: retainedSourcePath,
  );

  factory PhotoProcessingResult.failed({
    required String message,
    required String retainedSourcePath,
  }) => PhotoProcessingResult._(
    status: PhotoProcessingStatus.failed,
    failureMessage: message,
    retainedSourcePath: retainedSourcePath,
  );

  final PhotoProcessingStatus status;
  final StoredPhoto? storedPhoto;
  final PhotoQualityReport? qualityReport;
  final String? retainedSourcePath;
  final String? failureMessage;
}

abstract class CapturedPhotoProcessor {
  /// Processes a camera-plugin-owned temporary file.
  ///
  /// Ownership transfers to the processor while this future is pending. An
  /// [PhotoProcessingStatus.accepted] result means the processor has consumed
  /// (or otherwise taken responsibility for) [sourcePath], so the caller must
  /// not discard that source again. Rejected and failed results return cleanup
  /// ownership through [PhotoProcessingResult.retainedSourcePath]. If this
  /// method throws, ownership of the original [sourcePath] returns to the
  /// caller.
  Future<PhotoProcessingResult> process(String sourcePath);

  Future<void> discardSource(String sourcePath);

  Future<void> deleteStoredPhoto(StoredPhoto photo);
}

class PhotoQualityInspector {
  const PhotoQualityInspector({
    this.minimumShortEdge = 720,
    this.minimumPixelCount = 900000,
    this.minimumMeanLuminance = 38,
    this.maximumMeanLuminance = 225,
    this.maximumExtremeFraction = 0.55,
    this.minimumLaplacianVariance = 80,
  });

  final int minimumShortEdge;
  final int minimumPixelCount;
  final double minimumMeanLuminance;
  final double maximumMeanLuminance;
  final double maximumExtremeFraction;
  final double minimumLaplacianVariance;

  PhotoQualityReport inspect(img.Image source) {
    final issues = <PhotoQualityIssue>[];
    final shortEdge = math.min(source.width, source.height);
    if (shortEdge < minimumShortEdge ||
        source.width * source.height < minimumPixelCount) {
      issues.add(
        const PhotoQualityIssue(
          code: PhotoQualityIssueCode.tooSmall,
          explanation: '照片尺寸过小，难以看清色卡和试管，请靠近后重新拍摄。',
        ),
      );
    }

    final sampleStep = math
        .max(1, math.sqrt((source.width * source.height) / 40000).floor())
        .toInt();
    var luminanceSum = 0.0;
    var samples = 0;
    var darkPixels = 0;
    var brightPixels = 0;
    for (var y = 0; y < source.height; y += sampleStep) {
      for (var x = 0; x < source.width; x += sampleStep) {
        final pixel = source.getPixel(x, y);
        final luminance =
            0.2126 * pixel.r.toDouble() +
            0.7152 * pixel.g.toDouble() +
            0.0722 * pixel.b.toDouble();
        luminanceSum += luminance;
        samples++;
        if (luminance <= 24) darkPixels++;
        if (luminance >= 245) brightPixels++;
      }
    }
    final meanLuminance = samples == 0 ? 0.0 : luminanceSum / samples;
    final darkFraction = samples == 0 ? 0.0 : darkPixels / samples;
    final brightFraction = samples == 0 ? 0.0 : brightPixels / samples;
    if (meanLuminance < minimumMeanLuminance ||
        darkFraction > maximumExtremeFraction) {
      issues.add(
        const PhotoQualityIssue(
          code: PhotoQualityIssueCode.tooDark,
          explanation: '画面整体过暗或阴影过多，请移到明亮的中性光线下重拍。',
        ),
      );
    }
    if (meanLuminance > maximumMeanLuminance ||
        brightFraction > maximumExtremeFraction) {
      issues.add(
        const PhotoQualityIssue(
          code: PhotoQualityIssueCode.tooBright,
          explanation: '画面过曝或强反光区域过多，请调整角度并保持闪光灯关闭。',
        ),
      );
    }

    final laplacianVariance = _laplacianVariance(source);
    if (laplacianVariance < minimumLaplacianVariance) {
      issues.add(
        const PhotoQualityIssue(
          code: PhotoQualityIssueCode.likelyBlurred,
          explanation: '画面可能失焦或抖动，请稳定手机、对焦色卡后重拍。',
        ),
      );
    }
    return PhotoQualityReport(
      width: source.width,
      height: source.height,
      meanLuminance: meanLuminance,
      darkPixelFraction: darkFraction,
      brightPixelFraction: brightFraction,
      laplacianVariance: laplacianVariance,
      issues: List.unmodifiable(issues),
    );
  }

  double _laplacianVariance(img.Image source) {
    final stride = math
        .max(1, math.max(source.width, source.height) ~/ 320)
        .toInt();
    var sum = 0.0;
    var squareSum = 0.0;
    var count = 0;
    for (var y = stride; y < source.height - stride; y += stride) {
      for (var x = stride; x < source.width - stride; x += stride) {
        final center = _luminance(source.getPixel(x, y));
        final laplacian =
            4 * center -
            _luminance(source.getPixel(x - stride, y)) -
            _luminance(source.getPixel(x + stride, y)) -
            _luminance(source.getPixel(x, y - stride)) -
            _luminance(source.getPixel(x, y + stride));
        sum += laplacian;
        squareSum += laplacian * laplacian;
        count++;
      }
    }
    if (count == 0) return 0;
    final mean = sum / count;
    return math.max(0.0, squareSum / count - mean * mean).toDouble();
  }

  double _luminance(img.Pixel pixel) =>
      0.2126 * pixel.r.toDouble() +
      0.7152 * pixel.g.toDouble() +
      0.0722 * pixel.b.toDouble();
}
