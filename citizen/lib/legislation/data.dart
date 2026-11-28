// 法律模型及编解码。

library ;
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';

// 定义法律层级、地区、状态及章节条款和版本模型。

enum LawTier {
  constitution, // 0 宪法
  national, // 1 国家
  provincial, // 2 省
  municipal; // 3 市

  static LawTier fromIndex(int i) => switch (i) {
    0 => LawTier.constitution,
    1 => LawTier.national,
    2 => LawTier.provincial,
    3 => LawTier.municipal,
    _ => throw FormatException('未知法律层级: $i'),
  };

  int get index0 => index;

  String get label => switch (this) {
    LawTier.constitution => '宪法',
    LawTier.national => '国家',
    LawTier.provincial => '省',
    LawTier.municipal => '市',
  };
}

/// 法律地域：省码永久保留两位大写字母，市号为原省内三位编号的数值。
/// 全国使用显式值，不将非法省码或市号回退为全国。
class LawRegion {
  const LawRegion({required this.provinceCode, required this.cityNumber});
  static const national = LawRegion(provinceCode: '', cityNumber: 0);
  final String provinceCode;
  final int cityNumber;

  factory LawRegion.fromCodes(LawTier tier, String province, String city) {
    if (tier == LawTier.constitution || tier == LawTier.national) {
      return national;
    }
    if (tier == LawTier.municipal && !RegExp(r'^[0-9]{3}$').hasMatch(city)) {
      throw const FormatException('法律市号必须沿用省内三位编号');
    }
    final region = LawRegion(
      provinceCode: province,
      cityNumber: tier == LawTier.municipal ? int.parse(city) : 0,
    );
    region.validate(tier);
    return region;
  }

  void validate(LawTier tier) {
    final nationwide = tier == LawTier.constitution || tier == LawTier.national;
    if (nationwide
        ? provinceCode.isNotEmpty || cityNumber != 0
        : !RegExp(r'^[A-Z]{2}$').hasMatch(provinceCode) ||
              cityNumber < 0 ||
              cityNumber > 999 ||
              (tier == LawTier.provincial && cityNumber != 0)) {
      throw const FormatException('法律地域与层级不符');
    }
  }
}

/// 法律状态(链端 LawStatus,1 字节)。
enum LawStatus {
  pending, // 0 通过待生效
  effective, // 1 生效
  repealed; // 2 废止

  static LawStatus fromIndex(int i) => switch (i) {
    0 => LawStatus.pending,
    1 => LawStatus.effective,
    2 => LawStatus.repealed,
    _ => throw FormatException('未知法律状态: $i'),
  };

  String get label => switch (this) {
    LawStatus.pending => '待生效',
    LawStatus.effective => '生效中',
    LawStatus.repealed => '已废止',
  };
}

/// 表决类型(链端 VoteType,1 字节枚举索引;ADR-027 当前五类立法表决)。
///
/// 教育属性编进 vote_type(常规教育/重要教育),不另设内容分类字段。阈值:
/// 常规/常规教育 `>80%参与,≥60%赞成`;重要/重要教育 `>90%,≥70%`;
/// 特别 `全员,≥70%+强制公投(全国/省/市≥70%/≥70%)`。
enum VoteType {
  regular, // 0 常规案
  regularEducation, // 1 常规教育案
  major, // 2 重要案
  majorEducation, // 3 重要教育案
  special; // 4 特别案

  static VoteType fromIndex(int i) => switch (i) {
    0 => VoteType.regular,
    1 => VoteType.regularEducation,
    2 => VoteType.major,
    3 => VoteType.majorEducation,
    4 => VoteType.special,
    _ => throw FormatException('未知立法表决类型: $i'),
  };

  bool get isEducation =>
      this == VoteType.regularEducation || this == VoteType.majorEducation;

  String get label => switch (this) {
    VoteType.regular => '常规案',
    VoteType.regularEducation => '常规教育案',
    VoteType.major => '重要案',
    VoteType.majorEducation => '重要教育案',
    VoteType.special => '特别案',
  };
}

/// 条下的「款」。
class LawClause {
  const LawClause({required this.number, required this.text, this.textEn});
  final int number;
  final String text;
  final String? textEn;
}

/// 条(全法唯一连续编号,用于不可修改条款比对 + 锚点)。
class LawArticle {
  const LawArticle({
    required this.number,
    required this.title,
    required this.body,
    required this.clauses,
    this.titleEn,
    this.bodyEn,
  });
  final int number;
  final String title;
  final String? titleEn;
  final String body;
  final String? bodyEn;
  final List<LawClause> clauses;
}

/// 节。
class LawSection {
  const LawSection({
    required this.number,
    required this.title,
    required this.articles,
    this.titleEn,
  });
  final int number;
  final String title;
  final String? titleEn;
  final List<LawArticle> articles;
}

/// 章。
class LawChapter {
  const LawChapter({
    required this.number,
    required this.title,
    required this.sections,
    this.titleEn,
  });
  final int number;
  final String title;
  final String? titleEn;
  final List<LawSection> sections;
}

