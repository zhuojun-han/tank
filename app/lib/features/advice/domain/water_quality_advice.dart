enum WaterQualityAdviceStatus {
  insufficientData,
  belowTarget,
  withinTarget,
  aboveTarget,
  retestRequired,
  unsupportedParameter,
}

class ConfirmedMeasurement {
  const ConfirmedMeasurement({
    required this.recordId,
    required this.minValue,
    this.maxValue,
    required this.unit,
    required this.measuredAt,
  });

  final String recordId;
  final double minValue;
  final double? maxValue;
  final String unit;
  final DateTime measuredAt;

  double get upperValue => maxValue ?? minValue;
}

class UserTargetRange {
  const UserTargetRange({
    required this.minValue,
    required this.maxValue,
    required this.unit,
  });

  final double minValue;
  final double maxValue;
  final String unit;
}

class WaterQualityAdviceInput {
  const WaterQualityAdviceInput({
    required this.parameterId,
    required this.parameterCode,
    required this.parameterName,
    this.latestConfirmedRecord,
    this.userTarget,
  });

  final String parameterId;
  final String parameterCode;
  final String parameterName;
  final ConfirmedMeasurement? latestConfirmedRecord;
  final UserTargetRange? userTarget;
}

class AdviceRuleSource {
  const AdviceRuleSource({required this.title, required this.url});

  final String title;
  final String url;
}

class WaterQualityAdvice {
  const WaterQualityAdvice({
    required this.parameterId,
    required this.parameterCode,
    required this.parameterName,
    required this.status,
    required this.title,
    required this.summary,
    required this.trigger,
    required this.actions,
    required this.sources,
    required this.latestConfirmedRecord,
    required this.userTarget,
  });

  final String parameterId;
  final String parameterCode;
  final String parameterName;
  final WaterQualityAdviceStatus status;
  final String title;
  final String summary;
  final String trigger;
  final List<String> actions;
  final List<AdviceRuleSource> sources;
  final ConfirmedMeasurement? latestConfirmedRecord;
  final UserTargetRange? userTarget;
}

abstract final class WaterQualityAdviceEngine {
  static const safetyBoundary =
      '建议仅用于辅助日常维护，不能替代规范复测、专业诊断或对缸内生物的持续观察。'
      '首版不提供具体药剂剂量；任何调整都应从小幅变化开始，并在复测和观察后决定下一步。';

  static const _redSea = AdviceRuleSource(
    title: 'Red Sea · Algae Management Program',
    url:
        'https://redseafish.com/wp-content/uploads/2013/12/'
        'Algae-management-Program_Multilanguage-Manual_GB_DE_FR_SE_NL_SP_PT_JP_CH_17A.pdf',
  );
  static const _tropicNutrient = AdviceRuleSource(
    title: 'Tropic Marin · Nutrient Control',
    url: 'https://www.tropic-marin.com/naehrstoffkontrolle?lang=en',
  );
  static const _tropicPlusNp = AdviceRuleSource(
    title: 'Tropic Marin · Plus-NP',
    url: 'https://calulator.tropic-marin.com/en/control/plus-np.html',
  );
  static const _hanna = AdviceRuleSource(
    title: 'Hanna Instruments · Saltwater Aquarium Water Parameters Guidelines',
    url:
        'https://pages.hannainst.com/hubfs/006-finished-content/Aquarium/'
        'Saltwater-Aquarium-Water-Parameters-Guidelines-1.pdf',
  );

  static WaterQualityAdvice evaluate(WaterQualityAdviceInput input) {
    final code = input.parameterCode.trim().toUpperCase();
    final record = input.latestConfirmedRecord;
    final target = input.userTarget;
    final sources = _sourcesFor(code);

    if (record == null) {
      return _result(
        input,
        status: WaterQualityAdviceStatus.insufficientData,
        title: '$code 数据不足',
        summary: '完成一次检测并保存人工确认结果后，才能生成维护建议。',
        trigger: '当前海缸尚无 $code 人工确认记录。',
        actions: const ['完成一次规范检测', '保存人工确认结果后再查看建议'],
        sources: sources,
      );
    }
    if (!_validMeasurement(record)) {
      return _result(
        input,
        status: WaterQualityAdviceStatus.insufficientData,
        title: '$code 记录需要复核',
        summary: '最近人工确认记录的数值范围无效，不能据此生成维护建议。',
        trigger: '人工确认记录不是有效的非负数值或范围。',
        actions: const ['编辑并复核这条检测记录', '使用有效记录后再查看建议'],
        sources: sources,
      );
    }
    if (target == null) {
      return _result(
        input,
        status: WaterQualityAdviceStatus.insufficientData,
        title: '$code 尚未设置目标',
        summary: '目标范围由你按海缸设置；未设置时不会套用所谓通用最佳值。',
        trigger: '当前海缸尚未设置 $code 用户目标范围。',
        actions: const ['前往设置填写当前海缸的目标范围', '设置后结合最近人工确认结果查看建议'],
        sources: sources,
      );
    }
    if (!_validTarget(target)) {
      return _result(
        input,
        status: WaterQualityAdviceStatus.insufficientData,
        title: '$code 目标需要复核',
        summary: '当前目标范围无效，不能据此生成维护建议。',
        trigger: '用户目标不是有效的非负范围。',
        actions: const ['重新设置当前海缸的目标范围', '保存有效目标后再查看建议'],
        sources: sources,
      );
    }
    if (code != 'NO3' && code != 'PO4') {
      return _result(
        input,
        status: WaterQualityAdviceStatus.unsupportedParameter,
        title: '$code 暂无专用建议规则',
        summary: '当前参数没有已确认的专用规则来源，因此不提供方向性维护调整。',
        trigger: '首版只有 NO3 和 PO4 具备可追溯的专用维护规则。',
        actions: const ['规范复测并持续观察', '查阅可靠资料或咨询有经验的专业人士'],
        sources: const [],
      );
    }

    if (record.upperValue < target.minValue) {
      return code == 'NO3'
          ? _no3Below(input, sources)
          : _po4Below(input, sources);
    }
    if (record.minValue > target.maxValue) {
      return code == 'NO3'
          ? _no3Above(input, sources)
          : _po4Above(input, sources);
    }
    if (record.minValue >= target.minValue &&
        record.upperValue <= target.maxValue) {
      return _result(
        input,
        status: WaterQualityAdviceStatus.withinTarget,
        title: '$code 位于目标范围内',
        summary: '最近人工确认结果位于你的目标范围内。',
        trigger: '人工确认结果整体位于用户目标范围内。',
        actions: const ['保持当前喂食、过滤和维护节奏', '按原计划复测并持续观察'],
        sources: sources,
      );
    }
    return _result(
      input,
      status: WaterQualityAdviceStatus.retestRequired,
      title: '$code 需要复测确认',
      summary: '范围型人工确认结果与目标区间部分重叠，当前不能判定偏高或偏低。',
      trigger: '人工确认范围与用户目标范围部分重叠。',
      actions: const ['在相同条件下规范复测', '核对试剂、显色时间和人工读数'],
      sources: sources,
    );
  }

