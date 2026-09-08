import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/data/fish_stock_repository.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('内置鱼种目录包含 20 种独立立绘', () {
    expect(builtinFishCatalog.map((species) => species.name), [
      '小丑鱼',
      '双斑宝石海金鱼（公）',
      '双斑宝石海金鱼（母）',
      '蓝眼海金鱼（公）',
      '深水樱花宝石',
      '火焰仙',
      '紫吊',
      '粉蓝吊',
      '东非金剪刀',
      '蓝吊',
      '黄狐狸',
      '拉马克',
      '番茄小丑',
      '关刀',
      '皇后',
      '马鞍',
      '金毛巾',
      '蓝面',
      '紫罗兰',
      '黄金吊',
    ]);
    expect(
      builtinFishCatalog.map((species) => species.asset).toSet(),
      hasLength(20),
    );
    expect(
      builtinFishSpeciesFor(FishArtworkKind.builtinPowderBlueTang).name,
      '粉蓝吊',
    );
  });

  test('鱼类档案编码保留内置与自定义立绘并拒绝无效数据', () {
    final items = [
      FishStockItem(
        id: 'clownfish',
        tankId: 'tank',
        species: builtinClownfishSpecies,
        quantity: 2,
        introducedOn: DateTime.utc(2026, 8, 31),
        artworkKind: FishArtworkKind.builtinClownfish,
      ),
      FishStockItem(
        id: 'custom',
        tankId: 'tank',
        species: '蓝吊',
        quantity: 1,
        introducedOn: DateTime.utc(2026, 8, 30),
        artworkKind: FishArtworkKind.custom,
        artworkMimeType: 'image/webp',
        artworkBase64: base64Encode([1, 2, 3, 4]),
      ),
      FishStockItem(
        id: 'purple-tang',
        tankId: 'tank',
        species: '紫吊',
        quantity: 1,
        introducedOn: DateTime.utc(2026, 9, 4),
        artworkKind: FishArtworkKind.builtinPurpleTang,
      ),
    ];

    final restored = FishStockCodec.decode(FishStockCodec.encode(items));

    expect(restored, hasLength(3));
    expect(restored.first.quantity, 2);
    expect(restored[1].species, '蓝吊');
    expect(restored[1].customArtworkBytes, [1, 2, 3, 4]);
    expect(restored.last.artworkKind, FishArtworkKind.builtinPurpleTang);
    expect(
      () => FishStockCodec.decode(
        jsonEncode([
          {...items.last.toJson(), 'artworkBase64': 'not-valid-base64***'},
        ]),
      ),
      throwsFormatException,
    );
  });

  test('鱼类仓库按海缸隔离并让完整备份恢复自定义立绘', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final tanks = TankRepository(database);
    final repository = FishStockRepository(database);
    final secondTankId = await tanks.createTank(name: '第二海缸');
    final firstArtwork = base64Encode([10, 20, 30, 40]);
    await repository.replaceForTank(
      tankId: AppDatabase.defaultTankId,
      items: [
        FishStockItem(
          id: 'custom-fish',
          tankId: AppDatabase.defaultTankId,
          species: '自定义鱼',
          quantity: 3,
          introducedOn: DateTime.utc(2026, 8, 31),
          artworkKind: FishArtworkKind.custom,
          artworkMimeType: 'image/webp',
          artworkBase64: firstArtwork,
        ),
      ],
    );
    await repository.replaceForTank(
      tankId: secondTankId,
      items: [
        FishStockItem(
          id: 'clownfish-second',
          tankId: secondTankId,
          species: builtinClownfishSpecies,
          quantity: 1,
          introducedOn: DateTime.utc(2026, 8, 30),
          artworkKind: FishArtworkKind.builtinClownfish,
        ),
      ],
    );

    expect(
      (await repository.watchForTank(AppDatabase.defaultTankId).first)
          .single
          .quantity,
      3,
    );
    expect(
      (await repository.watchForTank(secondTankId).first).single.species,
      builtinClownfishSpecies,
    );

    final json = await LocalBackupService(database).exportJson();
    expect((jsonDecode(json) as Map<String, dynamic>)['formatVersion'], 12);
    final restoredDatabase = AppDatabase(NativeDatabase.memory());
    addTearDown(restoredDatabase.close);
    await LocalBackupService(restoredDatabase).restoreReplace(json);
    final restored = await FishStockRepository(
      restoredDatabase,
    ).watchForTank(AppDatabase.defaultTankId).first;
    expect(restored.single.artworkBase64, firstArtwork);
    expect(restored.single.customArtworkBytes, [10, 20, 30, 40]);
  });

  test('所有新增内置鱼种通过整库备份恢复并保留海缸归属', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final added = builtinFishCatalog.skip(9).toList();
    final items = [
      for (var index = 0; index < added.length; index++)
        FishStockItem(
          id: 'added-fish-$index',
          tankId: AppDatabase.defaultTankId,
          species: added[index].name,
          quantity: index + 1,
          introducedOn: DateTime.utc(2026, 9, 8),
          artworkKind: added[index].kind,
        ),
    ];
    await FishStockRepository(
      source,
    ).replaceForTank(tankId: AppDatabase.defaultTankId, items: items);
    await LocalBackupService(
      destination,
    ).restoreReplace(await LocalBackupService(source).exportJson());
    final restored = await FishStockRepository(
      destination,
    ).watchForTank(AppDatabase.defaultTankId).first;
    expect(restored, hasLength(11));
    for (final item in items) {
      final actual = restored.singleWhere((row) => row.id == item.id);
      expect(actual.toJson(), item.toJson());
      expect(builtinFishSpeciesFor(actual.artworkKind).name, item.species);
    }
  });

  test('v7 备份恢复时鱼类档案默认为空', () async {
    final source = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    final decoded =
        jsonDecode(await LocalBackupService(source).exportJson())
            as Map<String, dynamic>;
    decoded['formatVersion'] = 7;
    final preference =
        (decoded['appPreferences'] as List).single as Map<String, dynamic>;
    preference.remove('fishStockJson');

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await LocalBackupService(target).restoreReplace(jsonEncode(decoded));
    expect(
      await FishStockRepository(
        target,
      ).watchForTank(AppDatabase.defaultTankId).first,
      isEmpty,
    );
  });
}
