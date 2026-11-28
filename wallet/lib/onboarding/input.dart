// 助记词与钱包密码输入。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:citizen_system/theme.dart';

// 提供由SDK词表驱动的助记词输入和单词补全。

/// BIP39 助记词输入组件，支持单词自动补全。
///
/// 用户输入字母时，自动展示匹配的 BIP39 单词供选择。
/// 选中后自动补全并跳到下一个单词。
class Bip39InputField extends StatefulWidget {
  const Bip39InputField({
    super.key,
    required this.controller,
    this.wordCount = 12,
  });

  final TextEditingController controller;

  /// 期望的助记词单词数量（12、18或24）。
  final int wordCount;

  @override
  State<Bip39InputField> createState() => _Bip39InputFieldState();
}

class _Bip39InputFieldState extends State<Bip39InputField> {
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _onTextChanged() async {
    final text = widget.controller.text;
    final currentWord = _currentWord(text);

    if (currentWord.isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }

    final prefix = currentWord.toLowerCase();
    List<String> matches;
    try {
      matches = await context.read<CitizenSdk>().wordSuggestions(prefix);
    } catch (_) {
      matches = const [];
    }
    if (!mounted || widget.controller.text != text) return;
    setState(() => _suggestions = matches);
  }

  /// 提取末尾未完成单词；保留原交互，不按任意光标位置另算候选。
  String _currentWord(String text) {
    if (text.isEmpty) return '';
    // 如果末尾是空格，说明上一个单词已输完
    if (text.endsWith(' ')) return '';
    final parts = text.split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }

  void _selectWord(String word) {
    final text = widget.controller.text;
    final trimmed = text.trimRight();
    final parts = trimmed.split(RegExp(r'\s+'));

    // 替换最后一个不完整的单词
    if (parts.isNotEmpty) {
      parts[parts.length - 1] = word;
    } else {
      parts.add(word);
    }

    final newText = '${parts.join(' ')} ';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _suggestions = []);
  }

  int get _enteredWordCount {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '输入助记词，选择匹配的单词',
            counterText:
                '$_enteredWordCount / ${widget.wordCount > 0 ? widget.wordCount : "12、18 或 24"} 个单词',
          ),
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
        ),
        if (_suggestions.isNotEmpty) ...[
          SizedBox(height: AppLayout.scaled(context, 8)),
          Wrap(
            spacing: AppLayout.scaled(context, 8),
            runSpacing: AppLayout.scaled(context, 4),
            children: _suggestions.map((word) {
              return ActionChip(
                label:
                    Text(word, style: const TextStyle(color: AppTheme.primary)),
                backgroundColor: AppTheme.primary.withAlpha(15),
                side: BorderSide(color: AppTheme.primary.withAlpha(40)),
                onPressed: () => _selectWord(word),
              );
            }).toList(growable: false),
          ),
        ],
      ],
    );
  }
}

// 呈现可选钱包密码输入和风险确认，映射SDK校验结果。

/// 这里只映射原提示文案；密码校验、字符集和规范化均由SDK完成。
Future<void> validateWalletPasswordInput(BuildContext context, String raw) async {
  final result = await context.read<CitizenSdk>().validatePassword(raw);
  if (result.isValid) return;
  final message = switch (result.reason) {
    CitizenWalletInputReason.passwordLength || CitizenWalletInputReason.inputTooLong => '密码长度必须为 6–30 位',
    CitizenWalletInputReason.passwordNormalization => '密码包含规范化后无法安全恢复的字符',
    _ => '密码只能使用大写字母、小写字母、数字、指定符号或汉字',
  };
  throw WalletPasswordException(message);
}

final class WalletPasswordException implements Exception {
  const WalletPasswordException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 四端共用的单次可选 password 输入框。
class WalletPasswordField extends StatefulWidget {
  const WalletPasswordField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<WalletPasswordField> createState() => _WalletPasswordFieldState();
}

class _WalletPasswordFieldState extends State<WalletPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      decoration: InputDecoration(
        labelText: '钱包密码（选填）',
        helperText: '6–30 位；可用大小写字母、数字、符号或汉字',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _obscure ? '显示密码' : '隐藏密码',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

/// 非空 password 才提示风险；只确认一次，不要求用户再次输入。
Future<bool> confirmWalletPasswordUse(
  BuildContext context,
  String password,
) async {
  if (password.isEmpty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认钱包密码', textAlign: TextAlign.center),
          content: const Text(
            '钱包密码将用于派生钱包账户，不同的密码会派生完全不同的账户，'
            '请务必牢记密码，忘记密码将无法恢复钱包。',
          ),
          actions: [
            // 两个决定具有同等布局权重，固定等宽并左右对齐，避免文字宽度影响按钮位置。
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;
}
