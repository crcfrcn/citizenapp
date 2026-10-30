// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_isar.dart';

// ignore_for_file: experimental_member_use

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProofCollection on Isar {
  IsarCollection<Proof> get proofs => this.collection();
}

const ProofSchema = CollectionSchema(
  name: r'proof',
  id: -2565032288947897414,
  properties: {},

  estimateSize: _proofEstimateSize,
  serialize: _proofSerialize,
  deserialize: _proofDeserialize,
  deserializeProp: _proofDeserializeProp,
  idName: r'row_id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _proofGetId,
  getLinks: _proofGetLinks,
  attach: _proofAttach,
  version: '3.3.2',
);

int _proofEstimateSize(
  Proof object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _proofSerialize(
  Proof object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {}
Proof _proofDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Proof();
  object.rowId = id;
  return object;
}

P _proofDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _proofGetId(Proof object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _proofGetLinks(Proof object) {
  return [];
}

void _proofAttach(IsarCollection<dynamic> col, Id id, Proof object) {
  object.rowId = id;
}

extension ProofQueryWhereSort on QueryBuilder<Proof, Proof, QWhere> {
  QueryBuilder<Proof, Proof, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProofQueryWhere on QueryBuilder<Proof, Proof, QWhereClause> {
  QueryBuilder<Proof, Proof, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Proof, Proof, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProofQueryFilter on QueryBuilder<Proof, Proof, QFilterCondition> {
  QueryBuilder<Proof, Proof, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proof, Proof, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProofQueryObject on QueryBuilder<Proof, Proof, QFilterCondition> {}

extension ProofQueryLinks on QueryBuilder<Proof, Proof, QFilterCondition> {}

extension ProofQuerySortBy on QueryBuilder<Proof, Proof, QSortBy> {}

extension ProofQuerySortThenBy on QueryBuilder<Proof, Proof, QSortThenBy> {
  QueryBuilder<Proof, Proof, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Proof, Proof, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ProofQueryWhereDistinct on QueryBuilder<Proof, Proof, QDistinct> {}

extension ProofQueryProperty on QueryBuilder<Proof, Proof, QQueryProperty> {
  QueryBuilder<Proof, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBalanceCollection on Isar {
  IsarCollection<Balance> get balances => this.collection();
}

const BalanceSchema = CollectionSchema(
  name: r'balance',
  id: 2711266091681628246,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'body_data': PropertySchema(
      id: 1,
      name: r'body_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _balanceEstimateSize,
  serialize: _balanceSerialize,
  deserialize: _balanceDeserialize,
  deserializeProp: _balanceDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id': IndexSchema(
      id: 3848080515527097000,
      name: r'account_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _balanceGetId,
  getLinks: _balanceGetLinks,
  attach: _balanceAttach,
  version: '3.3.2',
);

int _balanceEstimateSize(
  Balance object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.bodyData.length * 3;
  return bytesCount;
}

void _balanceSerialize(
  Balance object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.bodyData);
}

Balance _balanceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Balance();
  object.accountId = reader.readString(offsets[0]);
  object.bodyData = reader.readString(offsets[1]);
  object.rowId = id;
  return object;
}

P _balanceDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _balanceGetId(Balance object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _balanceGetLinks(Balance object) {
  return [];
}

void _balanceAttach(IsarCollection<dynamic> col, Id id, Balance object) {
  object.rowId = id;
}

extension BalanceByIndex on IsarCollection<Balance> {
  Future<Balance?> getByAccountId(String accountId) {
    return getByIndex(r'account_id', [accountId]);
  }

  Balance? getByAccountIdSync(String accountId) {
    return getByIndexSync(r'account_id', [accountId]);
  }

  Future<bool> deleteByAccountId(String accountId) {
    return deleteByIndex(r'account_id', [accountId]);
  }

  bool deleteByAccountIdSync(String accountId) {
    return deleteByIndexSync(r'account_id', [accountId]);
  }

  Future<List<Balance?>> getAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'account_id', values);
  }

  List<Balance?> getAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'account_id', values);
  }

  Future<int> deleteAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'account_id', values);
  }

  int deleteAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'account_id', values);
  }

  Future<Id> putByAccountId(Balance object) {
    return putByIndex(r'account_id', object);
  }

  Id putByAccountIdSync(Balance object, {bool saveLinks = true}) {
    return putByIndexSync(r'account_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAccountId(List<Balance> objects) {
    return putAllByIndex(r'account_id', objects);
  }

  List<Id> putAllByAccountIdSync(
    List<Balance> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'account_id', objects, saveLinks: saveLinks);
  }
}

extension BalanceQueryWhereSort on QueryBuilder<Balance, Balance, QWhere> {
  QueryBuilder<Balance, Balance, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BalanceQueryWhere on QueryBuilder<Balance, Balance, QWhereClause> {
  QueryBuilder<Balance, Balance, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> accountIdEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterWhereClause> accountIdNotEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension BalanceQueryFilter
    on QueryBuilder<Balance, Balance, QFilterCondition> {
  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BalanceQueryObject
    on QueryBuilder<Balance, Balance, QFilterCondition> {}

extension BalanceQueryLinks
    on QueryBuilder<Balance, Balance, QFilterCondition> {}

extension BalanceQuerySortBy on QueryBuilder<Balance, Balance, QSortBy> {
  QueryBuilder<Balance, Balance, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }
}

extension BalanceQuerySortThenBy
    on QueryBuilder<Balance, Balance, QSortThenBy> {
  QueryBuilder<Balance, Balance, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension BalanceQueryWhereDistinct
    on QueryBuilder<Balance, Balance, QDistinct> {
  QueryBuilder<Balance, Balance, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Balance, Balance, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }
}

extension BalanceQueryProperty
    on QueryBuilder<Balance, Balance, QQueryProperty> {
  QueryBuilder<Balance, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Balance, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Balance, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGroupCollection on Isar {
  IsarCollection<Group> get groups => this.collection();
}

const GroupSchema = CollectionSchema(
  name: r'group',
  id: -7980787437430964260,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'detail_data': PropertySchema(
      id: 1,
      name: r'detail_data',
      type: IsarType.string,
    ),
    r'group_state': PropertySchema(
      id: 2,
      name: r'group_state',
      type: IsarType.string,
    ),
    r'synced_at': PropertySchema(
      id: 3,
      name: r'synced_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _groupEstimateSize,
  serialize: _groupSerialize,
  deserialize: _groupDeserialize,
  deserializeProp: _groupDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id': IndexSchema(
      id: 3848080515527097000,
      name: r'account_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _groupGetId,
  getLinks: _groupGetLinks,
  attach: _groupAttach,
  version: '3.3.2',
);

int _groupEstimateSize(
  Group object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  {
    final value = object.detailData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.groupState;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _groupSerialize(
  Group object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.detailData);
  writer.writeString(offsets[2], object.groupState);
  writer.writeLong(offsets[3], object.syncedAt);
}

Group _groupDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Group();
  object.accountId = reader.readString(offsets[0]);
  object.detailData = reader.readStringOrNull(offsets[1]);
  object.groupState = reader.readStringOrNull(offsets[2]);
  object.rowId = id;
  object.syncedAt = reader.readLongOrNull(offsets[3]);
  return object;
}

P _groupDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _groupGetId(Group object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _groupGetLinks(Group object) {
  return [];
}

void _groupAttach(IsarCollection<dynamic> col, Id id, Group object) {
  object.rowId = id;
}

extension GroupByIndex on IsarCollection<Group> {
  Future<Group?> getByAccountId(String accountId) {
    return getByIndex(r'account_id', [accountId]);
  }

  Group? getByAccountIdSync(String accountId) {
    return getByIndexSync(r'account_id', [accountId]);
  }

  Future<bool> deleteByAccountId(String accountId) {
    return deleteByIndex(r'account_id', [accountId]);
  }

  bool deleteByAccountIdSync(String accountId) {
    return deleteByIndexSync(r'account_id', [accountId]);
  }

  Future<List<Group?>> getAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'account_id', values);
  }

  List<Group?> getAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'account_id', values);
  }

  Future<int> deleteAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'account_id', values);
  }

  int deleteAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'account_id', values);
  }

  Future<Id> putByAccountId(Group object) {
    return putByIndex(r'account_id', object);
  }

  Id putByAccountIdSync(Group object, {bool saveLinks = true}) {
    return putByIndexSync(r'account_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAccountId(List<Group> objects) {
    return putAllByIndex(r'account_id', objects);
  }

  List<Id> putAllByAccountIdSync(List<Group> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'account_id', objects, saveLinks: saveLinks);
  }
}

extension GroupQueryWhereSort on QueryBuilder<Group, Group, QWhere> {
  QueryBuilder<Group, Group, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GroupQueryWhere on QueryBuilder<Group, Group, QWhereClause> {
  QueryBuilder<Group, Group, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> accountIdEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterWhereClause> accountIdNotEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension GroupQueryFilter on QueryBuilder<Group, Group, QFilterCondition> {
  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'detail_data'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'detail_data'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'detail_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'detail_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'detail_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'detail_data', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'detail_data', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'group_state'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'group_state'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'group_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'group_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_state', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'group_state', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'synced_at'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'synced_at'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'synced_at', value: value),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'synced_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'synced_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> syncedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'synced_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension GroupQueryObject on QueryBuilder<Group, Group, QFilterCondition> {}

extension GroupQueryLinks on QueryBuilder<Group, Group, QFilterCondition> {}

extension GroupQuerySortBy on QueryBuilder<Group, Group, QSortBy> {
  QueryBuilder<Group, Group, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByDetailData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'detail_data', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByDetailDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'detail_data', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByGroupState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_state', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByGroupStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_state', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.desc);
    });
  }
}

extension GroupQuerySortThenBy on QueryBuilder<Group, Group, QSortThenBy> {
  QueryBuilder<Group, Group, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByDetailData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'detail_data', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByDetailDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'detail_data', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByGroupState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_state', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByGroupStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_state', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.desc);
    });
  }
}

extension GroupQueryWhereDistinct on QueryBuilder<Group, Group, QDistinct> {
  QueryBuilder<Group, Group, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Group, Group, QDistinct> distinctByDetailData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'detail_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Group, Group, QDistinct> distinctByGroupState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Group, Group, QDistinct> distinctBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synced_at');
    });
  }
}

extension GroupQueryProperty on QueryBuilder<Group, Group, QQueryProperty> {
  QueryBuilder<Group, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Group, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Group, String?, QQueryOperations> detailDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'detail_data');
    });
  }

  QueryBuilder<Group, String?, QQueryOperations> groupStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_state');
    });
  }

  QueryBuilder<Group, int?, QQueryOperations> syncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synced_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetScanCollection on Isar {
  IsarCollection<Scan> get scans => this.collection();
}

