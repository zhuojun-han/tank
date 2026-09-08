import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../domain/fish_stock.dart';

class FishStockRepository {
  FishStockRepository(this._database, {this.uuid = const Uuid()});

  final AppDatabase _database;
  final Uuid uuid;

  String createId() => uuid.v4();

  Stream<List<FishStockItem>> watchForTank(String tankId) {
    final query = _database.select(_database.appPreferences)
      ..where((table) => table.id.equals(1));
    return query.watchSingle().map((preference) {
      return [
        for (final item in FishStockCodec.decode(preference.fishStockJson))
          if (item.tankId == tankId) item,
      ];
    });
  }

  Future<void> replaceForTank({
    required String tankId,
    required List<FishStockItem> items,
  }) async {
    await _database.transaction(() async {
      final tank = await (_database.select(
        _database.tanks,
      )..where((table) => table.id.equals(tankId))).getSingleOrNull();
      if (tank == null || tank.isArchived) {
        throw StateError('目标海缸不存在或已归档');
      }
      final preference = await (_database.select(
        _database.appPreferences,
      )..where((table) => table.id.equals(1))).getSingle();
      final retained = [
        for (final item in FishStockCodec.decode(preference.fishStockJson))
          if (item.tankId != tankId) item,
      ];
      final normalized = [
        for (final item in items) item.copyWith(tankId: tankId),
      ];
      final encoded = FishStockCodec.encode([...retained, ...normalized]);
      await (_database.update(
        _database.appPreferences,
      )..where((table) => table.id.equals(1))).write(
        AppPreferencesCompanion(
          fishStockJson: Value(encoded),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }
}
