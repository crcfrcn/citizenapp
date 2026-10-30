/// 身份/登记编排失败；不吞掉SDK原始失败，也不自动重复钱包授权。
class AccountSecurityException implements Exception {
  const AccountSecurityException(
    this.message, {
    this.code = 'accountSecurityFailed',
    this.stage,
  });
  final String message;
  final String code;
  final String? stage;
  @override
  String toString() => 'AccountSecurityException: $message';
}

