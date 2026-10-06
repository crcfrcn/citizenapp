import 'dart:typed_data';

import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' as scale;
import 'package:substrate_metadata/substrate_metadata.dart' as metadata;

/// 按 SDK 返回的准确区块 metadata 编解码；不维护类型名别名或固定类型编号。
final class CitizenChainRuntimeCodec {
  CitizenChainRuntimeCodec(Uint8List bytes) {
    final input = scale.ByteInput(bytes);
    runtime = metadata.RuntimeMetadataPrefixed.codec.decode(input).metadata;
    input.assertEndOfDataReached();
    types = CitizenChainPortableCodecs(runtime);
  }
  late final metadata.RuntimeMetadata runtime;
  late final CitizenChainPortableCodecs types;

  metadata.ApiMethodMetadata method(String trait, String name) {
    final apis = runtime.apis.where((api) => api.name == trait).toList();
    if (apis.length != 1) {
      throw const FormatException('准确 metadata 未提供所需 Runtime API');
    }
    final methods = apis.single.methods
        .where((method) => method.name == name)
        .toList();
    if (methods.length != 1) {
      throw const FormatException('准确 metadata 未提供所需 Runtime 方法');
    }
    return methods.single;
  }

  Uint8List arguments(
    metadata.ApiMethodMetadata method,
    Map<String, Object?> values,
  ) {
    if (method.inputs.length != values.length ||
        method.inputs.map((input) => input.name).toSet().length !=
            values.length ||
        !method.inputs.every((input) => values.containsKey(input.name))) {
      throw const FormatException('Runtime API 参数合同与准确 metadata 不一致');
    }
    final output = scale.ByteOutput();
    for (final input in method.inputs) {
      types.codec(input.type).encodeTo(values[input.name], output);
    }
    return output.toBytes();
  }

  /// 完整解码并重编码，拒绝尾字节和非规范 compact 编码。
  Object? result(metadata.ApiMethodMetadata method, Uint8List bytes) {
    final codec = types.codec(method.output);
    final input = scale.ByteInput(bytes);
    final raw = codec.decode(input);
    input.assertEndOfDataReached();
    final canonical = codec.encode(raw);
    if (canonical.length != bytes.length ||
        List.generate(
          bytes.length,
          (i) => i,
        ).any((i) => canonical[i] != bytes[i])) {
      throw const FormatException('Runtime API 输出不是规范 SCALE');
    }
    return normalize(raw);
  }

  static Object? normalize(Object? value) {
    if (value is MapEntry) return {value.key: normalize(value.value)};
    if (value is Map) {
      return value.map((key, item) => MapEntry(key, normalize(item)));
    }
    if (value is List) return value.map(normalize).toList();
    return value;
  }
}

/// System.Events 与 Runtime API 共用 portable 类型解析，透明包装只解析一次。
final class CitizenChainPortableCodecs {
  CitizenChainPortableCodecs(metadata.RuntimeMetadata runtime)
    : _types = {for (final type in runtime.types) type.id: type.type} {
    if (_types.length != runtime.types.length) {
      throw const FormatException('metadata 类型编号重复');
    }
  }
  final Map<int, metadata.TypeMetadata> _types;
  final _codecs = <int, scale.Codec>{};

  scale.Codec codec(int id) {
    id = _resolveType(id);
    final cached = _codecs[id];
    if (cached != null) return cached;
    final type = _types[id];
    if (type == null) throw const FormatException('metadata 类型引用不存在');
    final proxy = scale.ProxyCodec();
    _codecs[id] = proxy;
    final definition = type.typeDef;
    proxy.codec = switch (definition) {
      metadata.TypeDefPrimitive() =>
        scale.Registry().getCodec(definition.primitive.name.toLowerCase()) ??
            (throw const FormatException('事件包含不支持的 primitive')),
      metadata.TypeDefComposite() => _fields(definition.fields),
      metadata.TypeDefVariant() => _variants(definition.variants),
      metadata.TypeDefSequence() => scale.SequenceCodec(codec(definition.type)),
      metadata.TypeDefArray() => scale.ArrayCodec(
        codec(definition.type),
        definition.length,
      ),
      metadata.TypeDefTuple() => scale.TupleCodec(
        definition.fields.map(codec).toList(),
      ),
      metadata.TypeDefCompact() => scale.CompactBigIntCodec.codec,
      metadata.TypeDefBitSequence() => _bits(definition),
      _ => throw const FormatException('事件包含不支持的 portable 类型'),
    };
    return proxy;
  }

  /// SCALE 的单未命名字段包装不增加字节，也不增加解码值的层级。
  /// 在创建代理前解析到承载类型，避免 ProxyCodec 套 ProxyCodec；
  /// 只拒绝不经过真实容器的纯包装循环，容器递归仍复用已登记代理。
  int _resolveType(int id) {
    final visited = <int>{};
    while (true) {
      if (!visited.add(id)) {
        throw const FormatException('metadata 存在纯包装循环');
      }
      final type = _types[id];
      if (type == null) throw const FormatException('metadata 类型引用不存在');
      final definition = type.typeDef;
      if (definition is! metadata.TypeDefComposite ||
          definition.fields.length != 1 ||
          definition.fields.single.name != null) {
        return id;
      }
      id = definition.fields.single.type;
    }
  }

  scale.Codec _fields(List<metadata.Field> fields) {
    if (fields.isEmpty) return scale.NullCodec.codec;
    if (fields.every((field) => field.name == null)) {
      if (fields.length == 1) return codec(fields.single.type);
      return scale.TupleCodec(
        fields.map((field) => codec(field.type)).toList(),
      );
    }
    if (fields.any((field) => field.name == null) ||
        fields.map((field) => field.name).toSet().length != fields.length) {
      throw const FormatException('metadata 命名字段不完整或重复');
    }
    return scale.CompositeCodec({
      for (final field in fields) field.name!: codec(field.type),
    });
  }

  scale.Codec _variants(List<metadata.Variant> variants) {
    if (variants.map((v) => v.index).toSet().length != variants.length ||
        variants.map((v) => v.name).toSet().length != variants.length) {
      throw const FormatException('metadata 枚举索引或名称重复');
    }
    return scale.ComplexEnumCodec.sparse({
      for (final variant in variants)
        variant.index: MapEntry(variant.name, _fields(variant.fields)),
    });
  }

  scale.Codec _bits(metadata.TypeDefBitSequence definition) {
    final store = _types[definition.bitStoreType]?.typeDef;
    final order = _types[definition.bitOrderType]?.path.lastOrNull;
    if (store is! metadata.TypeDefPrimitive ||
        !['U8', 'U16', 'U32', 'U64'].contains(store.primitive.name) ||
        (order != 'Lsb0' && order != 'Msb0')) {
      throw const FormatException('metadata 位序类型无效');
    }
    return scale.BitSequenceCodec(
      scale.BitStore.values.singleWhere(
        (value) => value.name == store.primitive.name,
      ),
      order == 'Lsb0' ? scale.BitOrder.LSB : scale.BitOrder.MSB,
    );
  }
}