  static WaterQualityAdvice _no3Above(
    WaterQualityAdviceInput input,
    List<AdviceRuleSource> sources,
  ) => _result(
    input,
    status: WaterQualityAdviceStatus.aboveTarget,
    title: 'NO3 高于目标',
    summary: '最近人工确认结果高于你的目标范围；先复测，再逐步排查输入和累积。',
    trigger: '人工确认结果下界高于用户目标上限。',
    actions: const [
      '复测，并检查残饵或死亡生物',
      '适量减少高营养饲料或单次投喂',
      '清洁机械过滤并检查蛋分运行',
      '采用适量分次换水，避免骤降',
    ],
    sources: sources,
  );

  static WaterQualityAdvice _no3Below(
    WaterQualityAdviceInput input,
    List<AdviceRuleSource> sources,
  ) => _result(
    input,
    status: WaterQualityAdviceStatus.belowTarget,
    title: 'NO3 低于目标',
    summary: '最近人工确认结果低于你的目标范围；不要继续盲目强化营养盐去除。',
    trigger: '人工确认结果上界低于用户目标下限。',
    actions: const [
      '复测，并避免继续加强换水或脱氮',
      '检查碳源等营养盐去除措施',
      '在生物可承受范围内小幅增加喂食',
      '不要盲目添加硝酸盐药剂',
    ],
    sources: sources,
  );

  static WaterQualityAdvice _po4Above(
    WaterQualityAdviceInput input,
    List<AdviceRuleSource> sources,
  ) => _result(
    input,
    status: WaterQualityAdviceStatus.aboveTarget,
    title: 'PO4 高于目标',
    summary: '最近人工确认结果高于你的目标范围；先复测，再排查饲料输入、积污和吸磷材料状态。',
    trigger: '人工确认结果下界高于用户目标上限。',
    actions: const [
      '复测，并检查残饵、底砂和积污',
      '适量减少高磷或荤性饲料及单次投喂',
      '清洁机械过滤并采用适量分次换水',
      '按产品说明检查或更换吸磷材料',
    ],
    sources: sources,
  );

  static WaterQualityAdvice _po4Below(
    WaterQualityAdviceInput input,
    List<AdviceRuleSource> sources,
  ) => _result(
    input,
    status: WaterQualityAdviceStatus.belowTarget,
    title: 'PO4 低于目标',
    summary: '最近人工确认结果低于你的目标范围；继续强力吸磷可能造成营养限制。',
    trigger: '人工确认结果上界低于用户目标下限。',
    actions: const [
      '使用适合低量程的方式复测',
      '避免新增吸磷材料，并酌情降低吸附强度',
      '在生物可承受范围内小幅增加喂食',
      '不要盲目添加磷酸盐',
    ],
    sources: sources,
  );

  static WaterQualityAdvice _result(
    WaterQualityAdviceInput input, {
    required WaterQualityAdviceStatus status,
    required String title,
    required String summary,
    required String trigger,
    required List<String> actions,
    required List<AdviceRuleSource> sources,
  }) => WaterQualityAdvice(
    parameterId: input.parameterId,
    parameterCode: input.parameterCode.trim().toUpperCase(),
    parameterName: input.parameterName,
    status: status,
    title: title,
    summary: summary,
    trigger: trigger,
    actions: actions,
    sources: sources,
    latestConfirmedRecord: input.latestConfirmedRecord,
    userTarget: input.userTarget,
  );

  static List<AdviceRuleSource> _sourcesFor(String code) => switch (code) {
    'NO3' => const [_redSea, _tropicPlusNp, _hanna],
    'PO4' => const [_redSea, _tropicNutrient, _tropicPlusNp, _hanna],
    _ => const [],
  };

  static bool _validMeasurement(ConfirmedMeasurement record) =>
      record.minValue.isFinite &&
      record.minValue >= 0 &&
      record.upperValue.isFinite &&
      record.upperValue >= record.minValue;

  static bool _validTarget(UserTargetRange target) =>
      target.minValue.isFinite &&
      target.minValue >= 0 &&
      target.maxValue.isFinite &&
      target.maxValue >= target.minValue;
}
