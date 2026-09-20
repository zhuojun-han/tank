import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/card_color_match.dart';
import '../data/card_photo_processor.dart';
import 'photo_color_match_editor.dart';
import '../../test_timer/presentation/test_workflow_widgets.dart';

import '../data/camera_gateway.dart';
import '../data/captured_photo_processor.dart';
import '../domain/photo_capture_models.dart';

enum _CaptureStage {
  guide,
  openingCamera,
  cameraReady,
  processing,
  rejected,
  confirmation,
  cameraError,
}

class PhotoCapturePage extends StatefulWidget {
  const PhotoCapturePage({
    required this.request,
    this.cameraGateway,
    this.photoProcessor,
    super.key,
  });

  final PhotoCaptureRequest? request;
  final CameraGateway? cameraGateway;
  final CapturedPhotoProcessor? photoProcessor;

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage>
    with WidgetsBindingObserver {
  late final CameraGateway _cameraGateway;
  late final CapturedPhotoProcessor _photoProcessor;

  _CaptureStage _stage = _CaptureStage.guide;
  CameraFailureKind? _cameraFailureKind;
  String? _message;
  String? _retainedSourcePath;
  StoredPhoto? _storedPhoto;
  PhotoQualityReport? _qualityReport;
  bool _cameraWasOpened = false;
  bool _cameraSuspended = false;
  bool _draftCommitted = false;

  @override
  void initState() {
    super.initState();
    _cameraGateway = widget.cameraGateway ?? FlutterCameraGateway();
    _photoProcessor = widget.photoProcessor ?? CardPhotoProcessor();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraWasOpened) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_suspendCamera());
    } else if (state == AppLifecycleState.resumed &&
        (_stage == _CaptureStage.cameraReady ||
            _stage == _CaptureStage.openingCamera)) {
      unawaited(_resumeCamera());
    }
  }

  Future<void> _suspendCamera() async {
    if (_cameraSuspended) return;
    _cameraSuspended = true;
    try {
      await _cameraGateway.suspend();
    } catch (_) {
      // Lifecycle cleanup is best-effort; resuming will provide a visible error.
    }
  }

  Future<void> _resumeCamera() async {
    if (!_cameraSuspended || !mounted) return;
    setState(() => _stage = _CaptureStage.openingCamera);
    try {
      await _cameraGateway.resume();
      _cameraSuspended = false;
      if (mounted) setState(() => _stage = _CaptureStage.cameraReady);
    } on CameraGatewayException catch (error) {
      _showCameraError(error);
    } catch (_) {
      _showCameraError(
        const CameraGatewayException(
          CameraFailureKind.unavailable,
          '相机恢复失败，请重试或改为手动录入。',
        ),
      );
    }
  }

  Future<void> _openCamera() async {
    setState(() {
      _stage = _CaptureStage.openingCamera;
      _message = null;
      _cameraFailureKind = null;
    });
    try {
      await _cameraGateway.initialize();
      _cameraWasOpened = true;
      _cameraSuspended = false;
      if (mounted) setState(() => _stage = _CaptureStage.cameraReady);
    } on CameraGatewayException catch (error) {
      _showCameraError(error);
    } catch (_) {
      _showCameraError(
        const CameraGatewayException(
          CameraFailureKind.unavailable,
          '相机初始化失败，请重试或改为手动录入。',
        ),
      );
    }
  }

  void _showCameraError(CameraGatewayException error) {
    if (!mounted) return;
    setState(() {
      _stage = _CaptureStage.cameraError;
      _cameraFailureKind = error.kind;
      _message = error.userMessage;
    });
  }

  Future<void> _capture() async {
    setState(() {
      _stage = _CaptureStage.processing;
      _message = null;
    });
    String? sourcePath;
    try {
      sourcePath = await _cameraGateway.takePicture();
      if (!mounted) {
        await _photoProcessor.discardSource(sourcePath);
        return;
      }
      final result = await _photoProcessor.process(sourcePath);
      if (!mounted) {
        await _discardUncommittedResult(result);
        return;
      }
      switch (result.status) {
        case PhotoProcessingStatus.accepted:
          _storedPhoto = result.storedPhoto;
          _qualityReport = result.qualityReport;
          await _suspendCamera();
          if (mounted) setState(() => _stage = _CaptureStage.confirmation);
          break;
        case PhotoProcessingStatus.rejected:
          _retainedSourcePath = result.retainedSourcePath;
          setState(() {
            _qualityReport = result.qualityReport;
            _stage = _CaptureStage.rejected;
          });
          break;
        case PhotoProcessingStatus.failed:
          _retainedSourcePath = result.retainedSourcePath;
          setState(() {
            _qualityReport = null;
            _message = result.failureMessage;
            _stage = _CaptureStage.rejected;
          });
          break;
      }
    } on CameraGatewayException catch (error) {
      await _retainOrDiscardThrownSource(sourcePath);
      if (!mounted) return;
      _showCameraError(error);
    } catch (_) {
      await _retainOrDiscardThrownSource(sourcePath);
      if (!mounted) return;
      setState(() {
        _message = '拍照处理失败，请重试或改为手动录入。';
        _stage = _CaptureStage.rejected;
      });
    }
  }

  Future<void> _retainOrDiscardThrownSource(String? sourcePath) async {
    if (sourcePath == null) return;
    if (mounted) {
      _retainedSourcePath = sourcePath;
    } else {
      await _photoProcessor.discardSource(sourcePath);
    }
  }

  Future<void> _discardUncommittedResult(PhotoProcessingResult result) async {
    switch (result.status) {
      case PhotoProcessingStatus.accepted:
        final stored = result.storedPhoto;
        if (stored != null) await _photoProcessor.deleteStoredPhoto(stored);
        break;
      case PhotoProcessingStatus.rejected:
      case PhotoProcessingStatus.failed:
        final retained = result.retainedSourcePath;
        if (retained != null) await _photoProcessor.discardSource(retained);
        break;
    }
  }

  Future<void> _retake() async {
    final retained = _retainedSourcePath;
    _retainedSourcePath = null;
    if (retained != null) await _photoProcessor.discardSource(retained);
    final stored = _storedPhoto;
    _storedPhoto = null;
    if (stored != null) await _photoProcessor.deleteStoredPhoto(stored);
    _qualityReport = null;
    _message = null;
    if (_cameraSuspended) {
      await _resumeCamera();
    } else if (mounted) {
      setState(() => _stage = _CaptureStage.cameraReady);
    }
  }

  Future<void> _finishManual(PhotoFallbackReason reason) async {
    final request = widget.request;
    if (request == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    await _discardUncommittedArtifacts();
    await _cameraGateway.dispose();
    if (!mounted) return;
    _draftCommitted = true;
    Navigator.of(
      context,
    ).pop(PhotoEstimationDraft.manualOnly(request: request, reason: reason));
  }

  Future<void> _confirmResult(ColorMatchResult result) async {
    final request = widget.request;
    final photo = _storedPhoto;
    if (request == null || photo == null) return;
    final draft = PhotoEstimationDraft(
      tankId: request.tankId,
      parameterId: request.parameterId,
      parameterCode: request.parameterCode,
      unit: request.unit,
      createdAtUtc: DateTime.now().toUtc(),
      photoCapturedAtUtc: photo.capturedAtUtc,
      qualityReport: photo.qualityReport,
      colorMatch: result,
    );
    _storedPhoto = null;
    await _photoProcessor.deleteStoredPhoto(photo);
    await _cameraGateway.dispose();
    if (!mounted) return;
    _draftCommitted = true;
    Navigator.of(context).pop(draft);
  }

  Future<void> _choosePhoto() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '照片',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    setState(() => _stage = _CaptureStage.processing);
    String? copied;
    try {
      final temp = await getTemporaryDirectory();
      copied =
          '${temp.path}/color-import-${DateTime.now().microsecondsSinceEpoch}';
      await file.saveTo(copied);
      final result = await _photoProcessor.process(copied);
      if (!mounted) {
        if (result.storedPhoto != null) {
          await _photoProcessor.deleteStoredPhoto(result.storedPhoto!);
        } else {
          await _photoProcessor.discardSource(copied);
        }
        return;
      }
      setState(() {
        _storedPhoto = result.storedPhoto;
        _qualityReport = result.qualityReport;
        _retainedSourcePath = result.retainedSourcePath;
        _message = result.failureMessage;
        _stage = result.storedPhoto == null
            ? _CaptureStage.rejected
            : _CaptureStage.confirmation;
      });
    } catch (_) {
      if (copied != null) await _photoProcessor.discardSource(copied);
      if (mounted) {
        setState(() {
          _message = '无法读取照片，请重新选择。';
          _stage = _CaptureStage.rejected;
        });
      }
    }
  }

  PhotoFallbackReason _cameraFallbackReason() {
    switch (_cameraFailureKind) {
      case CameraFailureKind.permissionDenied:
      case CameraFailureKind.permissionRestricted:
        return PhotoFallbackReason.cameraPermissionDenied;
      case CameraFailureKind.noRearCamera:
      case CameraFailureKind.unavailable:
      case CameraFailureKind.captureFailed:
      case null:
        return PhotoFallbackReason.cameraUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('拍照检测')),
      body: SafeArea(
        child: request == null
            ? _MissingRequest(onBack: () => Navigator.of(context).maybePop())
            : !request.supportsManualPhotoComparison
            ? _UnsupportedParameter(
                request: request,
                onManual: () =>
                    _finishManual(PhotoFallbackReason.unsupportedParameter),
              )
            : switch (_stage) {
                _CaptureStage.guide => _Guide(
                  request: request,
                  onStartCamera: _openCamera,
                  onChoosePhoto: _choosePhoto,
                  onManual: () =>
                      _finishManual(PhotoFallbackReason.userChoseManual),
                ),
                _CaptureStage.openingCamera ||
                _CaptureStage.processing => _Progress(
                  label: _stage == _CaptureStage.openingCamera
                      ? '正在准备后置摄像头…'
                      : '正在本机检查临时照片…',
                ),
                _CaptureStage.cameraReady => _CameraView(
                  gateway: _cameraGateway,
                  onCapture: _capture,
                  onManual: () =>
                      _finishManual(PhotoFallbackReason.userChoseManual),
                ),
                _CaptureStage.rejected => _RejectedView(
                  report: _qualityReport,
                  message: _message,
                  onRetake: _retake,
                  onManual: () =>
                      _finishManual(PhotoFallbackReason.qualityRejected),
                ),
                _CaptureStage.confirmation => PhotoColorMatchEditor(
                  path: _storedPhoto!.absolutePath,
                  parameter: request.parameterCode,
                  onConfirm: _confirmResult,
                  onRetake: _retake,
                  onManual: () =>
                      _finishManual(PhotoFallbackReason.userChoseManual),
                ),
                _CaptureStage.cameraError => _CameraErrorView(
                  message: _message ?? '相机不可用。',
                  onRetry: _openCamera,
                  onManual: () => _finishManual(_cameraFallbackReason()),
                ),
              },
      ),
    );
  }

  Future<void> _discardUncommittedArtifacts() async {
    if (_draftCommitted) return;
    final retained = _retainedSourcePath;
    _retainedSourcePath = null;
    if (retained != null) await _photoProcessor.discardSource(retained);
    final stored = _storedPhoto;
    _storedPhoto = null;
    if (stored != null) await _photoProcessor.deleteStoredPhoto(stored);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_draftCommitted) unawaited(_discardUncommittedArtifacts());
    unawaited(_cameraGateway.dispose());
    super.dispose();
  }
}

