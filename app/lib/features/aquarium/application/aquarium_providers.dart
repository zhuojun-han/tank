import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tanks/application/tank_providers.dart';
import '../data/fish_stock_repository.dart';

final fishStockRepositoryProvider = Provider<FishStockRepository>((ref) {
  return FishStockRepository(ref.watch(appDatabaseProvider));
});

final fishStockProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(fishStockRepositoryProvider).watchForTank(tankId);
});
