import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image_codec;
import 'package:lanjiao_water_quality/features/image_estimation/domain/no3_dataset_manifest.dart';
import 'package:path/path.dart' as path;

import 'support/project_root_locator.dart';

Future<void> main(List<String> arguments) async {
  final projectRoot = arguments.isEmpty ? await locateProjectRoot() : null;
  final manifestPath = path.normalize(
    arguments.isEmpty
        ? path.join(projectRoot!.path, 'datasets', 'no3', 'manifest_v1.json')
        : arguments.single,
  );
  final manifestFile = File(manifestPath);
  final manifest = parseNo3DatasetManifest(await manifestFile.readAsString());
  final manifestDirectory = manifestFile.parent.absolute.path;
  final failures = <String>[];
  for (final sample in manifest.samples) {
    final image = File(
      path.normalize(path.join(manifestDirectory, sample.imagePath)),
    );
    if (!await image.exists()) {
      failures.add('${sample.id}: 图片不存在');
      continue;
    }
    final bytes = await image.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    if (digest != sample.sha256) failures.add('${sample.id}: SHA-256 不匹配');
    final decoded = image_codec.decodeImage(bytes);
    if (decoded == null) {
      failures.add('${sample.id}: 图片无法解码');
    } else if (decoded.width != sample.width ||
        decoded.height != sample.height) {
      failures.add(
        '${sample.id}: 图片尺寸 ${decoded.width}x${decoded.height} '
        '与清单 ${sample.width}x${sample.height} 不一致',
      );
    }
  }

  final report = <String, Object?>{
    'datasetId': manifest.datasetId,
    'schemaVersion': manifest.schemaVersion,
    'samples': manifest.samples.length,
    'validationSamples': manifest.validationSampleCount,
    'eligibleValidationSamples': manifest.eligibleValidationSampleCount,
    'fileIntegrityPassed': failures.isEmpty,
    'failures': failures,
    'metricsComputable': manifest.eligibleValidationSampleCount > 0,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  if (failures.isNotEmpty) exitCode = 1;
}