const ScanSchema = CollectionSchema(
  name: r'scan',
  id: 3325226684762472654,
  properties: {
    r'wallet_hash': PropertySchema(
      id: 0,
      name: r'wallet_hash',
      type: IsarType.string,
    ),
  },

  estimateSize: _scanEstimateSize,
  serialize: _scanSerialize,
  deserialize: _scanDeserialize,
  deserializeProp: _scanDeserializeProp,
  idName: r'row_id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _scanGetId,
  getLinks: _scanGetLinks,
  attach: _scanAttach,
  version: '3.3.2',
);

int _scanEstimateSize(
  Scan object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.walletHash.length * 3;
  return bytesCount;
}

void _scanSerialize(
  Scan object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.walletHash);
}

Scan _scanDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Scan();
  object.rowId = id;
  object.walletHash = reader.readString(offsets[0]);
  return object;
}

P _scanDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _scanGetId(Scan object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _scanGetLinks(Scan object) {
  return [];
}

void _scanAttach(IsarCollection<dynamic> col, Id id, Scan object) {
  object.rowId = id;
}

extension ScanQueryWhereSort on QueryBuilder<Scan, Scan, QWhere> {
  QueryBuilder<Scan, Scan, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ScanQueryWhere on QueryBuilder<Scan, Scan, QWhereClause> {
  QueryBuilder<Scan, Scan, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Scan, Scan, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ScanQueryFilter on QueryBuilder<Scan, Scan, QFilterCondition> {
  QueryBuilder<Scan, Scan, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'wallet_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'wallet_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'wallet_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'wallet_hash', value: ''),
      );
    });
  }

  QueryBuilder<Scan, Scan, QAfterFilterCondition> walletHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'wallet_hash', value: ''),
      );
    });
  }
}

extension ScanQueryObject on QueryBuilder<Scan, Scan, QFilterCondition> {}

extension ScanQueryLinks on QueryBuilder<Scan, Scan, QFilterCondition> {}

extension ScanQuerySortBy on QueryBuilder<Scan, Scan, QSortBy> {
  QueryBuilder<Scan, Scan, QAfterSortBy> sortByWalletHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wallet_hash', Sort.asc);
    });
  }

  QueryBuilder<Scan, Scan, QAfterSortBy> sortByWalletHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wallet_hash', Sort.desc);
    });
  }
}

extension ScanQuerySortThenBy on QueryBuilder<Scan, Scan, QSortThenBy> {
  QueryBuilder<Scan, Scan, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Scan, Scan, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Scan, Scan, QAfterSortBy> thenByWalletHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wallet_hash', Sort.asc);
    });
  }

  QueryBuilder<Scan, Scan, QAfterSortBy> thenByWalletHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wallet_hash', Sort.desc);
    });
  }
}

extension ScanQueryWhereDistinct on QueryBuilder<Scan, Scan, QDistinct> {
  QueryBuilder<Scan, Scan, QDistinct> distinctByWalletHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wallet_hash', caseSensitive: caseSensitive);
    });
  }
}

extension ScanQueryProperty on QueryBuilder<Scan, Scan, QQueryProperty> {
  QueryBuilder<Scan, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Scan, String, QQueryOperations> walletHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wallet_hash');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSummaryCollection on Isar {
  IsarCollection<Summary> get summarys => this.collection();
}

const SummarySchema = CollectionSchema(
  name: r'summary',
  id: 7630605597744450915,
  properties: {
    r'body_data': PropertySchema(
      id: 0,
      name: r'body_data',
      type: IsarType.string,
    ),
    r'proposal_id': PropertySchema(
      id: 1,
      name: r'proposal_id',
      type: IsarType.long,
    ),
  },

  estimateSize: _summaryEstimateSize,
  serialize: _summarySerialize,
  deserialize: _summaryDeserialize,
  deserializeProp: _summaryDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'proposal_id': IndexSchema(
      id: -1697214643687574663,
      name: r'proposal_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'proposal_id',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _summaryGetId,
  getLinks: _summaryGetLinks,
  attach: _summaryAttach,
  version: '3.3.2',
);

int _summaryEstimateSize(
  Summary object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  return bytesCount;
}

void _summarySerialize(
  Summary object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
  writer.writeLong(offsets[1], object.proposalId);
}

Summary _summaryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Summary();
  object.bodyData = reader.readString(offsets[0]);
  object.proposalId = reader.readLong(offsets[1]);
  object.rowId = id;
  return object;
}

P _summaryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _summaryGetId(Summary object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _summaryGetLinks(Summary object) {
  return [];
}

void _summaryAttach(IsarCollection<dynamic> col, Id id, Summary object) {
  object.rowId = id;
}

extension SummaryByIndex on IsarCollection<Summary> {
  Future<Summary?> getByProposalId(int proposalId) {
    return getByIndex(r'proposal_id', [proposalId]);
  }

  Summary? getByProposalIdSync(int proposalId) {
    return getByIndexSync(r'proposal_id', [proposalId]);
  }

  Future<bool> deleteByProposalId(int proposalId) {
    return deleteByIndex(r'proposal_id', [proposalId]);
  }

  bool deleteByProposalIdSync(int proposalId) {
    return deleteByIndexSync(r'proposal_id', [proposalId]);
  }

  Future<List<Summary?>> getAllByProposalId(List<int> proposalIdValues) {
    final values = proposalIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'proposal_id', values);
  }

  List<Summary?> getAllByProposalIdSync(List<int> proposalIdValues) {
    final values = proposalIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'proposal_id', values);
  }

  Future<int> deleteAllByProposalId(List<int> proposalIdValues) {
    final values = proposalIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'proposal_id', values);
  }

  int deleteAllByProposalIdSync(List<int> proposalIdValues) {
    final values = proposalIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'proposal_id', values);
  }

  Future<Id> putByProposalId(Summary object) {
    return putByIndex(r'proposal_id', object);
  }

  Id putByProposalIdSync(Summary object, {bool saveLinks = true}) {
    return putByIndexSync(r'proposal_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProposalId(List<Summary> objects) {
    return putAllByIndex(r'proposal_id', objects);
  }

  List<Id> putAllByProposalIdSync(
    List<Summary> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'proposal_id', objects, saveLinks: saveLinks);
  }
}

extension SummaryQueryWhereSort on QueryBuilder<Summary, Summary, QWhere> {
  QueryBuilder<Summary, Summary, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhere> anyProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'proposal_id'),
      );
    });
  }
}

extension SummaryQueryWhere on QueryBuilder<Summary, Summary, QWhereClause> {
  QueryBuilder<Summary, Summary, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> proposalIdEqualTo(
    int proposalId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'proposal_id',
          value: [proposalId],
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> proposalIdNotEqualTo(
    int proposalId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_id',
                lower: [],
                upper: [proposalId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_id',
                lower: [proposalId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_id',
                lower: [proposalId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_id',
                lower: [],
                upper: [proposalId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> proposalIdGreaterThan(
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_id',
          lower: [proposalId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> proposalIdLessThan(
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_id',
          lower: [],
          upper: [proposalId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterWhereClause> proposalIdBetween(
    int lowerProposalId,
    int upperProposalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_id',
          lower: [lowerProposalId],
          includeLower: includeLower,
          upper: [upperProposalId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SummaryQueryFilter
    on QueryBuilder<Summary, Summary, QFilterCondition> {
  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> proposalIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_id', value: value),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> proposalIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> proposalIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> proposalIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SummaryQueryObject
    on QueryBuilder<Summary, Summary, QFilterCondition> {}

extension SummaryQueryLinks
    on QueryBuilder<Summary, Summary, QFilterCondition> {}

extension SummaryQuerySortBy on QueryBuilder<Summary, Summary, QSortBy> {
  QueryBuilder<Summary, Summary, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> sortByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> sortByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }
}

extension SummaryQuerySortThenBy
    on QueryBuilder<Summary, Summary, QSortThenBy> {
  QueryBuilder<Summary, Summary, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension SummaryQueryWhereDistinct
    on QueryBuilder<Summary, Summary, QDistinct> {
  QueryBuilder<Summary, Summary, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Summary, Summary, QDistinct> distinctByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proposal_id');
    });
  }
}

extension SummaryQueryProperty
    on QueryBuilder<Summary, Summary, QQueryProperty> {
  QueryBuilder<Summary, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Summary, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }

  QueryBuilder<Summary, int, QQueryOperations> proposalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProposalListCollection on Isar {
  IsarCollection<ProposalList> get proposalLists => this.collection();
}

const ProposalListSchema = CollectionSchema(
  name: r'list',
  id: -5742266293228518431,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'proposal_ids': PropertySchema(
      id: 1,
      name: r'proposal_ids',
      type: IsarType.longList,
    ),
    r'synced_at': PropertySchema(
      id: 2,
      name: r'synced_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _proposalListEstimateSize,
  serialize: _proposalListSerialize,
  deserialize: _proposalListDeserialize,
  deserializeProp: _proposalListDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number': IndexSchema(
      id: 5073804840546792610,
      name: r'cid_number',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _proposalListGetId,
  getLinks: _proposalListGetLinks,
  attach: _proposalListAttach,
  version: '3.3.2',
);

int _proposalListEstimateSize(
  ProposalList object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.proposalIds.length * 8;
  return bytesCount;
}

void _proposalListSerialize(
  ProposalList object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeLongList(offsets[1], object.proposalIds);
  writer.writeLong(offsets[2], object.syncedAt);
}

ProposalList _proposalListDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ProposalList();
  object.cidNumber = reader.readString(offsets[0]);
  object.proposalIds = reader.readLongList(offsets[1]) ?? [];
  object.rowId = id;
  object.syncedAt = reader.readLong(offsets[2]);
  return object;
}

P _proposalListDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongList(offset) ?? []) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _proposalListGetId(ProposalList object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _proposalListGetLinks(ProposalList object) {
  return [];
}

void _proposalListAttach(
  IsarCollection<dynamic> col,
  Id id,
  ProposalList object,
) {
  object.rowId = id;
}

extension ProposalListByIndex on IsarCollection<ProposalList> {
  Future<ProposalList?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  ProposalList? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<ProposalList?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<ProposalList?> getAllByCidNumberSync(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'cid_number', values);
  }

  Future<int> deleteAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'cid_number', values);
  }

  int deleteAllByCidNumberSync(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'cid_number', values);
  }

  Future<Id> putByCidNumber(ProposalList object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(ProposalList object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<ProposalList> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<ProposalList> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension ProposalListQueryWhereSort
    on QueryBuilder<ProposalList, ProposalList, QWhere> {
  QueryBuilder<ProposalList, ProposalList, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProposalListQueryWhere
    on QueryBuilder<ProposalList, ProposalList, QWhereClause> {
  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> rowIdEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> rowIdNotEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterWhereClause>
  cidNumberNotEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ProposalListQueryFilter
    on QueryBuilder<ProposalList, ProposalList, QFilterCondition> {
  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cid_number',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cid_number',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_ids', value: value),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_ids',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_ids',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_ids',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'proposal_ids', length, true, length, true);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'proposal_ids', 0, true, 0, true);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'proposal_ids', 0, false, 999999, true);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'proposal_ids', 0, true, length, include);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'proposal_ids', length, include, 999999, true);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  proposalIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'proposal_ids',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  syncedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'synced_at', value: value),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  syncedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'synced_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  syncedAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'synced_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  syncedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'synced_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProposalListQueryObject
    on QueryBuilder<ProposalList, ProposalList, QFilterCondition> {}

extension ProposalListQueryLinks
    on QueryBuilder<ProposalList, ProposalList, QFilterCondition> {}

extension ProposalListQuerySortBy
    on QueryBuilder<ProposalList, ProposalList, QSortBy> {
  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> sortBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> sortBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.desc);
    });
  }
}

extension ProposalListQuerySortThenBy
    on QueryBuilder<ProposalList, ProposalList, QSortThenBy> {
  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced_at', Sort.desc);
    });
  }
}

