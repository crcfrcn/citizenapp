import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 页面只登记可见账户；最终区块、缓存和读取调度属于 SDK。
final chainBalanceRoutes = RouteObserver<ModalRoute<dynamic>>();

class ChainBalanceVisibility extends InheritedWidget {
  const ChainBalanceVisibility({
    super.key,
    required this.active,
    required super.child,
  });
  final bool active;
  @override
  bool updateShouldNotify(ChainBalanceVisibility oldWidget) =>
      active != oldWidget.active;
}

class ChainBalanceScope extends StatefulWidget {
  const ChainBalanceScope({
    super.key,
    required this.accountIds,
    required this.builder,
    this.balances,
    this.onError,
  });
  final Iterable<String> accountIds;
  final CitizenBalances? balances;
  final ValueChanged<Object>? onError;
  final Widget Function(BuildContext, CitizenBalances) builder;
  @override
  State<ChainBalanceScope> createState() => _ChainBalanceScopeState();
}

class _ChainBalanceScopeState extends State<ChainBalanceScope> with RouteAware {
  late CitizenBalances _store;
  ModalRoute<dynamic>? _route;
  Set<String> _ids = {};
  final _states = <CitizenBalanceState<CitizenAccountBalance>>[];
  VoidCallback? _release;
  Object? _reportedError;
  bool _routeVisible = true, _tabVisible = true, _ready = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _store = _resolve();
    }
    _tabVisible =
        context
            .dependOnInheritedWidgetOfExactType<ChainBalanceVisibility>()
            ?.active ??
        true;
    final route = ModalRoute.of(context);
    if (route != _route) {
      chainBalanceRoutes.unsubscribe(this);
      _route = route;
      _routeVisible = route?.isCurrent ?? true;
      if (route != null) {
        chainBalanceRoutes.subscribe(this, route);
      }
    }
    _ready = true;
    _bind();
  }

  @override
  void didUpdateWidget(ChainBalanceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready) {
      _bind();
    }
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    final errors = _states.where((s) => s.hasError);
    final error = errors.isEmpty ? null : errors.first.error;
    if (error != null && !identical(error, _reportedError)) {
      _reportedError = error;
      scheduleMicrotask(() {
        if (mounted && _routeVisible && _tabVisible) {
          widget.onError?.call(error);
        }
      });
    } else if (error == null) {
      _reportedError = null;
    }
    setState(() {});
  }

  void _unbind() {
    _release?.call();
    _release = null;
    for (final state in _states) {
      state.removeListener(_changed);
    }
    _states.clear();
    _reportedError = null;
    _ids = {};
  }

  CitizenBalances _resolve() =>
      widget.balances ??
      context.read<CitizenBalances?>() ??
      context.read<CitizenSdk>().balances;

  void _bind() {
    final ids = _routeVisible && _tabVisible
        ? widget.accountIds.toSet()
        : <String>{};
    final next = _resolve();
    if (identical(next, _store) &&
        ids.length == _ids.length &&
        ids.containsAll(_ids)) {
      return;
    }
    _unbind();
    _store = next;
    _ids = ids;
    if (ids.isEmpty) {
      return;
    }
    for (final id in ids) {
      final state = _store.accountState(id);
      state.addListener(_changed);
      _states.add(state);
    }
    _release = _store.watch(ids);
  }

  void _visibility(bool visible) {
    _routeVisible = visible;
    _bind();
  }

  @override
  void didPushNext() => _visibility(false);
  @override
  void didPopNext() => _visibility(true);
  @override
  void didPush() => _visibility(true);
  @override
  void didPop() => _visibility(false);
  @override
  void dispose() {
    chainBalanceRoutes.unsubscribe(this);
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _store);
}

class ChainBalanceText extends StatelessWidget {
  const ChainBalanceText({
    super.key,
    required this.accountId,
    this.total = false,
    this.style,
    this.suffix = ' 元',
  });
  final String accountId;
  final bool total;
  final TextStyle? style;
  final String suffix;
  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: [accountId],
    builder: (context, store) {
      final state = store.accountState(accountId);
      final value = state.value;
      final text = value == null
          ? (state.hasError ? '读取失败，点击重试' : '—')
          : formatFen(total ? value.totalFen : value.freeFen) +
                suffix +
                (state.hasError ? '（更新失败）' : '');
      return GestureDetector(
        onTap: state.hasError
            ? () => unawaited(state.load(forceRefresh: true))
            : null,
        child: Text(text, style: style),
      );
    },
  );
}
