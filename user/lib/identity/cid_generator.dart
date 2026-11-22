// 按链原语的人主体协议生成公民或居民CID号码。

import 'dart:convert';
import 'package:citizen_sdk/citizen_sdk.dart';

/// 人主体机构码:公民。
const String kCidInstitutionCitizen = 'CTZN';

/// 人主体机构码:居民。
const String kCidInstitutionResident = 'NATP';

/// 校验位字母表(对齐 number.rs `CHECKSUM_ALPHABET`)。
const String _checksumAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// 人主体号段容量:12 位十进制 = 1e12/年。
final BigInt _numberModulus = BigInt.from(1000000000000);

/// R5 高 3 位 / N9 低 9 位分界:1e9。
final BigInt _highLowSplit = BigInt.from(1000000000);

/// 生成公民 / 居民「人主体」CID 号(链上自助占号首选候选号)。
///
/// [accountId] 必须为小写 `0x` + 64 位十六进制的账户文本(与链端 `public_key`
/// 输入逐字节一致,原样进 hash,不做大小写归一)。[institution] 取 `CTZN`(公民)
/// 或 `NATP`(居民)。[year] 为 4 位公历年份 YYYY。
String generateCitizenCid({
  required String accountId,
  required String institution,
  required int year,
}) {
  if (institution != kCidInstitutionCitizen &&
      institution != kCidInstitutionResident) {
    throw ArgumentError.value(
      institution,
      'institution',
      '人主体 CID 仅支持 CTZN(公民)/ NATP(居民)',
    );
  }
  if (year < 1000 || year > 9999) {
    throw ArgumentError.value(year, 'year', 'year 必须为 4 位公历年份 YYYY');
  }
  final yearText = year.toString();

  final input = '$accountId|$institution|$yearText';
  final digest = CitizenScale.blake2b256(utf8.encode(input));

  // 前 8 字节小端 → 无符号 u64。用 BigInt 承载,避免 Dart 有符号 int 在高位溢出。
  final n = CitizenScale.readUnsigned(digest, 0, 8);
  final number = n % _numberModulus;
  final high3 = (number ~/ _highLowSplit).toInt(); // 0..=999
  final low9 = (number % _highLowSplit).toInt();

  final r5 = 'CN${high3.toString().padLeft(3, '0')}';
  final n9 = low9.toString().padLeft(9, '0');

  final payload = '$r5$institution$n9$yearText';
  final m1 = _checksumCharM1(payload);

  return '$r5-$institution$m1-$n9-$yearText';
}

/// 4 字符布局盈利码(Profit)的 M1 校验位 —— 对齐 number.rs
/// `checksum_char_m1(payload, profit = true)`:`'0' + (acc % 10)`。
String _checksumCharM1(String payload) {
  final acc = _checksumAcc(payload);
  final zero = '0'.codeUnitAt(0);
  return String.fromCharCode(zero + (acc % 10));
}

/// 校验和累加器 —— 对齐 number.rs `checksum_acc`:
/// `Σ (idx+1) * alphabetIndex(ch)`,字母表外字符按索引 0 计。
int _checksumAcc(String payload) {
  var total = 0;
  for (var idx = 0; idx < payload.length; idx++) {
    final pos = _checksumAlphabet.indexOf(payload[idx]);
    total += (idx + 1) * (pos < 0 ? 0 : pos);
  }
  return total;
}
