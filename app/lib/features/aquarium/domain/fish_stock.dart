import 'dart:convert';
import 'dart:typed_data';

const maximumAnimatedFish = 24;
const maximumFishQuantity = 999;
const maximumFishArtworkInputBytes = 8 * 1024 * 1024;
const maximumFishArtworkBase64Length = 450000;
const builtinClownfishSpecies = '小丑鱼';
const builtinClownfishAsset = 'assets/aquarium/clownfish.png';
const aquariumBackgroundAsset = 'assets/aquarium/reef_tank_soft_cartoon.png';

enum FishArtworkKind {
  builtinClownfish,
  builtinBimaculatusMale,
  builtinBimaculatusFemale,
  builtinSquamipinnisMale,
  builtinBorbonius,
  builtinFlameAngelfish,
  builtinPurpleTang,
  builtinPowderBlueTang,
  builtinMidasBlenny,
  custom,
}

class BuiltinFishSpecies {
  const BuiltinFishSpecies({
    required this.kind,
    required this.name,
    required this.note,
    required this.asset,
  });

  final FishArtworkKind kind;
  final String name;
  final String note;
  final String asset;
}

const builtinFishCatalog = <BuiltinFishSpecies>[
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinClownfish,
    name: builtinClownfishSpecies,
    note: 'A1 轻写实立绘',
    asset: builtinClownfishAsset,
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinBimaculatusMale,
    name: '双斑宝石海金鱼（公）',
    note: '公鱼 · 红紫与金黄斑纹',
    asset: 'assets/aquarium/pseudanthias-bimaculatus-male.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinBimaculatusFemale,
    name: '双斑宝石海金鱼（母）',
    note: '母鱼 · 金黄与粉橙体色',
    asset: 'assets/aquarium/pseudanthias-bimaculatus-female.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinSquamipinnisMale,
    name: '蓝眼海金鱼（公）',
    note: '公鱼 · 延长背鳍棘',
    asset: 'assets/aquarium/pseudanthias-squamipinnis-male.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinBorbonius,
    name: '深水樱花宝石',
    note: '又称发霉鱼',
    asset: 'assets/aquarium/odontanthias-borbonius.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinFlameAngelfish,
    name: '火焰仙',
    note: '橙红鱼体与黑色竖纹',
    asset: 'assets/aquarium/centropyge-loriculus.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinPurpleTang,
    name: '紫吊',
    note: '紫蓝鱼体与黄色尾鳍',
    asset: 'assets/aquarium/zebrasoma-xanthurum.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinPowderBlueTang,
    name: '粉蓝吊',
    note: '圆润饱满背鳍版本',
    asset: 'assets/aquarium/acanthurus-leucosternon.webp',
  ),
  BuiltinFishSpecies(
    kind: FishArtworkKind.builtinMidasBlenny,
    name: '东非金剪刀',
    note: '金橙体色与剪刀尾',
    asset: 'assets/aquarium/ecsenius-midas.webp',
  ),
];

BuiltinFishSpecies builtinFishSpeciesFor(FishArtworkKind kind) {
  return builtinFishCatalog.firstWhere(
    (species) => species.kind == kind,
    orElse: () => builtinFishCatalog.first,
  );
}

bool isBuiltinFishArtwork(FishArtworkKind kind) =>
    kind != FishArtworkKind.custom;

class FishStockItem {
  const FishStockItem({
    required this.id,
    required this.tankId,
    required this.species,
    required this.quantity,
    required this.introducedOn,
    required this.artworkKind,
    this.artworkMimeType,
    this.artworkBase64,
  });

  final String id;
  final String tankId;
  final String species;
  final int quantity;
  final DateTime introducedOn;
  final FishArtworkKind artworkKind;
  final String? artworkMimeType;
  final String? artworkBase64;

  Uint8List? get customArtworkBytes {
    final encoded = artworkBase64;
    if (artworkKind != FishArtworkKind.custom || encoded == null) return null;
    return base64Decode(encoded);
  }