class _MissingRequest extends StatelessWidget {
  const _MissingRequest({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off, size: 48),
          const SizedBox(height: 12),
          Text('无法开始拍照', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('请返回检测页选择海缸和参数。'),
          const SizedBox(height: 20),
          FilledButton(onPressed: onBack, child: const Text('返回')),
        ],
      ),
    ),
  );
}

class _UnsupportedParameter extends StatelessWidget {
  const _UnsupportedParameter({required this.request, required this.onManual});

  final PhotoCaptureRequest request;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            '${request.parameterCode} 暂不支持拍照比色',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('此参数请使用手动录入。'),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('unsupported-manual-entry'),
            onPressed: onManual,
            child: const Text('返回手动录入'),
          ),
        ],
      ),
    ),
  );
}

class _Guide extends StatelessWidget {
  const _Guide({
    required this.request,
    required this.onStartCamera,
    required this.onChoosePhoto,
    required this.onManual,
  });
  final PhotoCaptureRequest request;
  final VoidCallback onStartCamera, onChoosePhoto, onManual;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
    children: [
      Text(
        '${request.parameterCode} 照片辅助比色',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      TestPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择照片', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('显色后，将完整色卡和测试液放在同一光线下，避开反光。'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 48),
                  SizedBox(height: 10),
                  Text('测试液与完整色卡同框'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('start-camera'),
              onPressed: onStartCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('打开相机'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onChoosePhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('选择照片'),
            ),
          ],
        ),
      ),
      TestEntryCard(
        title: '手动录入',
        subtitle: '填写检测结果并确认是否记录',
        icon: Icons.keyboard_outlined,
        onTap: onManual,
      ),
      const SizedBox(height: 12),
      const Text('仅供参考', textAlign: TextAlign.center),
    ],
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label),
      ],
    ),
  );
}