extension ProposalListQueryWhereDistinct
    on QueryBuilder<ProposalList, ProposalList, QDistinct> {
  QueryBuilder<ProposalList, ProposalList, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QDistinct> distinctByProposalIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proposal_ids');
    });
  }

  QueryBuilder<ProposalList, ProposalList, QDistinct> distinctBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synced_at');
    });
  }
}

extension ProposalListQueryProperty
    on QueryBuilder<ProposalList, ProposalList, QQueryProperty> {
  QueryBuilder<ProposalList, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<ProposalList, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<ProposalList, List<int>, QQueryOperations>
  proposalIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_ids');
    });
  }

  QueryBuilder<ProposalList, int, QQueryOperations> syncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synced_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProposalCollection on Isar {
  IsarCollection<Proposal> get proposals => this.collection();
}

const ProposalSchema = CollectionSchema(
  name: r'proposal',
  id: 7845892132956556269,
  properties: {
    r'body_data': PropertySchema(
      id: 0,
      name: r'body_data',
      type: IsarType.string,
    ),
    r'proposal_id': PropertySchema(
      id: 1,
      name: r'proposal_id',
      type: IsarType.long,
    ),
    r'proposal_kind': PropertySchema(
      id: 2,
      name: r'proposal_kind',
      type: IsarType.string,
    ),
  },

  estimateSize: _proposalEstimateSize,
  serialize: _proposalSerialize,
  deserialize: _proposalDeserialize,
  deserializeProp: _proposalDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'proposal_kind_proposal_id': IndexSchema(
      id: -1301108225446421680,
      name: r'proposal_kind_proposal_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'proposal_kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'proposal_id',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _proposalGetId,
  getLinks: _proposalGetLinks,
  attach: _proposalAttach,
  version: '3.3.2',
);

int _proposalEstimateSize(
  Proposal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.proposalKind.length * 3;
  return bytesCount;
}

void _proposalSerialize(
  Proposal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
  writer.writeLong(offsets[1], object.proposalId);
  writer.writeString(offsets[2], object.proposalKind);
}

Proposal _proposalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Proposal();
  object.bodyData = reader.readString(offsets[0]);
  object.proposalId = reader.readLong(offsets[1]);
  object.proposalKind = reader.readString(offsets[2]);
  object.rowId = id;
  return object;
}

P _proposalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _proposalGetId(Proposal object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _proposalGetLinks(Proposal object) {
  return [];
}

void _proposalAttach(IsarCollection<dynamic> col, Id id, Proposal object) {
  object.rowId = id;
}

extension ProposalByIndex on IsarCollection<Proposal> {
  Future<Proposal?> getByProposalKindProposalId(
    String proposalKind,
    int proposalId,
  ) {
    return getByIndex(r'proposal_kind_proposal_id', [proposalKind, proposalId]);
  }

  Proposal? getByProposalKindProposalIdSync(
    String proposalKind,
    int proposalId,
  ) {
    return getByIndexSync(r'proposal_kind_proposal_id', [
      proposalKind,
      proposalId,
    ]);
  }

  Future<bool> deleteByProposalKindProposalId(
    String proposalKind,
    int proposalId,
  ) {
    return deleteByIndex(r'proposal_kind_proposal_id', [
      proposalKind,
      proposalId,
    ]);
  }

  bool deleteByProposalKindProposalIdSync(String proposalKind, int proposalId) {
    return deleteByIndexSync(r'proposal_kind_proposal_id', [
      proposalKind,
      proposalId,
    ]);
  }

  Future<List<Proposal?>> getAllByProposalKindProposalId(
    List<String> proposalKindValues,
    List<int> proposalIdValues,
  ) {
    final len = proposalKindValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([proposalKindValues[i], proposalIdValues[i]]);
    }

    return getAllByIndex(r'proposal_kind_proposal_id', values);
  }

  List<Proposal?> getAllByProposalKindProposalIdSync(
    List<String> proposalKindValues,
    List<int> proposalIdValues,
  ) {
    final len = proposalKindValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([proposalKindValues[i], proposalIdValues[i]]);
    }

    return getAllByIndexSync(r'proposal_kind_proposal_id', values);
  }

  Future<int> deleteAllByProposalKindProposalId(
    List<String> proposalKindValues,
    List<int> proposalIdValues,
  ) {
    final len = proposalKindValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([proposalKindValues[i], proposalIdValues[i]]);
    }

    return deleteAllByIndex(r'proposal_kind_proposal_id', values);
  }

  int deleteAllByProposalKindProposalIdSync(
    List<String> proposalKindValues,
    List<int> proposalIdValues,
  ) {
    final len = proposalKindValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([proposalKindValues[i], proposalIdValues[i]]);
    }

    return deleteAllByIndexSync(r'proposal_kind_proposal_id', values);
  }

  Future<Id> putByProposalKindProposalId(Proposal object) {
    return putByIndex(r'proposal_kind_proposal_id', object);
  }

  Id putByProposalKindProposalIdSync(Proposal object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'proposal_kind_proposal_id',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByProposalKindProposalId(List<Proposal> objects) {
    return putAllByIndex(r'proposal_kind_proposal_id', objects);
  }

  List<Id> putAllByProposalKindProposalIdSync(
    List<Proposal> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'proposal_kind_proposal_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ProposalQueryWhereSort on QueryBuilder<Proposal, Proposal, QWhere> {
  QueryBuilder<Proposal, Proposal, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProposalQueryWhere on QueryBuilder<Proposal, Proposal, QWhereClause> {
  QueryBuilder<Proposal, Proposal, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause> rowIdNotEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindEqualToAnyProposalId(String proposalKind) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'proposal_kind_proposal_id',
          value: [proposalKind],
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindNotEqualToAnyProposalId(String proposalKind) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [],
                upper: [proposalKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [],
                upper: [proposalKind],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindProposalIdEqualTo(String proposalKind, int proposalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'proposal_kind_proposal_id',
          value: [proposalKind, proposalId],
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindEqualToProposalIdNotEqualTo(String proposalKind, int proposalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind],
                upper: [proposalKind, proposalId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind, proposalId],
                includeLower: false,
                upper: [proposalKind],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind, proposalId],
                includeLower: false,
                upper: [proposalKind],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_kind_proposal_id',
                lower: [proposalKind],
                upper: [proposalKind, proposalId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindEqualToProposalIdGreaterThan(
    String proposalKind,
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_kind_proposal_id',
          lower: [proposalKind, proposalId],
          includeLower: include,
          upper: [proposalKind],
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindEqualToProposalIdLessThan(
    String proposalKind,
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_kind_proposal_id',
          lower: [proposalKind],
          upper: [proposalKind, proposalId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterWhereClause>
  proposalKindEqualToProposalIdBetween(
    String proposalKind,
    int lowerProposalId,
    int upperProposalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'proposal_kind_proposal_id',
          lower: [proposalKind, lowerProposalId],
          includeLower: includeLower,
          upper: [proposalKind, upperProposalId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProposalQueryFilter
    on QueryBuilder<Proposal, Proposal, QFilterCondition> {
  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_id', value: value),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition>
  proposalKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition>
  proposalKindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'proposal_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> proposalKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'proposal_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition>
  proposalKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_kind', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition>
  proposalKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'proposal_kind', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProposalQueryObject
    on QueryBuilder<Proposal, Proposal, QFilterCondition> {}

extension ProposalQueryLinks
    on QueryBuilder<Proposal, Proposal, QFilterCondition> {}

extension ProposalQuerySortBy on QueryBuilder<Proposal, Proposal, QSortBy> {
  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_kind', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_kind', Sort.desc);
    });
  }
}

extension ProposalQuerySortThenBy
    on QueryBuilder<Proposal, Proposal, QSortThenBy> {
  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_kind', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_kind', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ProposalQueryWhereDistinct
    on QueryBuilder<Proposal, Proposal, QDistinct> {
  QueryBuilder<Proposal, Proposal, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Proposal, Proposal, QDistinct> distinctByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proposal_id');
    });
  }

  QueryBuilder<Proposal, Proposal, QDistinct> distinctByProposalKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'proposal_kind',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension ProposalQueryProperty
    on QueryBuilder<Proposal, Proposal, QQueryProperty> {
  QueryBuilder<Proposal, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Proposal, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }

  QueryBuilder<Proposal, int, QQueryOperations> proposalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_id');
    });
  }

  QueryBuilder<Proposal, String, QQueryOperations> proposalKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_kind');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLawSnapshotCollection on Isar {
  IsarCollection<LawSnapshot> get lawSnapshots => this.collection();
}

const LawSnapshotSchema = CollectionSchema(
  name: r'law',
  id: 8427905963410600019,
  properties: {
    r'state_hex': PropertySchema(
      id: 0,
      name: r'state_hex',
      type: IsarType.string,
    ),
    r'state_key': PropertySchema(
      id: 1,
      name: r'state_key',
      type: IsarType.string,
    ),
  },

  estimateSize: _lawSnapshotEstimateSize,
  serialize: _lawSnapshotSerialize,
  deserialize: _lawSnapshotDeserialize,
  deserializeProp: _lawSnapshotDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'state_key': IndexSchema(
      id: 6677710894347112482,
      name: r'state_key',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'state_key',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _lawSnapshotGetId,
  getLinks: _lawSnapshotGetLinks,
  attach: _lawSnapshotAttach,
  version: '3.3.2',
);

int _lawSnapshotEstimateSize(
  LawSnapshot object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.stateHex.length * 3;
  bytesCount += 3 + object.stateKey.length * 3;
  return bytesCount;
}

void _lawSnapshotSerialize(
  LawSnapshot object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.stateHex);
  writer.writeString(offsets[1], object.stateKey);
}

LawSnapshot _lawSnapshotDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LawSnapshot();
  object.rowId = id;
  object.stateHex = reader.readString(offsets[0]);
  object.stateKey = reader.readString(offsets[1]);
  return object;
}

P _lawSnapshotDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _lawSnapshotGetId(LawSnapshot object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _lawSnapshotGetLinks(LawSnapshot object) {
  return [];
}

void _lawSnapshotAttach(
  IsarCollection<dynamic> col,
  Id id,
  LawSnapshot object,
) {
  object.rowId = id;
}

extension LawSnapshotByIndex on IsarCollection<LawSnapshot> {
  Future<LawSnapshot?> getByStateKey(String stateKey) {
    return getByIndex(r'state_key', [stateKey]);
  }

  LawSnapshot? getByStateKeySync(String stateKey) {
    return getByIndexSync(r'state_key', [stateKey]);
  }

  Future<bool> deleteByStateKey(String stateKey) {
    return deleteByIndex(r'state_key', [stateKey]);
  }

  bool deleteByStateKeySync(String stateKey) {
    return deleteByIndexSync(r'state_key', [stateKey]);
  }

  Future<List<LawSnapshot?>> getAllByStateKey(List<String> stateKeyValues) {
    final values = stateKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'state_key', values);
  }

  List<LawSnapshot?> getAllByStateKeySync(List<String> stateKeyValues) {
    final values = stateKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'state_key', values);
  }

  Future<int> deleteAllByStateKey(List<String> stateKeyValues) {
    final values = stateKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'state_key', values);
  }

  int deleteAllByStateKeySync(List<String> stateKeyValues) {
    final values = stateKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'state_key', values);
  }

  Future<Id> putByStateKey(LawSnapshot object) {
    return putByIndex(r'state_key', object);
  }

  Id putByStateKeySync(LawSnapshot object, {bool saveLinks = true}) {
    return putByIndexSync(r'state_key', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByStateKey(List<LawSnapshot> objects) {
    return putAllByIndex(r'state_key', objects);
  }

  List<Id> putAllByStateKeySync(
    List<LawSnapshot> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'state_key', objects, saveLinks: saveLinks);
  }
}

