import 'alkalinity_calculator.dart';
import 'lanthanum_calculator.dart';

enum DosingChemical { po4, kh }

enum PumpFlowUnit { mlPerSecond, mlPerMinute }

class MaintenanceDosingResult {
  const MaintenanceDosingResult({
    this.volumeMl = 500,
    required this.dailyStockMl,
    required this.dailyLiquidMl,
    required this.actualDays,
    required this.stockMl,
    this.khConcentrationGPerL,
  });
  final double volumeMl;
  final double dailyStockMl, dailyLiquidMl, actualDays, stockMl;
  final double? khConcentrationGPerL;
  bool get feasible => stockMl <= volumeMl;
}

/// Uses the actual reservoir duration described in MAINTENANCE_DOSING_CALCULATOR.md.
/// Only the selected reagent is validated; no hardware control or efficiency correction.
MaintenanceDosingResult calculateMaintenanceDosing({
  required DosingChemical chemical,
  double waterL = 200,
  double volumeMl = 500,
  required double dailyChange,
  double flow = 1.4,
  double minutes = 1,
  PumpFlowUnit unit = PumpFlowUnit.mlPerSecond,
  int khStrength = 6,
  double khPurity = 100,
  double temperature = 20,
}) {
  if ([waterL, dailyChange, flow, minutes].any((v) => !v.isFinite || v < 0) ||
      waterL <= 0 ||
      flow <= 0 ||
      minutes <= 0) {
    throw const FormatException('请填写有效数值；净水量、流速和运行时间必须大于 0，每日变化须非负。');
  }
  double? concentration;
  if (chemical == DosingChemical.kh) {
    if (!alkalinityStockMlOptions.contains(khStrength) ||
        !khPurity.isFinite ||
        khPurity <= 0 ||
        khPurity > 100) {
      throw const FormatException('请核对 KH 母液档位和纯度（大于 0 且不超过 100%）。');
    }
    concentration =
        gramsPurePer100LPerDkh * 100 / khStrength / (khPurity / 100);
    final limit = sodiumBicarbonateSolubilityAt(temperature) * 10 * 0.8;
    if (concentration > limit + 1e-12) {
      throw const FormatException('KH 母液超过该温度下的溶解度余量，请选择更稀的档位或核对最低温度。');
    }
  }
  final dailyStock = chemical == DosingChemical.po4
      ? dailyChange * waterL / stockPo4RemovalMgPerMl
      : dailyChange * waterL / 100 / 0.1 * khStrength;
  final dailyLiquid =
      flow * (unit == PumpFlowUnit.mlPerSecond ? 60 : 1) * minutes;
  if (!volumeMl.isFinite || volumeMl <= 0) {
    throw const FormatException('溶液体积必须大于 0');
  }
  final actualDays = volumeMl / dailyLiquid;
  final stock = dailyStock * actualDays;
  if ([dailyStock, dailyLiquid, actualDays, stock].any((v) => !v.isFinite) ||
      dailyLiquid <= 0 ||
      actualDays <= 0) {
    throw const FormatException('输入超出可计算范围，请核对数值。');
  }
  return MaintenanceDosingResult(
    volumeMl: volumeMl,
    dailyStockMl: dailyStock,
    dailyLiquidMl: dailyLiquid,
    actualDays: actualDays,
    stockMl: stock,
    khConcentrationGPerL: concentration,
  );
}