class _CameraView extends StatelessWidget {
  const _CameraView({
    required this.gateway,
    required this.onCapture,
    required this.onManual,
  });

  final CameraGateway gateway;
  final VoidCallback onCapture;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return Column(
      children: [
        if (!portrait)
          MaterialBanner(
            content: const Text('请将手机竖直后拍摄，确保色卡和试管完整入镜。'),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: gateway.buildPreview(),
                      ),
                      const IgnorePointer(
                        child: CustomPaint(painter: _GuidePainter()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('完整色卡放入大框，试管放入右侧窄框；避免遮挡色块和数字。'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onManual,
                  child: const Text('手动录入'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('capture-photo'),
                  onPressed: portrait ? onCapture : null,
                  icon: const Icon(Icons.camera),
                  label: const Text('拍照'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.17,
        size.width * 0.84,
        size.height * 0.48,
      ),
      const Radius.circular(12),
    );
    final tube = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.62,
        size.height * 0.24,
        size.width * 0.16,
        size.height * 0.52,
      ),
      const Radius.circular(20),
    );
    canvas.drawRRect(card, paint);
    canvas.drawRRect(tube, paint..color = Colors.cyanAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({
    required this.report,
    required this.message,
    required this.onRetake,
    required this.onManual,
  });

  final PhotoQualityReport? report;
  final String? message;
  final VoidCallback onRetake;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.photo_camera_back_outlined, size: 52),
      const SizedBox(height: 12),
      Text('这张照片暂不适合比色', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (message != null) Text(message!),
      if (report != null)
        for (final issue in report!.issues)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(issue.explanation),
          ),
      const SizedBox(height: 8),

      const SizedBox(height: 20),
      FilledButton.icon(
        key: const Key('retake-photo'),
        onPressed: onRetake,
        icon: const Icon(Icons.refresh),
        label: const Text('重新拍摄'),
      ),
      TextButton(onPressed: onManual, child: const Text('改为手动录入')),
    ],
  );
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('重试相机')),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('camera-error-manual-entry'),
            onPressed: onManual,
            child: const Text('继续手动录入'),
          ),
        ],
      ),
    ),
  );
}