extension LawSnapshotQueryWhereSort
    on QueryBuilder<LawSnapshot, LawSnapshot, QWhere> {
  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LawSnapshotQueryWhere
    on QueryBuilder<LawSnapshot, LawSnapshot, QWhereClause> {
  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> rowIdEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> rowIdNotEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> stateKeyEqualTo(
    String stateKey,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'state_key', value: [stateKey]),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterWhereClause> stateKeyNotEqualTo(
    String stateKey,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state_key',
                lower: [],
                upper: [stateKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state_key',
                lower: [stateKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state_key',
                lower: [stateKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state_key',
                lower: [],
                upper: [stateKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LawSnapshotQueryFilter
    on QueryBuilder<LawSnapshot, LawSnapshot, QFilterCondition> {
  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state_hex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'state_hex',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateHexMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'state_hex',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state_hex', value: ''),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state_hex', value: ''),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state_key',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'state_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition> stateKeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'state_key',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state_key', value: ''),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  stateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state_key', value: ''),
      );
    });
  }
}

extension LawSnapshotQueryObject
    on QueryBuilder<LawSnapshot, LawSnapshot, QFilterCondition> {}

extension LawSnapshotQueryLinks
    on QueryBuilder<LawSnapshot, LawSnapshot, QFilterCondition> {}

extension LawSnapshotQuerySortBy
    on QueryBuilder<LawSnapshot, LawSnapshot, QSortBy> {
  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> sortByStateHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_hex', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> sortByStateHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_hex', Sort.desc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> sortByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_key', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> sortByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_key', Sort.desc);
    });
  }
}

extension LawSnapshotQuerySortThenBy
    on QueryBuilder<LawSnapshot, LawSnapshot, QSortThenBy> {
  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByStateHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_hex', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByStateHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_hex', Sort.desc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_key', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_key', Sort.desc);
    });
  }
}

extension LawSnapshotQueryWhereDistinct
    on QueryBuilder<LawSnapshot, LawSnapshot, QDistinct> {
  QueryBuilder<LawSnapshot, LawSnapshot, QDistinct> distinctByStateHex({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state_hex', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QDistinct> distinctByStateKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state_key', caseSensitive: caseSensitive);
    });
  }
}

extension LawSnapshotQueryProperty
    on QueryBuilder<LawSnapshot, LawSnapshot, QQueryProperty> {
  QueryBuilder<LawSnapshot, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<LawSnapshot, String, QQueryOperations> stateHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state_hex');
    });
  }

  QueryBuilder<LawSnapshot, String, QQueryOperations> stateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state_key');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAdminCollection on Isar {
  IsarCollection<Admin> get admins => this.collection();
}

const AdminSchema = CollectionSchema(
  name: r'admin',
  id: 1851435006106218815,
  properties: {
    r'body_data': PropertySchema(
      id: 0,
      name: r'body_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _adminEstimateSize,
  serialize: _adminSerialize,
  deserialize: _adminDeserialize,
  deserializeProp: _adminDeserializeProp,
  idName: r'row_id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _adminGetId,
  getLinks: _adminGetLinks,
  attach: _adminAttach,
  version: '3.3.2',
);

int _adminEstimateSize(
  Admin object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  return bytesCount;
}

void _adminSerialize(
  Admin object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
}

Admin _adminDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Admin();
  object.bodyData = reader.readString(offsets[0]);
  object.rowId = id;
  return object;
}

P _adminDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _adminGetId(Admin object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _adminGetLinks(Admin object) {
  return [];
}

void _adminAttach(IsarCollection<dynamic> col, Id id, Admin object) {
  object.rowId = id;
}

extension AdminQueryWhereSort on QueryBuilder<Admin, Admin, QWhere> {
  QueryBuilder<Admin, Admin, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AdminQueryWhere on QueryBuilder<Admin, Admin, QWhereClause> {
  QueryBuilder<Admin, Admin, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Admin, Admin, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AdminQueryFilter on QueryBuilder<Admin, Admin, QFilterCondition> {
  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AdminQueryObject on QueryBuilder<Admin, Admin, QFilterCondition> {}

extension AdminQueryLinks on QueryBuilder<Admin, Admin, QFilterCondition> {}

extension AdminQuerySortBy on QueryBuilder<Admin, Admin, QSortBy> {
  QueryBuilder<Admin, Admin, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }
}

extension AdminQuerySortThenBy on QueryBuilder<Admin, Admin, QSortThenBy> {
  QueryBuilder<Admin, Admin, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension AdminQueryWhereDistinct on QueryBuilder<Admin, Admin, QDistinct> {
  QueryBuilder<Admin, Admin, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }
}

extension AdminQueryProperty on QueryBuilder<Admin, Admin, QQueryProperty> {
  QueryBuilder<Admin, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Admin, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMemberCollection on Isar {
  IsarCollection<Member> get members => this.collection();
}

const MemberSchema = CollectionSchema(
  name: r'member',
  id: 4005898307651635317,
  properties: {
    r'body_data': PropertySchema(
      id: 0,
      name: r'body_data',
      type: IsarType.string,
    ),
    r'cid_number': PropertySchema(
      id: 1,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'state_kind': PropertySchema(
      id: 2,
      name: r'state_kind',
      type: IsarType.string,
    ),
  },

  estimateSize: _memberEstimateSize,
  serialize: _memberSerialize,
  deserialize: _memberDeserialize,
  deserializeProp: _memberDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_state_kind': IndexSchema(
      id: 5180110874569567356,
      name: r'cid_number_state_kind',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'state_kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _memberGetId,
  getLinks: _memberGetLinks,
  attach: _memberAttach,
  version: '3.3.2',
);

int _memberEstimateSize(
  Member object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.stateKind.length * 3;
  return bytesCount;
}

void _memberSerialize(
  Member object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeString(offsets[2], object.stateKind);
}

Member _memberDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Member();
  object.bodyData = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.rowId = id;
  object.stateKind = reader.readString(offsets[2]);
  return object;
}

P _memberDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _memberGetId(Member object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _memberGetLinks(Member object) {
  return [];
}

void _memberAttach(IsarCollection<dynamic> col, Id id, Member object) {
  object.rowId = id;
}

extension MemberByIndex on IsarCollection<Member> {
  Future<Member?> getByCidNumberStateKind(String cidNumber, String stateKind) {
    return getByIndex(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Member? getByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return getByIndexSync(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Future<bool> deleteByCidNumberStateKind(String cidNumber, String stateKind) {
    return deleteByIndex(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  bool deleteByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return deleteByIndexSync(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Future<List<Member?>> getAllByCidNumberStateKind(
    List<String> cidNumberValues,
    List<String> stateKindValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      stateKindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], stateKindValues[i]]);
    }

    return getAllByIndex(r'cid_number_state_kind', values);
  }

  List<Member?> getAllByCidNumberStateKindSync(
    List<String> cidNumberValues,
    List<String> stateKindValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      stateKindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], stateKindValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_state_kind', values);
  }

  Future<int> deleteAllByCidNumberStateKind(
    List<String> cidNumberValues,
    List<String> stateKindValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      stateKindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], stateKindValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_state_kind', values);
  }

  int deleteAllByCidNumberStateKindSync(
    List<String> cidNumberValues,
    List<String> stateKindValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      stateKindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], stateKindValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_state_kind', values);
  }

  Future<Id> putByCidNumberStateKind(Member object) {
    return putByIndex(r'cid_number_state_kind', object);
  }

  Id putByCidNumberStateKindSync(Member object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'cid_number_state_kind',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByCidNumberStateKind(List<Member> objects) {
    return putAllByIndex(r'cid_number_state_kind', objects);
  }

  List<Id> putAllByCidNumberStateKindSync(
    List<Member> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_state_kind',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension MemberQueryWhereSort on QueryBuilder<Member, Member, QWhere> {
  QueryBuilder<Member, Member, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MemberQueryWhere on QueryBuilder<Member, Member, QWhereClause> {
  QueryBuilder<Member, Member, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> cidNumberEqualToAnyStateKind(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_state_kind',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause>
  cidNumberNotEqualToAnyStateKind(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause> cidNumberStateKindEqualTo(
    String cidNumber,
    String stateKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_state_kind',
          value: [cidNumber, stateKind],
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterWhereClause>
  cidNumberEqualToStateKindNotEqualTo(String cidNumber, String stateKind) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber],
                upper: [cidNumber, stateKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_state_kind',
                lower: [cidNumber],
                upper: [cidNumber, stateKind],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MemberQueryFilter on QueryBuilder<Member, Member, QFilterCondition> {
  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cid_number',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cid_number',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'state_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'state_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state_kind', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state_kind', value: ''),
      );
    });
  }
}

extension MemberQueryObject on QueryBuilder<Member, Member, QFilterCondition> {}

extension MemberQueryLinks on QueryBuilder<Member, Member, QFilterCondition> {}

extension MemberQuerySortBy on QueryBuilder<Member, Member, QSortBy> {
  QueryBuilder<Member, Member, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.desc);
    });
  }
}

extension MemberQuerySortThenBy on QueryBuilder<Member, Member, QSortThenBy> {
  QueryBuilder<Member, Member, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.desc);
    });
  }
}

