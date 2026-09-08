import 'package:lanjiao_water_quality/features/image_estimation/presentation/photo_color_match_editor.dart';
import 'package:lanjiao_water_quality/features/image_estimation/domain/card_color_match.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/image_estimation/data/camera_gateway.dart';
import 'package:lanjiao_water_quality/features/image_estimation/data/captured_photo_processor.dart';
import 'package:lanjiao_water_quality/features/image_estimation/domain/photo_capture_models.dart';
import 'package:lanjiao_water_quality/features/image_estimation/presentation/photo_capture_page.dart';

void main() {
  const no3Request = PhotoCaptureRequest(
    tankId: 'tank-1',
    parameterId: 'parameter-no3',
    parameterCode: 'NO3',
    parameterName: '硝酸盐',
    unit: 'mg/L',
  );

  testWidgets('假相机完成拍照后只返回人工选择的相邻范围', (tester) async {
    _usePortraitView(tester);
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor();
    PhotoEstimationDraft? returnedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                returnedDraft = await Navigator.of(context).push(
                  MaterialPageRoute<PhotoEstimationDraft>(
                    builder: (_) => PhotoCapturePage(
                      request: no3Request,
                      cameraGateway: gateway,
                      photoProcessor: processor,
                    ),
                  ),
                );
              },
              child: const Text('进入拍照'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('进入拍照'));
    await tester.pumpAndSettle();
    expect(find.textContaining('仅供参考'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-camera')));
    await tester.pumpAndSettle();
    expect(gateway.initializeCalls, 1);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture-photo')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(processor.processedPaths, ['/temporary/capture.jpg']);

    tester
        .widget<PhotoColorMatchEditor>(find.byType(PhotoColorMatchEditor))
        .onConfirm(
          const ColorMatchResult(
            low: 10,
            high: 25,
            interpolation: 18.3,
            nearest: 25,
            nearestReasons: [],
            rangeReasons: [],
            interpolationReasons: [],
          ),
        );
    await tester.pumpAndSettle();

    expect(returnedDraft, isNotNull);
    expect(returnedDraft!.photoRelativePath, isNull);
    expect(returnedDraft!.colorMatch!.low, 10);
    expect(returnedDraft!.colorMatch!.high, 25);
    expect(returnedDraft!.hasUnverifiedAlgorithmEstimate, isTrue);
    // An accepted result means the processor already consumed or owns the
    // camera temporary file. The page must not try to delete it a second time.
    expect(processor.discardedSources, isEmpty);
    expect(processor.deletedStoredPhotos, [processor.storedPhoto]);
  });

  testWidgets('已接管源文件的成功结果在重拍时只删除未提交的压缩照片', (tester) async {
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor();
    await _openPhotoRoute(tester, gateway: gateway, processor: processor);
    await _startCameraAndCapture(tester);

    await _scrollToAndTap(tester, find.text('重新拍摄'));
    await tester.pumpAndSettle();

    expect(processor.discardedSources, isEmpty);
    expect(processor.deletedStoredPhotos, [processor.storedPhoto]);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
  });

  testWidgets('质量拒绝后重拍会清理页面重新取得所有权的源临时文件', (tester) async {
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor(
      outcome: _FakeProcessingOutcome.rejected,
    );
    await _openPhotoRoute(tester, gateway: gateway, processor: processor);
    await _startCameraAndCapture(tester);

    expect(find.text('这张照片暂不适合比色'), findsOneWidget);
    await _scrollToAndTap(tester, find.byKey(const Key('retake-photo')));
    await tester.pumpAndSettle();

    expect(processor.discardedSources, ['/temporary/capture.jpg']);
    expect(processor.deletedStoredPhotos, isEmpty);
  });

  testWidgets('处理失败后返回会清理返回给页面的源临时文件', (tester) async {
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor(
      outcome: _FakeProcessingOutcome.failed,
    );
    await _openPhotoRoute(tester, gateway: gateway, processor: processor);
    await _startCameraAndCapture(tester);

    expect(find.text('测试处理失败'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(processor.discardedSources, ['/temporary/capture.jpg']);
    expect(processor.deletedStoredPhotos, isEmpty);
  });

  testWidgets('处理中返回后由完成结果决定清理对象且不并发删除源文件', (tester) async {
    final pending = Completer<PhotoProcessingResult>();
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor(pendingResult: pending);
    await _openPhotoRoute(tester, gateway: gateway, processor: processor);

    await tester.tap(find.byKey(const Key('start-camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture-photo')));
    await tester.pump();
    expect(find.text('正在本机检查临时照片…'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    expect(processor.discardedSources, isEmpty);

    pending.complete(PhotoProcessingResult.accepted(processor.storedPhoto));
    await tester.pumpAndSettle();

    expect(processor.discardedSources, isEmpty);
    expect(processor.deletedStoredPhotos, [processor.storedPhoto]);
  });

  testWidgets('确认提交等待相机释放时返回仍删除尚未交付的压缩照片', (tester) async {
    final pendingDispose = Completer<void>();
    final gateway = _FakeCameraGateway(pendingDispose: pendingDispose);
    final processor = _FakePhotoProcessor();
    await _openPhotoRoute(tester, gateway: gateway, processor: processor);
    await _startCameraAndCapture(tester);

    tester
        .widget<PhotoColorMatchEditor>(find.byType(PhotoColorMatchEditor))
        .onConfirm(
          const ColorMatchResult(
            low: 10,
            high: 25,
            interpolation: 18,
            nearestReasons: [],
            rangeReasons: [],
            interpolationReasons: [],
          ),
        );
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(processor.discardedSources, isEmpty);
    expect(processor.deletedStoredPhotos, [processor.storedPhoto]);

    pendingDispose.complete();
    await tester.pumpAndSettle();
    expect(processor.deletedStoredPhotos, [processor.storedPhoto]);
  });

  testWidgets('KH 不启动相机并返回可继续手动录入的草稿', (tester) async {
    _usePortraitView(tester);
    final gateway = _FakeCameraGateway();
    final processor = _FakePhotoProcessor();
    PhotoEstimationDraft? returnedDraft;
    const po4Request = PhotoCaptureRequest(
      tankId: 'tank-1',
      parameterId: 'parameter-kh',
      parameterCode: 'KH',
      unit: 'mg/L',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                returnedDraft = await Navigator.of(context).push(
                  MaterialPageRoute<PhotoEstimationDraft>(
                    builder: (_) => PhotoCapturePage(
                      request: po4Request,
                      cameraGateway: gateway,
                      photoProcessor: processor,
                    ),
                  ),
                );
              },
              child: const Text('进入 PO4'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('进入 PO4'));
    await tester.pumpAndSettle();
    expect(find.text('KH 暂不支持拍照比色'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unsupported-manual-entry')));
    await tester.pumpAndSettle();

    expect(gateway.initializeCalls, 0);
    expect(returnedDraft!.photoRelativePath, isNull);
    expect(
      returnedDraft!.fallbackReason,
      PhotoFallbackReason.unsupportedParameter,
    );
  });
}

Future<void> _openPhotoRoute(
  WidgetTester tester, {
  required _FakeCameraGateway gateway,
  required _FakePhotoProcessor processor,
}) async {
  _usePortraitView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhotoCapturePage(
                  request: const PhotoCaptureRequest(
                    tankId: 'tank-1',
                    parameterId: 'parameter-no3',
                    parameterCode: 'NO3',
                    parameterName: '硝酸盐',
                    unit: 'mg/L',
                  ),
                  cameraGateway: gateway,
                  photoProcessor: processor,
                ),
              ),
            ),
            child: const Text('进入拍照'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('进入拍照'));
  await tester.pumpAndSettle();
}

Future<void> _startCameraAndCapture(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('start-camera')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('capture-photo')));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void _usePortraitView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  expect(scrollable, findsWidgets);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: scrollable.first,
    maxScrolls: 20,
  );
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

class _FakeCameraGateway implements CameraGateway {
  _FakeCameraGateway({this.pendingDispose});

  final Completer<void>? pendingDispose;
  var initializeCalls = 0;
  var initialized = false;

  @override
  bool get isInitialized => initialized;

  @override
  double? get previewAspectRatio => 4 / 3;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    initialized = true;
  }

  @override
  Future<void> resume() async => initialized = true;

  @override
  Future<void> suspend() async => initialized = false;

  @override
  Future<String> takePicture() async => '/temporary/capture.jpg';

  @override
  Widget buildPreview() =>
      const ColoredBox(key: Key('fake-camera-preview'), color: Colors.black);

  @override
  Future<void> dispose() async {
    initialized = false;
    final pending = pendingDispose;
    if (pending != null) await pending.future;
  }
}

enum _FakeProcessingOutcome { accepted, rejected, failed }

class _FakePhotoProcessor implements CapturedPhotoProcessor {
  _FakePhotoProcessor({
    this.outcome = _FakeProcessingOutcome.accepted,
    this.pendingResult,
  });

  final _FakeProcessingOutcome outcome;
  final Completer<PhotoProcessingResult>? pendingResult;
  final processedPaths = <String>[];
  final discardedSources = <String>[];
  final deletedStoredPhotos = <StoredPhoto>[];

  static const qualityReport = PhotoQualityReport(
    width: 1200,
    height: 1600,
    meanLuminance: 128,
    darkPixelFraction: 0.01,
    brightPixelFraction: 0.01,
    laplacianVariance: 240,
    issues: [],
  );

  final storedPhoto = StoredPhoto(
    relativePath: 'water_quality_photos/test.jpg',
    absolutePath: 'missing-test-photo.jpg',
    width: 1200,
    height: 1600,
    byteLength: 1000,
    capturedAtUtc: DateTime.utc(2026, 8, 12),
    qualityReport: qualityReport,
  );

  @override
  Future<PhotoProcessingResult> process(String sourcePath) async {
    processedPaths.add(sourcePath);
    final pending = pendingResult;
    if (pending != null) return pending.future;
    return switch (outcome) {
      _FakeProcessingOutcome.accepted => PhotoProcessingResult.accepted(
        storedPhoto,
      ),
      _FakeProcessingOutcome.rejected => PhotoProcessingResult.rejected(
        qualityReport: qualityReport,
        retainedSourcePath: sourcePath,
      ),
      _FakeProcessingOutcome.failed => PhotoProcessingResult.failed(
        message: '测试处理失败',
        retainedSourcePath: sourcePath,
      ),
    };
  }

  @override
  Future<void> discardSource(String sourcePath) async {
    discardedSources.add(sourcePath);
  }

  @override
  Future<void> deleteStoredPhoto(StoredPhoto photo) async {
    deletedStoredPhotos.add(photo);
  }
}
