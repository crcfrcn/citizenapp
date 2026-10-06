import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;
import 'package:citizenapp/citizen/shared/account_derivation.dart';

import 'citizenchain_contract_read_service.dart';

/// 当前账户的合约只读入口；用户主动查询才读取链，返回/改参使迟到结果失效。
class CitizenChainContractPage extends StatefulWidget {
  const CitizenChainContractPage({super.key, required this.accountId});
  final String accountId;
  @override
  State<CitizenChainContractPage> createState() =>
      _CitizenChainContractPageState();
}

enum _ReadKind { storage, call, execution }

class _CitizenChainContractPageState extends State<CitizenChainContractPage> {
  final _address = TextEditingController();
  final _input = TextEditingController();
  final _height = TextEditingController();
  final _index = TextEditingController();
  _ReadKind _kind = _ReadKind.storage;
  CitizenChainContractRead? _read;
  CitizenChainContractExecution? _execution;
  String? _error;
  bool _busy = false;
  int _epoch = 0;

  void _clear() => setState(() {
    _epoch++;
    _busy = false;
    _read = null;
    _execution = null;
    _error = null;
  });

  Future<void> _query() async {
    if (_busy) return;
    final service = CitizenChainContractReadService(
      context.read<CitizenSdk>().chain,
    );
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _read = null;
      _execution = null;
    });
    try {
      CitizenChainContractRead? read;
      CitizenChainContractExecution? execution;
      switch (_kind) {
        case _ReadKind.storage:
          read = await service.getStorage(
            contract: _address.text.trim(),
            key: _input.text.trim(),
          );
        case _ReadKind.call:
          read = await service.call(
            accountId: widget.accountId,
            contract: _address.text.trim(),
            inputData: _input.text.trim(),
          );
        case _ReadKind.execution:
          final number = BigInt.tryParse(_height.text.trim());
          final index = int.tryParse(_index.text.trim());
          if (number == null || index == null) {
            throw const FormatException('请输入区块高度和交易序号');
          }
          execution = await service.execution(
            blockNumber: number,
            extrinsicIndex: index,
          );
      }
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _read = read;
        _execution = execution;
      });
    } catch (error) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _error = '查询未完成：$error';
      });
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    for (final controller in [_address, _input, _height, _index]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int maxLength,
  ) => TextField(
    controller: controller,
    maxLength: maxLength,
    onChanged: (_) => _clear(),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );

  String _data(List<int> value) {
    final preview = value.length > 256 ? value.take(256).toList() : value;
    return '${CitizenChainContractReadService.hex(preview)}'
        '${value.length > 256 ? '（共 ${value.length} 字节，仅展示前 256 字节）' : ''}';
  }

  String _fen(String value) {
    final amount = BigInt.parse(value);
    return '${amount ~/ BigInt.from(100)}.${(amount % BigInt.from(100)).toString().padLeft(2, '0')} GMB';
  }

  @override
  Widget build(BuildContext context) {
    final read = _read;
    final execution = _execution;
    final block = read?.block ?? execution?.block;
    return Scaffold(
      appBar: AppBar(title: const Text('合约查询')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('查询使用已确认区块。只读模拟不提交交易，也不扣费。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<_ReadKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: '查询内容'),
            items: const [
              DropdownMenuItem(value: _ReadKind.storage, child: Text('合约存储')),
              DropdownMenuItem(value: _ReadKind.call, child: Text('只读模拟')),
              DropdownMenuItem(
                value: _ReadKind.execution,
                child: Text('执行记录与日志'),
              ),
            ],
            onChanged: (kind) {
              if (kind != null) {
                _clear();
                setState(() {
                  _kind = kind;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          if (_kind == _ReadKind.execution) ...[
            _field(_height, '已确认区块高度', 20),
            _field(_index, '原生交易序号（从 0 开始）', 10),
          ] else ...[
            _field(_address, '合约地址（0x + 40 位十六进制）', 42),
            _field(
              _input,
              _kind == _ReadKind.storage
                  ? '存储键（0x + 64 位十六进制）'
                  : '调用数据（0x 十六进制）',
              _kind == _ReadKind.storage ? 66 : 8194,
            ),
            if (_kind == _ReadKind.call) const Text('金额固定为 0；返回数据按字节展示。'),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _query,
            child: Text(_busy ? '查询中…' : '查询'),
          ),
          if (_error != null) _value('查询状态', _error!),
          if (block != null) ...[
            _value('区块高度', block.number.toString()),
            _value('已确认区块哈希', block.hash),
          ],
          if (read != null) ...[
            _value(
              '查询结果',
              read.failureDescription ??
                  (read.reverted
                      ? '合约已回滚（REVERT）'
                      : read.data == null
                      ? '存储键不存在'
                      : '查询成功'),
            ),
            if (read.data != null) _value('返回数据', _data(read.data!)),
            if (read.gasConsumed != null)
              _value('Gas 消耗（资源）', read.gasConsumed.toString()),
          ],
          if (execution != null) ...[
            _value('执行结果', execution.outcome.succeeded ? '成功' : '失败'),
            _value('原生交易序号', execution.extrinsicIndex.toString()),
            _value('原生交易哈希', execution.transactionHash),
            _value(
              '真实手续费',
              execution.fee == null
                  ? '本交易没有 FeePaid 事件'
                  : _fen(execution.fee!.feeFen),
            ),
            if (execution.fee != null)
              _value(
                '付款账户',
                Keyring().encodeAddress(
                  CitizenChainContractReadService.bytes(
                    execution.fee!.accountId,
                    32,
                  ),
                  kGmbSs58Prefix,
                ),
              ),
            _value('合约日志数', execution.logs.length.toString()),
            for (final log in execution.logs) ...[
              _value('日志 ${log.eventRecordIndex} · 合约地址', log.contract),
              _value('主题', log.topics.join('\n')),
              _value('日志数据', _data(log.data)),
            ],
            const Text('原生交易哈希和序号来自链上正文。日志只展示已确认执行，原生费用以 FeePaid 为准。'),
          ],
        ],
      ),
    );
  }
}