extension MemberQueryWhereDistinct on QueryBuilder<Member, Member, QDistinct> {
  QueryBuilder<Member, Member, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Member, Member, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Member, Member, QDistinct> distinctByStateKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state_kind', caseSensitive: caseSensitive);
    });
  }
}

extension MemberQueryProperty on QueryBuilder<Member, Member, QQueryProperty> {
  QueryBuilder<Member, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> stateKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state_kind');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCreatorCollection on Isar {
  IsarCollection<Creator> get creators => this.collection();
}

const CreatorSchema = CollectionSchema(
  name: r'creator',
  id: -6478246287788314136,
  properties: {
    r'body_data': PropertySchema(
      id: 0,
      name: r'body_data',
      type: IsarType.string,
    ),
    r'cid_number': PropertySchema(
      id: 1,
      name: r'cid_number',
      type: IsarType.string,
    ),
  },

  estimateSize: _creatorEstimateSize,
  serialize: _creatorSerialize,
  deserialize: _creatorDeserialize,
  deserializeProp: _creatorDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number': IndexSchema(
      id: 5073804840546792610,
      name: r'cid_number',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _creatorGetId,
  getLinks: _creatorGetLinks,
  attach: _creatorAttach,
  version: '3.3.2',
);

int _creatorEstimateSize(
  Creator object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  return bytesCount;
}

void _creatorSerialize(
  Creator object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
  writer.writeString(offsets[1], object.cidNumber);
}

Creator _creatorDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Creator();
  object.bodyData = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.rowId = id;
  return object;
}

P _creatorDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _creatorGetId(Creator object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _creatorGetLinks(Creator object) {
  return [];
}

void _creatorAttach(IsarCollection<dynamic> col, Id id, Creator object) {
  object.rowId = id;
}

extension CreatorByIndex on IsarCollection<Creator> {
  Future<Creator?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  Creator? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<Creator?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<Creator?> getAllByCidNumberSync(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'cid_number', values);
  }

  Future<int> deleteAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'cid_number', values);
  }

  int deleteAllByCidNumberSync(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'cid_number', values);
  }

  Future<Id> putByCidNumber(Creator object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(Creator object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<Creator> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<Creator> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension CreatorQueryWhereSort on QueryBuilder<Creator, Creator, QWhere> {
  QueryBuilder<Creator, Creator, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CreatorQueryWhere on QueryBuilder<Creator, Creator, QWhereClause> {
  QueryBuilder<Creator, Creator, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterWhereClause> cidNumberNotEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension CreatorQueryFilter
    on QueryBuilder<Creator, Creator, QFilterCondition> {
  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cid_number',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cid_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cid_number',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CreatorQueryObject
    on QueryBuilder<Creator, Creator, QFilterCondition> {}

extension CreatorQueryLinks
    on QueryBuilder<Creator, Creator, QFilterCondition> {}

extension CreatorQuerySortBy on QueryBuilder<Creator, Creator, QSortBy> {
  QueryBuilder<Creator, Creator, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }
}

extension CreatorQuerySortThenBy
    on QueryBuilder<Creator, Creator, QSortThenBy> {
  QueryBuilder<Creator, Creator, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension CreatorQueryWhereDistinct
    on QueryBuilder<Creator, Creator, QDistinct> {
  QueryBuilder<Creator, Creator, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Creator, Creator, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }
}

extension CreatorQueryProperty
    on QueryBuilder<Creator, Creator, QQueryProperty> {
  QueryBuilder<Creator, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Creator, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }

  QueryBuilder<Creator, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAccountCollection on Isar {
  IsarCollection<Account> get accounts => this.collection();
}

const AccountSchema = CollectionSchema(
  name: r'account',
  id: -5827943236100964141,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'account_name': PropertySchema(
      id: 1,
      name: r'account_name',
      type: IsarType.string,
    ),
    r'added_at': PropertySchema(id: 2, name: r'added_at', type: IsarType.long),
    r'admin_accounts': PropertySchema(
      id: 3,
      name: r'admin_accounts',
      type: IsarType.stringList,
    ),
    r'creator_account': PropertySchema(
      id: 4,
      name: r'creator_account',
      type: IsarType.string,
    ),
    r'is_found': PropertySchema(id: 5, name: r'is_found', type: IsarType.bool),
  },

  estimateSize: _accountEstimateSize,
  serialize: _accountSerialize,
  deserialize: _accountDeserialize,
  deserializeProp: _accountDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id': IndexSchema(
      id: 3848080515527097000,
      name: r'account_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'added_at': IndexSchema(
      id: -1635581074781047109,
      name: r'added_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'added_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'is_found': IndexSchema(
      id: 2059846674314974340,
      name: r'is_found',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'is_found',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _accountGetId,
  getLinks: _accountGetLinks,
  attach: _accountAttach,
  version: '3.3.2',
);

int _accountEstimateSize(
  Account object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.accountName.length * 3;
  bytesCount += 3 + object.adminAccounts.length * 3;
  {
    for (var i = 0; i < object.adminAccounts.length; i++) {
      final value = object.adminAccounts[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.creatorAccount.length * 3;
  return bytesCount;
}

void _accountSerialize(
  Account object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.accountName);
  writer.writeLong(offsets[2], object.addedAt);
  writer.writeStringList(offsets[3], object.adminAccounts);
  writer.writeString(offsets[4], object.creatorAccount);
  writer.writeBool(offsets[5], object.isFound);
}

Account _accountDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Account();
  object.accountId = reader.readString(offsets[0]);
  object.accountName = reader.readString(offsets[1]);
  object.addedAt = reader.readLong(offsets[2]);
  object.adminAccounts = reader.readStringList(offsets[3]) ?? [];
  object.creatorAccount = reader.readString(offsets[4]);
  object.isFound = reader.readBool(offsets[5]);
  object.rowId = id;
  return object;
}

P _accountDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _accountGetId(Account object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _accountGetLinks(Account object) {
  return [];
}

void _accountAttach(IsarCollection<dynamic> col, Id id, Account object) {
  object.rowId = id;
}

extension AccountByIndex on IsarCollection<Account> {
  Future<Account?> getByAccountId(String accountId) {
    return getByIndex(r'account_id', [accountId]);
  }

  Account? getByAccountIdSync(String accountId) {
    return getByIndexSync(r'account_id', [accountId]);
  }

  Future<bool> deleteByAccountId(String accountId) {
    return deleteByIndex(r'account_id', [accountId]);
  }

  bool deleteByAccountIdSync(String accountId) {
    return deleteByIndexSync(r'account_id', [accountId]);
  }

  Future<List<Account?>> getAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'account_id', values);
  }

  List<Account?> getAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'account_id', values);
  }

  Future<int> deleteAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'account_id', values);
  }

  int deleteAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'account_id', values);
  }

  Future<Id> putByAccountId(Account object) {
    return putByIndex(r'account_id', object);
  }

  Id putByAccountIdSync(Account object, {bool saveLinks = true}) {
    return putByIndexSync(r'account_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAccountId(List<Account> objects) {
    return putAllByIndex(r'account_id', objects);
  }

  List<Id> putAllByAccountIdSync(
    List<Account> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'account_id', objects, saveLinks: saveLinks);
  }
}

extension AccountQueryWhereSort on QueryBuilder<Account, Account, QWhere> {
  QueryBuilder<Account, Account, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Account, Account, QAfterWhere> anyAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'added_at'),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhere> anyIsFound() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'is_found'),
      );
    });
  }
}

extension AccountQueryWhere on QueryBuilder<Account, Account, QWhereClause> {
  QueryBuilder<Account, Account, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> accountIdEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> accountIdNotEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> addedAtEqualTo(
    int addedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'added_at', value: [addedAt]),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> addedAtNotEqualTo(
    int addedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'added_at',
                lower: [],
                upper: [addedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'added_at',
                lower: [addedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'added_at',
                lower: [addedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'added_at',
                lower: [],
                upper: [addedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> addedAtGreaterThan(
    int addedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'added_at',
          lower: [addedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> addedAtLessThan(
    int addedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'added_at',
          lower: [],
          upper: [addedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> addedAtBetween(
    int lowerAddedAt,
    int upperAddedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'added_at',
          lower: [lowerAddedAt],
          includeLower: includeLower,
          upper: [upperAddedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> isFoundEqualTo(
    bool isFound,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'is_found', value: [isFound]),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterWhereClause> isFoundNotEqualTo(
    bool isFound,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'is_found',
                lower: [],
                upper: [isFound],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'is_found',
                lower: [isFound],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'is_found',
                lower: [isFound],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'is_found',
                lower: [],
                upper: [isFound],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension AccountQueryFilter
    on QueryBuilder<Account, Account, QFilterCondition> {
  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> accountNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_name', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  accountNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_name', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> addedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'added_at', value: value),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> addedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'added_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> addedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'added_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> addedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'added_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'admin_accounts',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'admin_accounts',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'admin_accounts',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'admin_accounts', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'admin_accounts', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'admin_accounts', length, true, length, true);
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> adminAccountsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'admin_accounts', 0, true, 0, true);
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'admin_accounts', 0, false, 999999, true);
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'admin_accounts', 0, true, length, include);
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'admin_accounts', length, include, 999999, true);
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  adminAccountsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'admin_accounts',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  creatorAccountGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'creator_account',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  creatorAccountStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'creator_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> creatorAccountMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'creator_account',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  creatorAccountIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'creator_account', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition>
  creatorAccountIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'creator_account', value: ''),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> isFoundEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'is_found', value: value),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Account, Account, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AccountQueryObject
    on QueryBuilder<Account, Account, QFilterCondition> {}

extension AccountQueryLinks
    on QueryBuilder<Account, Account, QFilterCondition> {}

extension AccountQuerySortBy on QueryBuilder<Account, Account, QSortBy> {
  QueryBuilder<Account, Account, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByAccountName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_name', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByAccountNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_name', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'added_at', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'added_at', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByCreatorAccount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_account', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByCreatorAccountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_account', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByIsFound() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_found', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> sortByIsFoundDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_found', Sort.desc);
    });
  }
}

extension AccountQuerySortThenBy
    on QueryBuilder<Account, Account, QSortThenBy> {
  QueryBuilder<Account, Account, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByAccountName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_name', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByAccountNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_name', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'added_at', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'added_at', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByCreatorAccount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_account', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByCreatorAccountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_account', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByIsFound() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_found', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByIsFoundDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_found', Sort.desc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension AccountQueryWhereDistinct
    on QueryBuilder<Account, Account, QDistinct> {
  QueryBuilder<Account, Account, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Account, Account, QDistinct> distinctByAccountName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Account, Account, QDistinct> distinctByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'added_at');
    });
  }

  QueryBuilder<Account, Account, QDistinct> distinctByAdminAccounts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'admin_accounts');
    });
  }

  QueryBuilder<Account, Account, QDistinct> distinctByCreatorAccount({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'creator_account',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Account, Account, QDistinct> distinctByIsFound() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'is_found');
    });
  }
}