  FishStockItem copyWith({
    String? id,
    String? tankId,
    String? species,
    int? quantity,
    DateTime? introducedOn,
    FishArtworkKind? artworkKind,
    String? artworkMimeType,
    String? artworkBase64,
  }) {
    return FishStockItem(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      species: species ?? this.species,
      quantity: quantity ?? this.quantity,
      introducedOn: introducedOn ?? this.introducedOn,
      artworkKind: artworkKind ?? this.artworkKind,
      artworkMimeType: artworkMimeType ?? this.artworkMimeType,
      artworkBase64: artworkBase64 ?? this.artworkBase64,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'tankId': tankId,
    'species': species,
    'quantity': quantity,
    'introducedOn': _dateKey(introducedOn),
    'artworkKind': artworkKind.name,
    'artworkMimeType': artworkMimeType,
    'artworkBase64': artworkBase64,
  };
}

class FishStockCodec {
  const FishStockCodec._();

  static const maximumEntries = 200;
  static const maximumTotalArtworkBase64Length = 20 * 1024 * 1024;

  static List<FishStockItem> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) throw const FormatException('鱼类档案格式无效');
    if (decoded.length > maximumEntries) {
      throw const FormatException('鱼类档案条目过多');
    }
    final result = <FishStockItem>[];
    final ids = <String>{};
    var totalArtworkLength = 0;
    for (final value in decoded) {
      if (value is! Map) throw const FormatException('鱼类档案条目无效');
      final map = Map<String, Object?>.from(value);
      final id = _requiredText(map, 'id', maximumLength: 80);
      final tankId = _requiredText(map, 'tankId', maximumLength: 80);
      final species = _requiredText(map, 'species', maximumLength: 24);
      final quantity = map['quantity'];
      if (quantity is! int || quantity < 1 || quantity > maximumFishQuantity) {
        throw const FormatException('鱼类数量无效');
      }
      final introducedOn = _parseDateKey(map['introducedOn']);
      final kindName = map['artworkKind'];
      final kind = FishArtworkKind.values
          .where((item) => item.name == kindName)
          .firstOrNull;
      if (kind == null) throw const FormatException('鱼类立绘类型无效');
      final mime = map['artworkMimeType'];
      final encoded = map['artworkBase64'];
      if (kind == FishArtworkKind.custom) {
        if (mime is! String ||
            !const {'image/png', 'image/jpeg', 'image/webp'}.contains(mime) ||
            encoded is! String ||
            encoded.isEmpty ||
            encoded.length > maximumFishArtworkBase64Length) {
          throw const FormatException('自定义鱼类立绘无效或过大');
        }
        Uint8List bytes;
        try {
          bytes = base64Decode(encoded);
        } on FormatException {
          throw const FormatException('自定义鱼类立绘编码无效');
        }
        if (bytes.isEmpty) throw const FormatException('自定义鱼类立绘为空');
        totalArtworkLength += encoded.length;
      } else if (mime != null || encoded != null) {
        throw const FormatException('内置鱼种不能携带自定义立绘');
      }
      if (!ids.add(id)) throw const FormatException('鱼类档案 ID 重复');
      result.add(
        FishStockItem(
          id: id,
          tankId: tankId,
          species: species,
          quantity: quantity,
          introducedOn: introducedOn,
          artworkKind: kind,
          artworkMimeType: mime as String?,
          artworkBase64: encoded as String?,
        ),
      );
    }
    if (totalArtworkLength > maximumTotalArtworkBase64Length) {
      throw const FormatException('自定义鱼类立绘总量过大');
    }
    return List.unmodifiable(result);
  }

  static String encode(Iterable<FishStockItem> items) {
    final value = jsonEncode([for (final item in items) item.toJson()]);
    decode(value);
    return value;
  }
}

String _requiredText(
  Map<String, Object?> map,
  String key, {
  required int maximumLength,
}) {
  final value = map[key];
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximumLength) {
    throw FormatException('$key 无效');
  }
  return value.trim();
}

DateTime _parseDateKey(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('入缸日期无效');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || _dateKey(parsed) != value) {
    throw const FormatException('入缸日期无效');
  }
  return parsed;
}

String _dateKey(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}
