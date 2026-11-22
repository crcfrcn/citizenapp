// 缩写展示CID和系统标签，完整选区复制时恢复原始标识。

const identityCidLabel = '身份CID号';
final _identityCidPattern = RegExp(
  r'(?<![A-Za-z0-9-])([A-Z0-9]{5}-[A-Z0-9]{5}-[0-9]{9})-[0-9]{4,10}(?![A-Za-z0-9-])',
);

String formatIdentityCidText(String value) =>
    value.replaceAllMapped(_identityCidPattern, (match) => match.group(1)!);

/// 仅用于系统标签/提示；不用于昵称、聊天正文或用户文档。
String identityCidUiText(
  String value,
) => formatIdentityCidText(value).replaceAll(
  RegExp(
    r'机构身份CID号|身份\s*ID|(?:公民|居民|机构|身份)\s*CID(?:\s*(?:编号|号码|号))?|公民号|(?:身份\s*)?CID\s*(?:编号|号码|号)|\bCID(?![A-Za-z0-9_])',
  ),
  identityCidLabel,
);

/// 显示选区映射回原文；完整选中的短号仍复制完整 CID，其他选区原样保留。
String identityCidSelectionText(String original, int start, int end) {
  final display = formatIdentityCidText(original);
  if (start < 0 || end < start || end > display.length) return '';
  int originalOffset(int offset) {
    var hidden = 0;
    for (final match in _identityCidPattern.allMatches(original)) {
      final displayEnd = match.start - hidden + match.group(1)!.length;
      if (offset < displayEnd) break;
      hidden += match.group(0)!.length - match.group(1)!.length;
    }
    return offset + hidden;
  }

  return original.substring(originalOffset(start), originalOffset(end));
}

/// 按既有字段语义格式化确认页，用户备注、姓名和正文保持原文。
String identityCidFieldText(String key, String value) {
  const composite = {
    'admins',
    'governance_detail',
    'issuer',
    'target',
    'houses',
    'fee_payer_description',
    'execution_fee_payer_description',
    'operation_fee_payer_description',
    'contact_list',
  };
  return key == 'cid_number' ||
          key.endsWith('_cid_number') ||
          composite.contains(key)
      ? formatIdentityCidText(value)
      : value;
}

/// 已有中文审阅条目只在身份字段上隐藏年份，姓名和其他内容不改。
String identityCidReviewText(String label, String value) =>
    identityCidUiText(label).contains(identityCidLabel)
    ? formatIdentityCidText(value)
    : value;