extension AccountQueryProperty
    on QueryBuilder<Account, Account, QQueryProperty> {
  QueryBuilder<Account, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Account, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Account, String, QQueryOperations> accountNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_name');
    });
  }

  QueryBuilder<Account, int, QQueryOperations> addedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'added_at');
    });
  }

  QueryBuilder<Account, List<String>, QQueryOperations>
  adminAccountsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'admin_accounts');
    });
  }

  QueryBuilder<Account, String, QQueryOperations> creatorAccountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'creator_account');
    });
  }

  QueryBuilder<Account, bool, QQueryOperations> isFoundProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'is_found');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetActionCollection on Isar {
  IsarCollection<Action> get actions => this.collection();
}

const ActionSchema = CollectionSchema(
  name: r'action',
  id: -2948318935682215514,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'action_kind': PropertySchema(
      id: 1,
      name: r'action_kind',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 2,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'final_at': PropertySchema(id: 3, name: r'final_at', type: IsarType.long),
    r'no_count': PropertySchema(id: 4, name: r'no_count', type: IsarType.long),
    r'proposal_id': PropertySchema(
      id: 5,
      name: r'proposal_id',
      type: IsarType.long,
    ),
    r'proposal_state': PropertySchema(
      id: 6,
      name: r'proposal_state',
      type: IsarType.string,
    ),
    r'snapshot_data': PropertySchema(
      id: 7,
      name: r'snapshot_data',
      type: IsarType.string,
    ),
    r'yes_count': PropertySchema(
      id: 8,
      name: r'yes_count',
      type: IsarType.long,
    ),
  },

  estimateSize: _actionEstimateSize,
  serialize: _actionSerialize,
  deserialize: _actionDeserialize,
  deserializeProp: _actionDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id_proposal_id': IndexSchema(
      id: 35444471039370691,
      name: r'account_id_proposal_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'proposal_id',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'action_kind': IndexSchema(
      id: -2919321054537354383,
      name: r'action_kind',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'action_kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'proposal_state': IndexSchema(
      id: 1733742963513769442,
      name: r'proposal_state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'proposal_state',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'created_at': IndexSchema(
      id: 6296488693525790031,
      name: r'created_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'created_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _actionGetId,
  getLinks: _actionGetLinks,
  attach: _actionAttach,
  version: '3.3.2',
);

int _actionEstimateSize(
  Action object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.actionKind.length * 3;
  bytesCount += 3 + object.proposalState.length * 3;
  {
    final value = object.snapshotData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _actionSerialize(
  Action object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.actionKind);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.finalAt);
  writer.writeLong(offsets[4], object.noCount);
  writer.writeLong(offsets[5], object.proposalId);
  writer.writeString(offsets[6], object.proposalState);
  writer.writeString(offsets[7], object.snapshotData);
  writer.writeLong(offsets[8], object.yesCount);
}

Action _actionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Action();
  object.accountId = reader.readString(offsets[0]);
  object.actionKind = reader.readString(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.finalAt = reader.readLongOrNull(offsets[3]);
  object.noCount = reader.readLong(offsets[4]);
  object.proposalId = reader.readLong(offsets[5]);
  object.proposalState = reader.readString(offsets[6]);
  object.rowId = id;
  object.snapshotData = reader.readStringOrNull(offsets[7]);
  object.yesCount = reader.readLong(offsets[8]);
  return object;
}

P _actionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _actionGetId(Action object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _actionGetLinks(Action object) {
  return [];
}

void _actionAttach(IsarCollection<dynamic> col, Id id, Action object) {
  object.rowId = id;
}

extension ActionByIndex on IsarCollection<Action> {
  Future<Action?> getByAccountIdProposalId(String accountId, int proposalId) {
    return getByIndex(r'account_id_proposal_id', [accountId, proposalId]);
  }

  Action? getByAccountIdProposalIdSync(String accountId, int proposalId) {
    return getByIndexSync(r'account_id_proposal_id', [accountId, proposalId]);
  }

  Future<bool> deleteByAccountIdProposalId(String accountId, int proposalId) {
    return deleteByIndex(r'account_id_proposal_id', [accountId, proposalId]);
  }

  bool deleteByAccountIdProposalIdSync(String accountId, int proposalId) {
    return deleteByIndexSync(r'account_id_proposal_id', [
      accountId,
      proposalId,
    ]);
  }

  Future<List<Action?>> getAllByAccountIdProposalId(
    List<String> accountIdValues,
    List<int> proposalIdValues,
  ) {
    final len = accountIdValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([accountIdValues[i], proposalIdValues[i]]);
    }

    return getAllByIndex(r'account_id_proposal_id', values);
  }

  List<Action?> getAllByAccountIdProposalIdSync(
    List<String> accountIdValues,
    List<int> proposalIdValues,
  ) {
    final len = accountIdValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([accountIdValues[i], proposalIdValues[i]]);
    }

    return getAllByIndexSync(r'account_id_proposal_id', values);
  }

  Future<int> deleteAllByAccountIdProposalId(
    List<String> accountIdValues,
    List<int> proposalIdValues,
  ) {
    final len = accountIdValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([accountIdValues[i], proposalIdValues[i]]);
    }

    return deleteAllByIndex(r'account_id_proposal_id', values);
  }

  int deleteAllByAccountIdProposalIdSync(
    List<String> accountIdValues,
    List<int> proposalIdValues,
  ) {
    final len = accountIdValues.length;
    assert(
      proposalIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([accountIdValues[i], proposalIdValues[i]]);
    }

    return deleteAllByIndexSync(r'account_id_proposal_id', values);
  }

  Future<Id> putByAccountIdProposalId(Action object) {
    return putByIndex(r'account_id_proposal_id', object);
  }

  Id putByAccountIdProposalIdSync(Action object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'account_id_proposal_id',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByAccountIdProposalId(List<Action> objects) {
    return putAllByIndex(r'account_id_proposal_id', objects);
  }

  List<Id> putAllByAccountIdProposalIdSync(
    List<Action> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'account_id_proposal_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ActionQueryWhereSort on QueryBuilder<Action, Action, QWhere> {
  QueryBuilder<Action, Action, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Action, Action, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'created_at'),
      );
    });
  }
}

extension ActionQueryWhere on QueryBuilder<Action, Action, QWhereClause> {
  QueryBuilder<Action, Action, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> accountIdEqualToAnyProposalId(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'account_id_proposal_id',
          value: [accountId],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause>
  accountIdNotEqualToAnyProposalId(String accountId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> accountIdProposalIdEqualTo(
    String accountId,
    int proposalId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'account_id_proposal_id',
          value: [accountId, proposalId],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause>
  accountIdEqualToProposalIdNotEqualTo(String accountId, int proposalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId],
                upper: [accountId, proposalId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId, proposalId],
                includeLower: false,
                upper: [accountId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId, proposalId],
                includeLower: false,
                upper: [accountId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id_proposal_id',
                lower: [accountId],
                upper: [accountId, proposalId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause>
  accountIdEqualToProposalIdGreaterThan(
    String accountId,
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'account_id_proposal_id',
          lower: [accountId, proposalId],
          includeLower: include,
          upper: [accountId],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause>
  accountIdEqualToProposalIdLessThan(
    String accountId,
    int proposalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'account_id_proposal_id',
          lower: [accountId],
          upper: [accountId, proposalId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause>
  accountIdEqualToProposalIdBetween(
    String accountId,
    int lowerProposalId,
    int upperProposalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'account_id_proposal_id',
          lower: [accountId, lowerProposalId],
          includeLower: includeLower,
          upper: [accountId, upperProposalId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> actionKindEqualTo(
    String actionKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'action_kind',
          value: [actionKind],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> actionKindNotEqualTo(
    String actionKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'action_kind',
                lower: [],
                upper: [actionKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'action_kind',
                lower: [actionKind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'action_kind',
                lower: [actionKind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'action_kind',
                lower: [],
                upper: [actionKind],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> proposalStateEqualTo(
    String proposalState,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'proposal_state',
          value: [proposalState],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> proposalStateNotEqualTo(
    String proposalState,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_state',
                lower: [],
                upper: [proposalState],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_state',
                lower: [proposalState],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_state',
                lower: [proposalState],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'proposal_state',
                lower: [],
                upper: [proposalState],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> createdAtEqualTo(
    int createdAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'created_at', value: [createdAt]),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> createdAtNotEqualTo(
    int createdAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> createdAtGreaterThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> createdAtLessThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterWhereClause> createdAtBetween(
    int lowerCreatedAt,
    int upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ActionQueryFilter on QueryBuilder<Action, Action, QFilterCondition> {
  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'action_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'action_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'action_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'action_kind', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'action_kind', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> createdAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'final_at'),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'final_at'),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'final_at', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'final_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'final_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> finalAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'final_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> noCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'no_count', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> noCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'no_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> noCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'no_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> noCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'no_count',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_id', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proposal_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'proposal_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'proposal_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'proposal_state', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition>
  proposalStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'proposal_state', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'snapshot_data'),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'snapshot_data'),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'snapshot_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'snapshot_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'snapshot_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snapshot_data', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'snapshot_data', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> yesCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'yes_count', value: value),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> yesCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'yes_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> yesCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'yes_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> yesCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'yes_count',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ActionQueryObject on QueryBuilder<Action, Action, QFilterCondition> {}

extension ActionQueryLinks on QueryBuilder<Action, Action, QFilterCondition> {}

extension ActionQuerySortBy on QueryBuilder<Action, Action, QSortBy> {
  QueryBuilder<Action, Action, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByActionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action_kind', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByActionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action_kind', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByFinalAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'final_at', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByFinalAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'final_at', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByNoCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'no_count', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByNoCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'no_count', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByProposalState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_state', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByProposalStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_state', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortBySnapshotData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot_data', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortBySnapshotDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot_data', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByYesCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'yes_count', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByYesCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'yes_count', Sort.desc);
    });
  }
}

extension ActionQuerySortThenBy on QueryBuilder<Action, Action, QSortThenBy> {
  QueryBuilder<Action, Action, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByActionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action_kind', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByActionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action_kind', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByFinalAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'final_at', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByFinalAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'final_at', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByNoCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'no_count', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByNoCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'no_count', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByProposalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByProposalState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_state', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByProposalStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proposal_state', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenBySnapshotData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot_data', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenBySnapshotDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot_data', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByYesCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'yes_count', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByYesCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'yes_count', Sort.desc);
    });
  }
}

extension ActionQueryWhereDistinct on QueryBuilder<Action, Action, QDistinct> {
  QueryBuilder<Action, Action, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByActionKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'action_kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByFinalAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'final_at');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByNoCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'no_count');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proposal_id');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByProposalState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'proposal_state',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctBySnapshotData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'snapshot_data',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByYesCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'yes_count');
    });
  }
}

extension ActionQueryProperty on QueryBuilder<Action, Action, QQueryProperty> {
  QueryBuilder<Action, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Action, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Action, String, QQueryOperations> actionKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'action_kind');
    });
  }

  QueryBuilder<Action, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<Action, int?, QQueryOperations> finalAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'final_at');
    });
  }

  QueryBuilder<Action, int, QQueryOperations> noCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'no_count');
    });
  }

  QueryBuilder<Action, int, QQueryOperations> proposalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_id');
    });
  }

  QueryBuilder<Action, String, QQueryOperations> proposalStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_state');
    });
  }

  QueryBuilder<Action, String?, QQueryOperations> snapshotDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snapshot_data');
    });
  }

  QueryBuilder<Action, int, QQueryOperations> yesCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'yes_count');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBodyCollection on Isar {
  IsarCollection<Body> get bodys => this.collection();
}

