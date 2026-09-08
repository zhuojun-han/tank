import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CameraFailureKind {
  permissionDenied,
  permissionRestricted,
  noRearCamera,
  unavailable,
  captureFailed,
}

class CameraGatewayException implements Exception {
  const CameraGatewayException(this.kind, this.userMessage);

  final CameraFailureKind kind;
  final String userMessage;

  @override
  String toString() => userMessage;
}

abstract class CameraGateway {
  bool get isInitialized;

  double? get previewAspectRatio;

  Future<void> initialize();

  Future<void> suspend();

  Future<void> resume();

  Future<String> takePicture();

  Widget buildPreview();

  Future<void> dispose();
}

class FlutterCameraGateway implements CameraGateway {
  camera.CameraDescription? _rearCamera;
  camera.CameraController? _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  double? get previewAspectRatio =>
      isInitialized ? _controller!.value.aspectRatio : null;

  @override
  Future<void> initialize() async {
    try {
      final cameras = await camera.availableCameras();
      for (final candidate in cameras) {
        if (candidate.lensDirection == camera.CameraLensDirection.back) {
          _rearCamera = candidate;
          break;
        }
      }
      if (_rearCamera == null) {
        throw const CameraGatewayException(
          CameraFailureKind.noRearCamera,
          '没有可用的后置摄像头，请改为手动录入。',
        );
      }
      await _open(_rearCamera!);
    } on CameraGatewayException {
      rethrow;
    } on camera.CameraException catch (error) {
      throw _translate(error);
    } catch (_) {
      throw const CameraGatewayException(
        CameraFailureKind.unavailable,
        '相机暂时不可用，请稍后重试或改为手动录入。',
      );
    }
  }

  Future<void> _open(camera.CameraDescription description) async {
    await _controller?.dispose();
    final next = camera.CameraController(
      description,
      camera.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: camera.ImageFormatGroup.jpeg,
    );
    _controller = next;
    try {
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await next.setFlashMode(camera.FlashMode.off);
    } on camera.CameraException catch (error) {
      await next.dispose();
      if (identical(_controller, next)) _controller = null;
      throw _translate(error);
    }
  }

  @override
  Future<void> suspend() async {
    final current = _controller;
    _controller = null;
    await current?.dispose();
  }

  @override
  Future<void> resume() async {
    if (isInitialized) return;
    final description = _rearCamera;
    if (description == null) {
      await initialize();
      return;
    }
    await _open(description);
  }

  @override
  Future<String> takePicture() async {
    final current = _controller;
    if (current == null || !current.value.isInitialized) {
      throw const CameraGatewayException(
        CameraFailureKind.unavailable,
        '相机尚未准备好，请稍后重试。',
      );
    }
    if (current.value.isTakingPicture) {
      throw const CameraGatewayException(
        CameraFailureKind.captureFailed,
        '正在保存上一张照片，请稍候。',
      );
    }
    try {
      final capture = await current.takePicture();
      return capture.path;
    } on camera.CameraException catch (error) {
      throw _translate(error, duringCapture: true);
    }
  }

  @override
  Widget buildPreview() {
    final current = _controller;
    if (current == null || !current.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return camera.CameraPreview(current);
  }

  @override
  Future<void> dispose() => suspend();

  CameraGatewayException _translate(
    camera.CameraException error, {
    bool duringCapture = false,
  }) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return const CameraGatewayException(
          CameraFailureKind.permissionDenied,
          '相机权限未开启。你仍可手动录入；如需拍照，请在系统设置中允许相机权限。',
        );
      case 'CameraAccessRestricted':
        return const CameraGatewayException(
          CameraFailureKind.permissionRestricted,
          '当前设备限制了相机访问，请改为手动录入。',
        );
      default:
        return CameraGatewayException(
          duringCapture
              ? CameraFailureKind.captureFailed
              : CameraFailureKind.unavailable,
          duringCapture ? '拍照失败，请重试或改为手动录入。' : '相机初始化失败，请重试或改为手动录入。',
        );
    }
  }
}
