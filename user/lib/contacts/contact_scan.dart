import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';

/// 用户码只提供联系人 CID；本机保存后才允许后台备份。
Future<ContactImportResult> addUserQrContact({
  required CitizenQrDocument body,
  required UserContactService contactService,
}) => contactService.addContact(cidNumber: body.cidNumber!);

String contactImportFailure(Object error) => switch (error) {
  FormatException(:final message) => message,
  AccountSecurityException() => '本机身份状态暂不可用，请稍后重试',
  SquareApiException() => SquareSessionResolution.fromError(error).message,
  _ => '联系人保存失败，请稍后重试',
};