const BodySchema = CollectionSchema(
  name: r'body',
  id: -8866803791400279558,
  properties: {},

  estimateSize: _bodyEstimateSize,
  serialize: _bodySerialize,
  deserialize: _bodyDeserialize,
  deserializeProp: _bodyDeserializeProp,
  idName: r'row_id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _bodyGetId,
  getLinks: _bodyGetLinks,
  attach: _bodyAttach,
  version: '3.3.2',
);

int _bodyEstimateSize(
  Body object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _bodySerialize(
  Body object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {}
Body _bodyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Body();
  object.rowId = id;
  return object;
}

P _bodyDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bodyGetId(Body object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _bodyGetLinks(Body object) {
  return [];
}

void _bodyAttach(IsarCollection<dynamic> col, Id id, Body object) {
  object.rowId = id;
}

extension BodyQueryWhereSort on QueryBuilder<Body, Body, QWhere> {
  QueryBuilder<Body, Body, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BodyQueryWhere on QueryBuilder<Body, Body, QWhereClause> {
  QueryBuilder<Body, Body, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Body, Body, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BodyQueryFilter on QueryBuilder<Body, Body, QFilterCondition> {
  QueryBuilder<Body, Body, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Body, Body, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BodyQueryObject on QueryBuilder<Body, Body, QFilterCondition> {}

extension BodyQueryLinks on QueryBuilder<Body, Body, QFilterCondition> {}

extension BodyQuerySortBy on QueryBuilder<Body, Body, QSortBy> {}

extension BodyQuerySortThenBy on QueryBuilder<Body, Body, QSortThenBy> {
  QueryBuilder<Body, Body, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Body, Body, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension BodyQueryWhereDistinct on QueryBuilder<Body, Body, QDistinct> {}

extension BodyQueryProperty on QueryBuilder<Body, Body, QQueryProperty> {
  QueryBuilder<Body, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWalletCursorCollection on Isar {
  IsarCollection<WalletCursor> get walletCursors => this.collection();
}

const WalletCursorSchema = CollectionSchema(
  name: r'cursor',
  id: -7058571471948605105,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 1,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'cursor_block': PropertySchema(
      id: 2,
      name: r'cursor_block',
      type: IsarType.long,
    ),
    r'genesis_hash': PropertySchema(
      id: 3,
      name: r'genesis_hash',
      type: IsarType.string,
    ),
    r'start_block': PropertySchema(
      id: 4,
      name: r'start_block',
      type: IsarType.long,
    ),
  },

  estimateSize: _walletCursorEstimateSize,
  serialize: _walletCursorSerialize,
  deserialize: _walletCursorDeserialize,
  deserializeProp: _walletCursorDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id': IndexSchema(
      id: 3848080515527097000,
      name: r'account_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _walletCursorGetId,
  getLinks: _walletCursorGetLinks,
  attach: _walletCursorAttach,
  version: '3.3.2',
);

int _walletCursorEstimateSize(
  WalletCursor object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.genesisHash.length * 3;
  return bytesCount;
}

void _walletCursorSerialize(
  WalletCursor object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.createdAt);
  writer.writeLong(offsets[2], object.cursorBlock);
  writer.writeString(offsets[3], object.genesisHash);
  writer.writeLong(offsets[4], object.startBlock);
}

WalletCursor _walletCursorDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WalletCursor();
  object.accountId = reader.readString(offsets[0]);
  object.createdAt = reader.readLong(offsets[1]);
  object.cursorBlock = reader.readLong(offsets[2]);
  object.genesisHash = reader.readString(offsets[3]);
  object.rowId = id;
  object.startBlock = reader.readLong(offsets[4]);
  return object;
}

P _walletCursorDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _walletCursorGetId(WalletCursor object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _walletCursorGetLinks(WalletCursor object) {
  return [];
}

void _walletCursorAttach(
  IsarCollection<dynamic> col,
  Id id,
  WalletCursor object,
) {
  object.rowId = id;
}

extension WalletCursorByIndex on IsarCollection<WalletCursor> {
  Future<WalletCursor?> getByAccountId(String accountId) {
    return getByIndex(r'account_id', [accountId]);
  }

  WalletCursor? getByAccountIdSync(String accountId) {
    return getByIndexSync(r'account_id', [accountId]);
  }

  Future<bool> deleteByAccountId(String accountId) {
    return deleteByIndex(r'account_id', [accountId]);
  }

  bool deleteByAccountIdSync(String accountId) {
    return deleteByIndexSync(r'account_id', [accountId]);
  }

  Future<List<WalletCursor?>> getAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'account_id', values);
  }

  List<WalletCursor?> getAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'account_id', values);
  }

  Future<int> deleteAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'account_id', values);
  }

  int deleteAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'account_id', values);
  }

  Future<Id> putByAccountId(WalletCursor object) {
    return putByIndex(r'account_id', object);
  }

  Id putByAccountIdSync(WalletCursor object, {bool saveLinks = true}) {
    return putByIndexSync(r'account_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAccountId(List<WalletCursor> objects) {
    return putAllByIndex(r'account_id', objects);
  }

  List<Id> putAllByAccountIdSync(
    List<WalletCursor> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'account_id', objects, saveLinks: saveLinks);
  }
}

extension WalletCursorQueryWhereSort
    on QueryBuilder<WalletCursor, WalletCursor, QWhere> {
  QueryBuilder<WalletCursor, WalletCursor, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WalletCursorQueryWhere
    on QueryBuilder<WalletCursor, WalletCursor, QWhereClause> {
  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> rowIdEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> rowIdNotEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause> accountIdEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterWhereClause>
  accountIdNotEqualTo(String accountId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension WalletCursorQueryFilter
    on QueryBuilder<WalletCursor, WalletCursor, QFilterCondition> {
  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  createdAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  createdAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  cursorBlockEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cursor_block', value: value),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  cursorBlockGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cursor_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  cursorBlockLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cursor_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  cursorBlockBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cursor_block',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'genesis_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'genesis_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'genesis_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'genesis_hash', value: ''),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  genesisHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'genesis_hash', value: ''),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  startBlockEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'start_block', value: value),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  startBlockGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'start_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  startBlockLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'start_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  startBlockBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'start_block',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension WalletCursorQueryObject
    on QueryBuilder<WalletCursor, WalletCursor, QFilterCondition> {}

extension WalletCursorQueryLinks
    on QueryBuilder<WalletCursor, WalletCursor, QFilterCondition> {}

extension WalletCursorQuerySortBy
    on QueryBuilder<WalletCursor, WalletCursor, QSortBy> {
  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByCursorBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursor_block', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  sortByCursorBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursor_block', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesis_hash', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  sortByGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesis_hash', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> sortByStartBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'start_block', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  sortByStartBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'start_block', Sort.desc);
    });
  }
}

extension WalletCursorQuerySortThenBy
    on QueryBuilder<WalletCursor, WalletCursor, QSortThenBy> {
  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByCursorBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursor_block', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  thenByCursorBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursor_block', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesis_hash', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  thenByGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesis_hash', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByStartBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'start_block', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy>
  thenByStartBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'start_block', Sort.desc);
    });
  }
}

extension WalletCursorQueryWhereDistinct
    on QueryBuilder<WalletCursor, WalletCursor, QDistinct> {
  QueryBuilder<WalletCursor, WalletCursor, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QDistinct> distinctByCursorBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cursor_block');
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QDistinct> distinctByGenesisHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genesis_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QDistinct> distinctByStartBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'start_block');
    });
  }
}

extension WalletCursorQueryProperty
    on QueryBuilder<WalletCursor, WalletCursor, QQueryProperty> {
  QueryBuilder<WalletCursor, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<WalletCursor, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<WalletCursor, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<WalletCursor, int, QQueryOperations> cursorBlockProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cursor_block');
    });
  }

  QueryBuilder<WalletCursor, String, QQueryOperations> genesisHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genesis_hash');
    });
  }

  QueryBuilder<WalletCursor, int, QQueryOperations> startBlockProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'start_block');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEntryCollection on Isar {
  IsarCollection<Entry> get entrys => this.collection();
}

