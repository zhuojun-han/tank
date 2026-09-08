import 'card_color_match.dart';

enum PhotoFallbackReason {
  userChoseManual,
  unsupportedParameter,
  cameraPermissionDenied,
  cameraUnavailable,
  qualityRejected,
}

enum ManualSelectionKind { singleLevel, adjacentRange }

enum PhotoQualityIssueCode {
  cannotDecode,
  tooSmall,
  tooDark,
  tooBright,
  likelyBlurred,
}

class PhotoCaptureRequest {
  const PhotoCaptureRequest({
    required this.tankId,
    required this.parameterId,
    required this.parameterCode,
    required this.unit,
    this.parameterName,
  });

  final String tankId;
  final String parameterId;
  final String parameterCode;
  final String unit;
  final String? parameterName;

  bool get supportsManualPhotoComparison =>
      const ['NO3', 'PO4'].contains(parameterCode.trim().toUpperCase());

  static const no3Levels = <double>[0, 1, 5, 10, 25, 50, 100];

  static PhotoCaptureRequest? fromQueryParameters(
    Map<String, String> parameters,
  ) {
    final tankId = parameters['tankId']?.trim() ?? '';
    final parameterId = parameters['parameterId']?.trim() ?? '';
    final parameterCode = parameters['parameterCode']?.trim() ?? '';
    final unit = parameters['unit']?.trim() ?? '';
    if (tankId.isEmpty ||
        parameterId.isEmpty ||
        parameterCode.isEmpty ||
        unit.isEmpty) {
      return null;
    }
    return PhotoCaptureRequest(
      tankId: tankId,
      parameterId: parameterId,
      parameterCode: parameterCode,
      unit: unit,
      parameterName: parameters['parameterName']?.trim(),
    );
  }
}

class PhotoQualityIssue {
  const PhotoQualityIssue({required this.code, required this.explanation});

  final PhotoQualityIssueCode code;
  final String explanation;
}

class PhotoQualityReport {
  const PhotoQualityReport({
    required this.width,
    required this.height,
    required this.meanLuminance,
    required this.darkPixelFraction,
    required this.brightPixelFraction,
    required this.laplacianVariance,
    required this.issues,
  });

  factory PhotoQualityReport.cannotDecode() => const PhotoQualityReport(
    width: 0,
    height: 0,
    meanLuminance: 0,
    darkPixelFraction: 0,
    brightPixelFraction: 0,
    laplacianVariance: 0,
    issues: [
      PhotoQualityIssue(
        code: PhotoQualityIssueCode.cannotDecode,
        explanation: '无法读取照片文件，请重新拍摄。',
      ),
    ],
  );

  final int width;
  final int height;
  final double meanLuminance;
  final double darkPixelFraction;
  final double brightPixelFraction;
  final double laplacianVariance;
  final List<PhotoQualityIssue> issues;

  bool get passed => issues.isEmpty;
}

class StoredPhoto {
  const StoredPhoto({
    required this.relativePath,
    required this.absolutePath,
    required this.width,
    required this.height,
    required this.byteLength,
    required this.capturedAtUtc,
    required this.qualityReport,
  });

  final String relativePath;
  final String absolutePath;
  final int width;
  final int height;
  final int byteLength;
  final DateTime capturedAtUtc;
  final PhotoQualityReport qualityReport;
}

class ManualColorSelection {
  ManualColorSelection._({
    required this.kind,
    required this.minimum,
    required this.maximum,
  });

  factory ManualColorSelection.single(double level, List<double> levels) {
    _requireKnownLevel(level, levels);
    return ManualColorSelection._(
      kind: ManualSelectionKind.singleLevel,
      minimum: level,
      maximum: level,
    );
  }

  factory ManualColorSelection.adjacentRange(
    double minimum,
    double maximum,
    List<double> levels,
  ) {
    final lowIndex = levels.indexOf(minimum);
    final highIndex = levels.indexOf(maximum);
    if (lowIndex < 0 || highIndex - lowIndex != 1) {
      throw ArgumentError('人工范围必须由两个相邻色卡档位构成');
    }
    return ManualColorSelection._(
      kind: ManualSelectionKind.adjacentRange,
      minimum: minimum,
      maximum: maximum,
    );
  }

  final ManualSelectionKind kind;
  final double minimum;
  final double maximum;

  static void _requireKnownLevel(double level, List<double> levels) {
    if (!levels.contains(level)) {
      throw ArgumentError('人工选择必须来自当前色卡档位');
    }
  }
}

class PhotoEstimationDraft {
  const PhotoEstimationDraft({
    required this.tankId,
    required this.parameterId,
    required this.parameterCode,
    required this.unit,
    required this.createdAtUtc,
    this.photoRelativePath,
    this.photoCapturedAtUtc,
    this.qualityReport,
    this.manualSelection,
    this.colorMatch,
    this.fallbackReason,
  });

  factory PhotoEstimationDraft.manualOnly({
    required PhotoCaptureRequest request,
    required PhotoFallbackReason reason,
  }) => PhotoEstimationDraft(
    tankId: request.tankId,
    parameterId: request.parameterId,
    parameterCode: request.parameterCode,
    unit: request.unit,
    createdAtUtc: DateTime.now().toUtc(),
    fallbackReason: reason,
  );

  factory PhotoEstimationDraft.withManualComparison({
    required PhotoCaptureRequest request,
    required StoredPhoto photo,
    required ManualColorSelection selection,
  }) => PhotoEstimationDraft(
    tankId: request.tankId,
    parameterId: request.parameterId,
    parameterCode: request.parameterCode,
    unit: request.unit,
    createdAtUtc: DateTime.now().toUtc(),
    // The photo is only a working artifact for this comparison. The capture
    // page deletes it before returning this structured result.
    photoRelativePath: null,
    photoCapturedAtUtc: photo.capturedAtUtc,
    qualityReport: photo.qualityReport,
    manualSelection: selection,
  );

  final String tankId;
  final String parameterId;
  final String parameterCode;
  final String unit;
  final DateTime createdAtUtc;
  final String? photoRelativePath;
  final DateTime? photoCapturedAtUtc;
  final PhotoQualityReport? qualityReport;
  final ManualColorSelection? manualSelection;
  final ColorMatchResult? colorMatch;
  final PhotoFallbackReason? fallbackReason;

  /// Auxiliary estimate retained separately from the user-confirmed record.
  bool get hasUnverifiedAlgorithmEstimate => colorMatch != null;
}
