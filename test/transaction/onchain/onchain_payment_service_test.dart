import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizenapp/transaction/onchain/onchain_payment_models.dart';
import 'package:citizenapp/transaction/onchain/onchain_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_citizen_sdk.dart';

const _cid = 'CN220-CTZN2-100000001-2026';

class _Reader extends CitizenIdentityChainReader {
  _Reader(this.binding) : super(chain: TestCitizenChain());
  final CitizenBindingChainSnapshot? binding;
  int reads = 0;
  @override
  Future<CitizenBindingChainSnapshot?> readBindingByCidNumber(
    String cid,
  ) async {
    expect(cid, _cid);
    reads++;
    return binding;
  }
}

void main() {
  OnchainPaymentService service(_Reader reader) => OnchainPaymentService(
    wallet: TestCitizenSdkWallet(),
    transactions: TestCitizenTransactions(),
    bindingReader: reader,
  );
  test('CID签名前只解析一次，采用换绑后当前账户，不沿用联系人旧地址', () async {
    final binding = CitizenBindingChainSnapshot(
      cidNumber: _cid,
      accountId: Uint8List.fromList(List.filled(32, 0xaa)),
      bindRev: 2,
      block: CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.from(9),
        finality: CitizenBlockFinality.finalized,
      ),
    );
    final reader = _Reader(binding);
    final target = await service(reader).resolveRecipient(
      address: ss58FromAccountIdText('0x${'bb' * 32}'),
      cidNumber: _cid,
    );
    expect(reader.reads, 1);
    expect(target.address, ss58FromAccountIdText(binding.accountIdText));
    expect(target.cidNumber, _cid);
    expect(target.bindRev, 2);
    expect(target.blockHash, binding.block!.hash);
  });
  test('无有效绑定时拒绝，禁止回退联系人缓存地址', () async {
    final reader = _Reader(null);
    await expectLater(
      service(reader).resolveRecipient(
        address: ss58FromAccountIdText('0x${'bb' * 32}'),
        cidNumber: _cid,
      ),
      throwsStateError,
    );
    expect(reader.reads, 1);
  });
  test('直接账户转账不解析CID', () async {
    final reader = _Reader(null);
    final address = ss58FromAccountIdText('0x${'bb' * 32}');
    expect(
      (await service(reader).resolveRecipient(address: address)).address,
      address,
    );
    expect(reader.reads, 0);
  });
  test('确认账户与待签草稿不一致时，在钱包读取和交易准备前拒绝', () async {
    final reader = _Reader(null);
    await expectLater(
      service(reader).prepareTransfer(
        OnchainPaymentDraft(
          sourceAccountId: '0x${'aa' * 32}',
          toAddress: 'changed',
          amount: 1,
          symbol: 'GMB',
          remark: '',
          recipient: const OnchainRecipient(
            address: 'confirmed',
            cidNumber: _cid,
          ),
        ),
      ),
      throwsA(isA<OnchainPaymentException>()),
    );
    expect(reader.reads, 0);
  });
}
