import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:lanjiao_water_quality/features/image_estimation/domain/no3_dataset_manifest.dart';
import 'package:path/path.dart' as path;

import '../../../tool/support/project_root_locator.dart';

void main() {
  test('当前 NO3 清单可解析、文件哈希一致且不伪造验证指标', () async {
    final projectRoot = await locateProjectRoot();
    final manifestFile = File(
      path.join(projectRoot.path, 'datasets', 'no3', 'manifest_v1.json'),
    );
    final manifest = parseNo3DatasetManifest(await manifestFile.readAsString());

    expect(manifest.datasetId, 'eal-no3-local-v1');
    expect(manifest.samples, isNotEmpty);
    expect(manifest.validationSampleCount, 0);
    expect(manifest.eligibleValidationSampleCount, 0);

    for (final sample in manifest.samples) {
      final image = File(
        path.normalize(
          path.join(manifestFile.parent.absolute.path, sample.imagePath),
        ),
      );
      expect(await image.exists(), isTrue);
      final bytes = await image.readAsBytes();
      expect(sha256.convert(bytes).toString(), sample.sha256);
      final decoded = image_codec.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect((decoded!.width, decoded.height), (sample.width, sample.height));
    }
  });

  test('同批次跨调参与验证集会被拒绝', () {
    const source = '''
{
  "schemaVersion": 1,
  "datasetId": "test",
  "parameter": "NO3",
  "unit": "mg/L",
  "reagentBrand": "test",
  "supportedLevels": [0, 1],
  "splitRule": "batch isolated",
  "samples": [
    {
      "id": "a", "batchId": "same", "split": "tuning",
      "imagePath": "a.jpg",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "width": 1, "height": 1,
      "label": {"minimum": 0, "maximum": 0},
      "reagentLot": null, "cardVersion": null, "device": null,
      "lighting": null, "capturedAt": null,
      "regionsAnnotated": false,
      "eligibleForFinalEvaluation": false,
      "exclusionReasons": ["missing"]
    },
    {
      "id": "b", "batchId": "same", "split": "validation",
      "imagePath": "b.jpg",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "width": 1, "height": 1,
      "label": {"minimum": 1, "maximum": 1},
      "reagentLot": null, "cardVersion": null, "device": null,
      "lighting": null, "capturedAt": null,
      "regionsAnnotated": false,
      "eligibleForFinalEvaluation": false,
      "exclusionReasons": ["missing"]
    }
  ]
}
''';
    expect(() => parseNo3DatasetManifest(source), throwsFormatException);
  });
}