/// 法律主记录(链端 `law(law_id)` 返回)。
class Law {
  const Law({
    required this.lawId,
    required this.tier,
    required this.region,
    required this.houses,
    required this.effectiveVersion,
    required this.latestVersion,
    required this.pendingVersion,
    required this.status,
  });
  final int lawId;
  final LawTier tier;

  /// 与链端 LawRegion 固定四字节布局对应，不把字母省码转成整数。
  final LawRegion region;

  /// 归属立法机构 CID 序列；宪法固定归属国家立法院，不等于修宪发起院。
  /// 机构码由 CID 解析，任何机构账户都不得替代机构身份。
  final List<String> houses;

  /// 当前真正生效的版本。新法通过但未到生效时间时为空。
  final int? effectiveVersion;

  /// 已写入链上的最新版本。
  final int latestVersion;

  /// 已通过但未到生效时间的版本。
  final int? pendingVersion;

  final LawStatus status;

  /// 公民端默认阅读版本:优先读生效版;新法尚无生效版时读待生效版。
  int? get readerVersion =>
      effectiveVersion ??
      pendingVersion ??
      (latestVersion > 0 ? latestVersion : null);
}

/// 法律某版本正文(链端 `law_version(law_id, version)` 返回)。
class LawVersion {
  const LawVersion({
    required this.lawId,
    required this.version,
    required this.title,
    required this.chapters,
    required this.contentHash,
    required this.voteType,
    required this.proposalId,
    required this.publishedAt,
    required this.effectiveAt,
    this.titleEn,
  });
  final int lawId;
  final int version;
  final String title;
  final String? titleEn;
  final List<LawChapter> chapters;

  /// blake2_256(SCALE chapters) hex(公投/签名绑定)。
  final String contentHash;
  final int voteType;

  /// 通过本版本所用的表决类型(5 类枚举)。
  VoteType get voteTypeEnum => VoteType.fromIndex(voteType);

  /// 创世宪法为 0。
  final BigInt proposalId;

  /// 链上时间戳(毫秒)。
  final int publishedAt;
  final int effectiveAt;
}

/// 法律版本展示标签(链端 `LawVersionLabels[(law_id, version)]`)。
class LawVersionLabel {
  const LawVersionLabel({required this.title, this.titleEn});

  /// 中文版本名,例如公民宪法 `version=1` 的“创世版”。
  final String title;

  /// 英文版本名,例如 `Genesis Edition`。
  final String? titleEn;
}

/// 宪法不可修改条款 manifest(链端 ConstitutionImmutableManifest)。
class ImmutableManifest {
  const ImmutableManifest({
    required this.articleNumbers,
    required this.articleHashes,
  });

  /// 不可修改的条号集合(链端固定 [1,2,3,17,19,24,34,42],ADR-027 重排后基准)。
  final List<int> articleNumbers;

  /// 与 [articleNumbers] 平行的条文 blake2_256 hex 数组。
  final List<String> articleHashes;

  bool isImmutable(int articleNumber) => articleNumbers.contains(articleNumber);
}

// 严格解码法律Runtime API及存储返回的SCALE字节。

/// 游标式 SCALE 读取器(内部)。
class _Scale {
  _Scale(this.data);
  final Uint8List data;
  int _i = 0;

  bool get isDone => _i == data.length;

  void requireDone() {
    if (!isDone) throw const FormatException('SCALE 数据存在尾随字节');
  }

  int u8() => data[_i++];

  int u16() => _unsigned(2);
  int u32() => _unsigned(4);
  int u64() => _unsigned(8);

  int _unsigned(int width) {
    final value = CitizenScale.readUnsigned(data, _i, width);
    _i += width;
    return value.toSigned(64).toInt();
  }

  int compact() {
    final (value, width) = CitizenScale.readCompact(data, _i);
    if (value > 0xffffffff) throw const FormatException('Compact 长度超出 u32');
    _i += width;
    return value;
  }

  Uint8List bytes(int n) {
    final b = data.sublist(_i, _i + n);
    _i += n;
    return b;
  }

  /// Compact(len)+len 字节 → UTF-8 字符串。
  String boundedString() => utf8.decode(bytes(compact()));

  /// 链端统一 CidNumber：`BoundedVec<u8, 32>`。
  String cidNumber() {
    final length = compact();
    if (length <= 0 || length > 32) {
      throw const FormatException('机构 CID 长度必须为 1..32 字节');
    }
    return utf8.decode(bytes(length));
  }

  /// N 裸字节 → 小写 hex(不含 0x)。
  String hex(int n) =>
      bytes(n).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// `Option<T>`:1 tag 字节(0=None / 1=Some)。
  T? option<T>(T Function() some) {
    final tag = u8();
    if (tag == 0) return null;
    if (tag == 1) return some();
    throw FormatException('Option tag 非法: $tag');
  }

  /// `Vec<T>`/`BoundedVec<T>`:Compact(len)+items。
  List<T> vec<T>(T Function() item) {
    final n = compact();
    return [for (var k = 0; k < n; k++) item()];
  }
}

