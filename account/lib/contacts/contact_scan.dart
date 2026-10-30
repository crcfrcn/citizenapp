import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/contacts/contact_service.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_system/security/account_security_exception.dart';

/// 用户码只作为导入声明；服务端核对当前公开绑定，本地保存同CID联系人关系。
Future<ContactImportResult> addUserQrContact({
  required CitizenQrDocument body,
  required UserContactService contactService,
}) => contactService.importContact(
  cidNumber: body.cidNumber!,
  accountId: body.accountId!,
);


String contactImportFailure(Object error) => error is AccountSecurityException
    ? '本机身份状态暂不可用，请稍后重试'
    : error is SquareApiException
    ? '公民服务暂不可用，请稍后重试'
    : '联系人身份验证或保存失败，请稍后重试';