const EntrySchema = CollectionSchema(
  name: r'entry',
  id: -8481733259686664850,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'amount_delta': PropertySchema(
      id: 1,
      name: r'amount_delta',
      type: IsarType.string,
    ),
    r'block_hash': PropertySchema(
      id: 2,
      name: r'block_hash',
      type: IsarType.string,
    ),
    r'block_number': PropertySchema(
      id: 3,
      name: r'block_number',
      type: IsarType.long,
    ),
    r'call_hash': PropertySchema(
      id: 4,
      name: r'call_hash',
      type: IsarType.string,
    ),
    r'confirmed_at': PropertySchema(
      id: 5,
      name: r'confirmed_at',
      type: IsarType.long,
    ),
    r'created_at': PropertySchema(
      id: 6,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'entry_kind': PropertySchema(
      id: 7,
      name: r'entry_kind',
      type: IsarType.string,
    ),
    r'entry_source': PropertySchema(
      id: 8,
      name: r'entry_source',
      type: IsarType.string,
    ),
    r'entry_state': PropertySchema(
      id: 9,
      name: r'entry_state',
      type: IsarType.string,
    ),
    r'event_index': PropertySchema(
      id: 10,
      name: r'event_index',
      type: IsarType.long,
    ),
    r'execution_id': PropertySchema(
      id: 11,
      name: r'execution_id',
      type: IsarType.string,
    ),
    r'extrinsic_index': PropertySchema(
      id: 12,
      name: r'extrinsic_index',
      type: IsarType.long,
    ),
    r'fail_reason': PropertySchema(
      id: 13,
      name: r'fail_reason',
      type: IsarType.string,
    ),
    r'fee_amount': PropertySchema(
      id: 14,
      name: r'fee_amount',
      type: IsarType.string,
    ),
    r'from_address': PropertySchema(
      id: 15,
      name: r'from_address',
      type: IsarType.string,
    ),
    r'to_address': PropertySchema(
      id: 16,
      name: r'to_address',
      type: IsarType.string,
    ),
    r'transfer_amount': PropertySchema(
      id: 17,
      name: r'transfer_amount',
      type: IsarType.string,
    ),
    r'tx_hash': PropertySchema(id: 18, name: r'tx_hash', type: IsarType.string),
    r'tx_note': PropertySchema(id: 19, name: r'tx_note', type: IsarType.string),
  },

  estimateSize: _entryEstimateSize,
  serialize: _entrySerialize,
  deserialize: _entryDeserialize,
  deserializeProp: _entryDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'account_id': IndexSchema(
      id: 3848080515527097000,
      name: r'account_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'account_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'created_at': IndexSchema(
      id: 6296488693525790031,
      name: r'created_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'created_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _entryGetId,
  getLinks: _entryGetLinks,
  attach: _entryAttach,
  version: '3.3.2',
);

int _entryEstimateSize(
  Entry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.amountDelta.length * 3;
  {
    final value = object.blockHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.callHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.entryKind.length * 3;
  bytesCount += 3 + object.entrySource.length * 3;
  bytesCount += 3 + object.entryState.length * 3;
  {
    final value = object.executionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.failReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.feeAmount;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.fromAddress;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.toAddress;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.transferAmount;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.txHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.txNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _entrySerialize(
  Entry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.amountDelta);
  writer.writeString(offsets[2], object.blockHash);
  writer.writeLong(offsets[3], object.blockNumber);
  writer.writeString(offsets[4], object.callHash);
  writer.writeLong(offsets[5], object.confirmedAt);
  writer.writeLong(offsets[6], object.createdAt);
  writer.writeString(offsets[7], object.entryKind);
  writer.writeString(offsets[8], object.entrySource);
  writer.writeString(offsets[9], object.entryState);
  writer.writeLong(offsets[10], object.eventIndex);
  writer.writeString(offsets[11], object.executionId);
  writer.writeLong(offsets[12], object.extrinsicIndex);
  writer.writeString(offsets[13], object.failReason);
  writer.writeString(offsets[14], object.feeAmount);
  writer.writeString(offsets[15], object.fromAddress);
  writer.writeString(offsets[16], object.toAddress);
  writer.writeString(offsets[17], object.transferAmount);
  writer.writeString(offsets[18], object.txHash);
  writer.writeString(offsets[19], object.txNote);
}

Entry _entryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Entry();
  object.accountId = reader.readString(offsets[0]);
  object.amountDelta = reader.readString(offsets[1]);
  object.blockHash = reader.readStringOrNull(offsets[2]);
  object.blockNumber = reader.readLongOrNull(offsets[3]);
  object.callHash = reader.readStringOrNull(offsets[4]);
  object.confirmedAt = reader.readLongOrNull(offsets[5]);
  object.createdAt = reader.readLong(offsets[6]);
  object.entryKind = reader.readString(offsets[7]);
  object.entrySource = reader.readString(offsets[8]);
  object.entryState = reader.readString(offsets[9]);
  object.eventIndex = reader.readLongOrNull(offsets[10]);
  object.executionId = reader.readStringOrNull(offsets[11]);
  object.extrinsicIndex = reader.readLongOrNull(offsets[12]);
  object.failReason = reader.readStringOrNull(offsets[13]);
  object.feeAmount = reader.readStringOrNull(offsets[14]);
  object.fromAddress = reader.readStringOrNull(offsets[15]);
  object.rowId = id;
  object.toAddress = reader.readStringOrNull(offsets[16]);
  object.transferAmount = reader.readStringOrNull(offsets[17]);
  object.txHash = reader.readStringOrNull(offsets[18]);
  object.txNote = reader.readStringOrNull(offsets[19]);
  return object;
}

P _entryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _entryGetId(Entry object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _entryGetLinks(Entry object) {
  return [];
}

void _entryAttach(IsarCollection<dynamic> col, Id id, Entry object) {
  object.rowId = id;
}

extension EntryQueryWhereSort on QueryBuilder<Entry, Entry, QWhere> {
  QueryBuilder<Entry, Entry, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'created_at'),
      );
    });
  }
}

extension EntryQueryWhere on QueryBuilder<Entry, Entry, QWhereClause> {
  QueryBuilder<Entry, Entry, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: rowId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: rowId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> rowIdBetween(
    Id lowerRowId,
    Id upperRowId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerRowId,
          includeLower: includeLower,
          upper: upperRowId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> accountIdEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> accountIdNotEqualTo(
    String accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [accountId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'account_id',
                lower: [],
                upper: [accountId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> createdAtEqualTo(
    int createdAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'created_at', value: [createdAt]),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> createdAtNotEqualTo(
    int createdAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> createdAtGreaterThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> createdAtLessThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterWhereClause> createdAtBetween(
    int lowerCreatedAt,
    int upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension EntryQueryFilter on QueryBuilder<Entry, Entry, QFilterCondition> {
  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amount_delta',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'amount_delta',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'amount_delta',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'amount_delta', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> amountDeltaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'amount_delta', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'block_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'block_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'block_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'block_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'block_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'block_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'block_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'block_number'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'block_number'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'block_number', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'block_number',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'block_number',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> blockNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'block_number',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'call_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'call_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'call_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'call_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'call_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'call_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> callHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'call_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'confirmed_at'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'confirmed_at'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'confirmed_at', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'confirmed_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'confirmed_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> confirmedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'confirmed_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> createdAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entry_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entry_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entry_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entry_kind', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entry_kind', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entry_source',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entry_source',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entry_source',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entry_source', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entrySourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entry_source', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entry_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entry_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entry_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entry_state', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entry_state', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'event_index'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'event_index'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'event_index', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'event_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'event_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> eventIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'event_index',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'execution_id'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'execution_id'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'execution_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'execution_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'execution_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'execution_id', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> executionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'execution_id', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'extrinsic_index'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'extrinsic_index'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'extrinsic_index', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'extrinsic_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'extrinsic_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> extrinsicIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'extrinsic_index',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fail_reason'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fail_reason'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fail_reason',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fail_reason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fail_reason',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fail_reason', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> failReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fail_reason', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fee_amount'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fee_amount'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fee_amount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fee_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fee_amount',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fee_amount', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> feeAmountIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fee_amount', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'from_address'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'from_address'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'from_address',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'from_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'from_address',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'from_address', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> fromAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'from_address', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'row_id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'to_address'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'to_address'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'to_address',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'to_address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'to_address',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'to_address', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> toAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'to_address', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'transfer_amount'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'transfer_amount'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'transfer_amount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'transfer_amount',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'transfer_amount',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'transfer_amount', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> transferAmountIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'transfer_amount', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'tx_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'tx_hash'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tx_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tx_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tx_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tx_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tx_hash', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'tx_note'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'tx_note'),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tx_note',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tx_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tx_note',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tx_note', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> txNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tx_note', value: ''),
      );
    });
  }
}

extension EntryQueryObject on QueryBuilder<Entry, Entry, QFilterCondition> {}

extension EntryQueryLinks on QueryBuilder<Entry, Entry, QFilterCondition> {}

extension EntryQuerySortBy on QueryBuilder<Entry, Entry, QSortBy> {
  QueryBuilder<Entry, Entry, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByAmountDelta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount_delta', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByAmountDeltaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount_delta', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByBlockHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByBlockHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByBlockNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_number', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByBlockNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_number', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByCallHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'call_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByCallHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'call_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmed_at', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmed_at', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_kind', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_kind', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntrySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_source', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntrySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_source', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_state', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_state', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEventIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'event_index', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEventIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'event_index', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByExecutionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execution_id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByExecutionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execution_id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByExtrinsicIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extrinsic_index', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByExtrinsicIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extrinsic_index', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFailReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fail_reason', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFailReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fail_reason', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFeeAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fee_amount', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFeeAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fee_amount', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFromAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from_address', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByFromAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from_address', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByToAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to_address', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByToAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to_address', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTransferAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer_amount', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTransferAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer_amount', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTxHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTxHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTxNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_note', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByTxNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_note', Sort.desc);
    });
  }
}

extension EntryQuerySortThenBy on QueryBuilder<Entry, Entry, QSortThenBy> {
  QueryBuilder<Entry, Entry, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByAmountDelta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount_delta', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByAmountDeltaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount_delta', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByBlockHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByBlockHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByBlockNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_number', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByBlockNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'block_number', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByCallHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'call_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByCallHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'call_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmed_at', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmed_at', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_kind', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_kind', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntrySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_source', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntrySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_source', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_state', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entry_state', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEventIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'event_index', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEventIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'event_index', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByExecutionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execution_id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByExecutionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execution_id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByExtrinsicIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extrinsic_index', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByExtrinsicIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extrinsic_index', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFailReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fail_reason', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFailReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fail_reason', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFeeAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fee_amount', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFeeAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fee_amount', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFromAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from_address', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByFromAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'from_address', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByToAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to_address', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByToAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'to_address', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTransferAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer_amount', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTransferAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer_amount', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTxHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTxHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTxNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_note', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByTxNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_note', Sort.desc);
    });
  }
}

extension EntryQueryWhereDistinct on QueryBuilder<Entry, Entry, QDistinct> {
  QueryBuilder<Entry, Entry, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByAmountDelta({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amount_delta', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByBlockHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'block_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByBlockNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'block_number');
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByCallHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'call_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmed_at');
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntryKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entry_kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntrySource({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entry_source', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntryState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entry_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByEventIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'event_index');
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByExecutionId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'execution_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByExtrinsicIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'extrinsic_index');
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByFailReason({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fail_reason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByFeeAmount({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fee_amount', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByFromAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'from_address', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByToAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'to_address', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByTransferAmount({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'transfer_amount',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByTxHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tx_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByTxNote({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tx_note', caseSensitive: caseSensitive);
    });
  }
}

extension EntryQueryProperty on QueryBuilder<Entry, Entry, QQueryProperty> {
  QueryBuilder<Entry, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> amountDeltaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amount_delta');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> blockHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'block_hash');
    });
  }

  QueryBuilder<Entry, int?, QQueryOperations> blockNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'block_number');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> callHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'call_hash');
    });
  }

  QueryBuilder<Entry, int?, QQueryOperations> confirmedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmed_at');
    });
  }

  QueryBuilder<Entry, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> entryKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entry_kind');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> entrySourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entry_source');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> entryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entry_state');
    });
  }

  QueryBuilder<Entry, int?, QQueryOperations> eventIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'event_index');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> executionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'execution_id');
    });
  }

  QueryBuilder<Entry, int?, QQueryOperations> extrinsicIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'extrinsic_index');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> failReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fail_reason');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> feeAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fee_amount');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> fromAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'from_address');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> toAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'to_address');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> transferAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transfer_amount');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> txHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tx_hash');
    });
  }

  QueryBuilder<Entry, String?, QQueryOperations> txNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tx_note');
    });
  }
}
