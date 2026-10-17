import 'dart:convert';

/// 链上已确认的公开身份绑定；不含任何钱包或数据秘密。
final class IdentityBinding {
  const IdentityBinding({
    required this.genesisHash,
    required this.cidNumber,
    required this.bindingRevision,
    required this.accountId,
  });
  final String genesisHash;
  final String cidNumber;
  final int bindingRevision;
  final String accountId;
  static final _hash = RegExp(r'^0x[0-9a-f]{64}$');
  void validate() {
    if (!_hash.hasMatch(genesisHash) ||
        !_hash.hasMatch(accountId) ||
        !RegExp(r'^[\x21-\x39\x3b-\x7e]{1,32}$').hasMatch(cidNumber) ||
        bindingRevision <= 0 ||
        bindingRevision > 9007199254740991) {
      throw const FormatException('公开身份绑定格式无效');
    }
  }

  Map<String, Object> toJson() => {
    'genesis_hash': genesisHash,
    'cid_number': cidNumber,
    'binding_revision': bindingRevision,
    'account_id': accountId,
  };
  static IdentityBinding? fromJson(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value.length != 4 ||
          value['genesis_hash'] is! String ||
          value['cid_number'] is! String ||
          value['binding_revision'] is! int ||
          value['account_id'] is! String) {
        return null;
      }
      final binding = IdentityBinding(
        genesisHash: value['genesis_hash'] as String,
        cidNumber: value['cid_number'] as String,
        bindingRevision: value['binding_revision'] as int,
        accountId: value['account_id'] as String,
      );
      binding.validate();
      return binding;
    } on FormatException {
      return null;
    }
  }
}