/// 解 `Option<Vec<u8>>`(API 边界外层)→ 内层 SCALE 字节(None 返回 null)。
Uint8List? decodeOptionBytes(Uint8List raw) {
  final s = _Scale(raw);
  final tag = s.u8();
  if (tag == 0) {
    s.requireDone();
    return null;
  }
  if (tag != 1) throw FormatException('Option tag 非法: $tag');
  final value = s.bytes(s.compact());
  s.requireDone();
  return value;
}

/// 解 `list_laws` 返回的 `Vec<u64>`。
List<int> decodeLawIds(Uint8List raw) {
  final s = _Scale(raw);
  final ids = s.vec(s.u64);
  s.requireDone();
  return ids;
}

/// 固定两字节省码 + u16 LE 市号；全国四零字节与冻结宪法布局一致。
Uint8List encodeLawRegion(LawTier tier, LawRegion region) {
  region.validate(tier);
  return Uint8List.fromList([
    if (region.provinceCode.isEmpty) ...[
      0,
      0,
    ] else
      ...region.provinceCode.codeUnits,
    ...CitizenScale.unsigned(BigInt.from(region.cityNumber), 2),
  ]);
}

/// 解 `Law`(内层字节,调用方先 [decodeOptionBytes] 拆 Option)。
Law decodeLaw(Uint8List raw) {
  final s = _Scale(raw);
  final lawId = s.u64();
  final tier = LawTier.fromIndex(s.u8());
  final province = [s.u8(), s.u8()];
  final region = LawRegion(
    provinceCode: province.every((byte) => byte == 0)
        ? ''
        : String.fromCharCodes(province),
    cityNumber: s.u16(),
  );
  region.validate(tier);
  final houses = s.vec(s.cidNumber);
  final effectiveVersion = s.option(s.u32);
  final latestVersion = s.u32();
  final pendingVersion = s.option(s.u32);
  final status = LawStatus.fromIndex(s.u8());
  s.requireDone();
  return Law(
    lawId: lawId,
    tier: tier,
    region: region,
    houses: houses,
    effectiveVersion: effectiveVersion,
    latestVersion: latestVersion,
    pendingVersion: pendingVersion,
    status: status,
  );
}

/// 解 `LawVersion`(内层字节)。
LawVersion decodeLawVersion(Uint8List raw) {
  final s = _Scale(raw);
  final lawId = s.u64();
  final version = s.u32();
  final title = s.boundedString();
  final titleEn = s.option(s.boundedString);
  final chapters = s.vec(() => _chapter(s));
  final contentHash = s.hex(32);
  final voteType = s.u8();
  final proposalId = CitizenScale.readUnsigned(s.data, s._i, 16);
  s._i += 16;
  final publishedAt = s.u64();
  final effectiveAt = s.u64();
  s.requireDone();
  return LawVersion(
    lawId: lawId,
    version: version,
    title: title,
    titleEn: titleEn,
    chapters: chapters,
    contentHash: contentHash,
    voteType: voteType,
    proposalId: proposalId,
    publishedAt: publishedAt,
    effectiveAt: effectiveAt,
  );
}

/// 解 `LawVersionLabel`(内层字节)。
LawVersionLabel decodeLawVersionLabel(Uint8List raw) {
  final s = _Scale(raw);
  final title = s.boundedString();
  final titleEn = s.option(s.boundedString);
  s.requireDone();
  return LawVersionLabel(title: title, titleEn: titleEn);
}

/// 解 `ConstitutionImmutableManifest`(StorageValue 原始字节)。
ImmutableManifest decodeImmutableManifest(Uint8List raw) {
  final s = _Scale(raw);
  final numbers = s.vec(s.u32);
  final hashes = s.vec(() => s.hex(32));
  s.requireDone();
  return ImmutableManifest(articleNumbers: numbers, articleHashes: hashes);
}

LawChapter _chapter(_Scale s) {
  final number = s.u32();
  final title = s.boundedString();
  final titleEn = s.option(s.boundedString);
  final sections = s.vec(() => _section(s));
  return LawChapter(
    number: number,
    title: title,
    titleEn: titleEn,
    sections: sections,
  );
}

LawSection _section(_Scale s) {
  final number = s.u32();
  final title = s.boundedString();
  final titleEn = s.option(s.boundedString);
  final articles = s.vec(() => _article(s));
  return LawSection(
    number: number,
    title: title,
    titleEn: titleEn,
    articles: articles,
  );
}

LawArticle _article(_Scale s) {
  final number = s.u32();
  final title = s.boundedString();
  final titleEn = s.option(s.boundedString);
  final body = s.boundedString();
  final bodyEn = s.option(s.boundedString);
  final clauses = s.vec(() => _clause(s));
  return LawArticle(
    number: number,
    title: title,
    titleEn: titleEn,
    body: body,
    bodyEn: bodyEn,
    clauses: clauses,
  );
}

LawClause _clause(_Scale s) {
  final number = s.u32();
  final text = s.boundedString();
  final textEn = s.option(s.boundedString);
  return LawClause(number: number, text: text, textEn: textEn);
}
