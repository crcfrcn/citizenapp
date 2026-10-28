// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_isar.dart';

// ignore_for_file: experimental_member_use

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEditCollection on Isar {
  IsarCollection<Edit> get edits => this.collection();
}

const EditSchema = CollectionSchema(
  name: r'edit',
  id: 6580256518399030560,
  properties: {
    r'avatar_bytes': PropertySchema(
      id: 0,
      name: r'avatar_bytes',
      type: IsarType.byteList,
    ),
    r'banner_bytes': PropertySchema(
      id: 1,
      name: r'banner_bytes',
      type: IsarType.byteList,
    ),
    r'cid_number': PropertySchema(
      id: 2,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'content_hash': PropertySchema(
      id: 3,
      name: r'content_hash',
      type: IsarType.string,
    ),
    r'job_state': PropertySchema(
      id: 4,
      name: r'job_state',
      type: IsarType.string,
    ),
    r'request_data': PropertySchema(
      id: 5,
      name: r'request_data',
      type: IsarType.string,
    ),
    r'response_data': PropertySchema(
      id: 6,
      name: r'response_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _editEstimateSize,
  serialize: _editSerialize,
  deserialize: _editDeserialize,
  deserializeProp: _editDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number': IndexSchema(
      id: 5073804840546792610,
      name: r'cid_number',
      unique: true,
      replace: false,
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

  getId: _editGetId,
  getLinks: _editGetLinks,
  attach: _editAttach,
  version: '3.3.2',
);

int _editEstimateSize(
  Edit object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.avatarBytes.length;
  bytesCount += 3 + object.bannerBytes.length;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentHash.length * 3;
  bytesCount += 3 + object.jobState.length * 3;
  bytesCount += 3 + object.requestData.length * 3;
  {
    final value = object.responseData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _editSerialize(
  Edit object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeByteList(offsets[0], object.avatarBytes);
  writer.writeByteList(offsets[1], object.bannerBytes);
  writer.writeString(offsets[2], object.cidNumber);
  writer.writeString(offsets[3], object.contentHash);
  writer.writeString(offsets[4], object.jobState);
  writer.writeString(offsets[5], object.requestData);
  writer.writeString(offsets[6], object.responseData);
}

Edit _editDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Edit();
  object.avatarBytes = reader.readByteList(offsets[0]) ?? [];
  object.bannerBytes = reader.readByteList(offsets[1]) ?? [];
  object.cidNumber = reader.readString(offsets[2]);
  object.contentHash = reader.readString(offsets[3]);
  object.jobState = reader.readString(offsets[4]);
  object.requestData = reader.readString(offsets[5]);
  object.responseData = reader.readStringOrNull(offsets[6]);
  object.rowId = id;
  return object;
}

P _editDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readByteList(offset) ?? []) as P;
    case 1:
      return (reader.readByteList(offset) ?? []) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _editGetId(Edit object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _editGetLinks(Edit object) {
  return [];
}

void _editAttach(IsarCollection<dynamic> col, Id id, Edit object) {
  object.rowId = id;
}

extension EditByIndex on IsarCollection<Edit> {
  Future<Edit?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  Edit? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<Edit?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<Edit?> getAllByCidNumberSync(List<String> cidNumberValues) {
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

  Future<Id> putByCidNumber(Edit object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(Edit object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<Edit> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(List<Edit> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension EditQueryWhereSort on QueryBuilder<Edit, Edit, QWhere> {
  QueryBuilder<Edit, Edit, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EditQueryWhere on QueryBuilder<Edit, Edit, QWhereClause> {
  QueryBuilder<Edit, Edit, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Edit, Edit, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Edit, Edit, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterWhereClause> cidNumberNotEqualTo(
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

extension EditQueryFilter on QueryBuilder<Edit, Edit, QFilterCondition> {
  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesElementEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'avatar_bytes', value: value),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avatar_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avatar_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avatar_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'avatar_bytes', length, true, length, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'avatar_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'avatar_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'avatar_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'avatar_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> avatarBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'avatar_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesElementEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'banner_bytes', value: value),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'banner_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'banner_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'banner_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'banner_bytes', length, true, length, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'banner_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'banner_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'banner_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'banner_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> bannerBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'banner_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> contentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'job_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'job_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'job_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'request_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'request_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'request_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'request_data', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'request_data', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'response_data'),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'response_data'),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'response_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'response_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'response_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'response_data', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'response_data', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> rowIdBetween(
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

extension EditQueryObject on QueryBuilder<Edit, Edit, QFilterCondition> {}

extension EditQueryLinks on QueryBuilder<Edit, Edit, QFilterCondition> {}

extension EditQuerySortBy on QueryBuilder<Edit, Edit, QSortBy> {
  QueryBuilder<Edit, Edit, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByRequestData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request_data', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByRequestDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request_data', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByResponseData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response_data', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByResponseDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response_data', Sort.desc);
    });
  }
}

extension EditQuerySortThenBy on QueryBuilder<Edit, Edit, QSortThenBy> {
  QueryBuilder<Edit, Edit, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRequestData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request_data', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRequestDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request_data', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByResponseData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response_data', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByResponseDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response_data', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension EditQueryWhereDistinct on QueryBuilder<Edit, Edit, QDistinct> {
  QueryBuilder<Edit, Edit, QDistinct> distinctByAvatarBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'avatar_bytes');
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByBannerBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'banner_bytes');
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByContentHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByJobState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'job_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByRequestData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'request_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByResponseData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'response_data',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension EditQueryProperty on QueryBuilder<Edit, Edit, QQueryProperty> {
  QueryBuilder<Edit, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Edit, List<int>, QQueryOperations> avatarBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avatar_bytes');
    });
  }

  QueryBuilder<Edit, List<int>, QQueryOperations> bannerBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'banner_bytes');
    });
  }

  QueryBuilder<Edit, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Edit, String, QQueryOperations> contentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_hash');
    });
  }

  QueryBuilder<Edit, String, QQueryOperations> jobStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'job_state');
    });
  }

  QueryBuilder<Edit, String, QQueryOperations> requestDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'request_data');
    });
  }

  QueryBuilder<Edit, String?, QQueryOperations> responseDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'response_data');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProfileCollection on Isar {
  IsarCollection<Profile> get profiles => this.collection();
}

const ProfileSchema = CollectionSchema(
  name: r'profile',
  id: -2659518370872103978,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'profile_data': PropertySchema(
      id: 1,
      name: r'profile_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _profileEstimateSize,
  serialize: _profileSerialize,
  deserialize: _profileDeserialize,
  deserializeProp: _profileDeserializeProp,
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

  getId: _profileGetId,
  getLinks: _profileGetLinks,
  attach: _profileAttach,
  version: '3.3.2',
);

int _profileEstimateSize(
  Profile object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.profileData.length * 3;
  return bytesCount;
}

void _profileSerialize(
  Profile object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.profileData);
}

Profile _profileDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Profile();
  object.cidNumber = reader.readString(offsets[0]);
  object.profileData = reader.readString(offsets[1]);
  object.rowId = id;
  return object;
}

P _profileDeserializeProp<P>(
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

Id _profileGetId(Profile object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _profileGetLinks(Profile object) {
  return [];
}

void _profileAttach(IsarCollection<dynamic> col, Id id, Profile object) {
  object.rowId = id;
}

extension ProfileByIndex on IsarCollection<Profile> {
  Future<Profile?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  Profile? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<Profile?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<Profile?> getAllByCidNumberSync(List<String> cidNumberValues) {
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

  Future<Id> putByCidNumber(Profile object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(Profile object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<Profile> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<Profile> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension ProfileQueryWhereSort on QueryBuilder<Profile, Profile, QWhere> {
  QueryBuilder<Profile, Profile, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProfileQueryWhere on QueryBuilder<Profile, Profile, QWhereClause> {
  QueryBuilder<Profile, Profile, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Profile, Profile, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Profile, Profile, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterWhereClause> cidNumberNotEqualTo(
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

extension ProfileQueryFilter
    on QueryBuilder<Profile, Profile, QFilterCondition> {
  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'profile_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'profile_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'profile_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'profile_data', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition>
  profileDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'profile_data', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Profile, Profile, QAfterFilterCondition> rowIdBetween(
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

extension ProfileQueryObject
    on QueryBuilder<Profile, Profile, QFilterCondition> {}

extension ProfileQueryLinks
    on QueryBuilder<Profile, Profile, QFilterCondition> {}

extension ProfileQuerySortBy on QueryBuilder<Profile, Profile, QSortBy> {
  QueryBuilder<Profile, Profile, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> sortByProfileData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_data', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> sortByProfileDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_data', Sort.desc);
    });
  }
}

extension ProfileQuerySortThenBy
    on QueryBuilder<Profile, Profile, QSortThenBy> {
  QueryBuilder<Profile, Profile, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByProfileData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_data', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByProfileDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_data', Sort.desc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ProfileQueryWhereDistinct
    on QueryBuilder<Profile, Profile, QDistinct> {
  QueryBuilder<Profile, Profile, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Profile, Profile, QDistinct> distinctByProfileData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profile_data', caseSensitive: caseSensitive);
    });
  }
}

extension ProfileQueryProperty
    on QueryBuilder<Profile, Profile, QQueryProperty> {
  QueryBuilder<Profile, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Profile, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Profile, String, QQueryOperations> profileDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profile_data');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProfileMediaCollection on Isar {
  IsarCollection<ProfileMedia> get profileMedias => this.collection();
}

const ProfileMediaSchema = CollectionSchema(
  name: r'media',
  id: -460020576612860404,
  properties: {
    r'body_hash': PropertySchema(
      id: 0,
      name: r'body_hash',
      type: IsarType.string,
    ),
    r'cid_number': PropertySchema(
      id: 1,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'media_bytes': PropertySchema(
      id: 2,
      name: r'media_bytes',
      type: IsarType.byteList,
    ),
    r'media_role': PropertySchema(
      id: 3,
      name: r'media_role',
      type: IsarType.string,
    ),
    r'object_key': PropertySchema(
      id: 4,
      name: r'object_key',
      type: IsarType.string,
    ),
    r'profile_at': PropertySchema(
      id: 5,
      name: r'profile_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _profileMediaEstimateSize,
  serialize: _profileMediaSerialize,
  deserialize: _profileMediaDeserialize,
  deserializeProp: _profileMediaDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_media_role_profile_at': IndexSchema(
      id: 3106397547773676457,
      name: r'cid_number_media_role_profile_at',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'media_role',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'profile_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _profileMediaGetId,
  getLinks: _profileMediaGetLinks,
  attach: _profileMediaAttach,
  version: '3.3.2',
);

int _profileMediaEstimateSize(
  ProfileMedia object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyHash.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.mediaBytes.length;
  bytesCount += 3 + object.mediaRole.length * 3;
  bytesCount += 3 + object.objectKey.length * 3;
  return bytesCount;
}

void _profileMediaSerialize(
  ProfileMedia object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyHash);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeByteList(offsets[2], object.mediaBytes);
  writer.writeString(offsets[3], object.mediaRole);
  writer.writeString(offsets[4], object.objectKey);
  writer.writeLong(offsets[5], object.profileAt);
}

ProfileMedia _profileMediaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ProfileMedia();
  object.bodyHash = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.mediaBytes = reader.readByteList(offsets[2]) ?? [];
  object.mediaRole = reader.readString(offsets[3]);
  object.objectKey = reader.readString(offsets[4]);
  object.profileAt = reader.readLong(offsets[5]);
  object.rowId = id;
  return object;
}

P _profileMediaDeserializeProp<P>(
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
      return (reader.readByteList(offset) ?? []) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _profileMediaGetId(ProfileMedia object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _profileMediaGetLinks(ProfileMedia object) {
  return [];
}

void _profileMediaAttach(
  IsarCollection<dynamic> col,
  Id id,
  ProfileMedia object,
) {
  object.rowId = id;
}

extension ProfileMediaByIndex on IsarCollection<ProfileMedia> {
  Future<ProfileMedia?> getByCidNumberMediaRoleProfileAt(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return getByIndex(r'cid_number_media_role_profile_at', [
      cidNumber,
      mediaRole,
      profileAt,
    ]);
  }

  ProfileMedia? getByCidNumberMediaRoleProfileAtSync(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return getByIndexSync(r'cid_number_media_role_profile_at', [
      cidNumber,
      mediaRole,
      profileAt,
    ]);
  }

  Future<bool> deleteByCidNumberMediaRoleProfileAt(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return deleteByIndex(r'cid_number_media_role_profile_at', [
      cidNumber,
      mediaRole,
      profileAt,
    ]);
  }

  bool deleteByCidNumberMediaRoleProfileAtSync(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return deleteByIndexSync(r'cid_number_media_role_profile_at', [
      cidNumber,
      mediaRole,
      profileAt,
    ]);
  }

  Future<List<ProfileMedia?>> getAllByCidNumberMediaRoleProfileAt(
    List<String> cidNumberValues,
    List<String> mediaRoleValues,
    List<int> profileAtValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      mediaRoleValues.length == len && profileAtValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], mediaRoleValues[i], profileAtValues[i]]);
    }

    return getAllByIndex(r'cid_number_media_role_profile_at', values);
  }

  List<ProfileMedia?> getAllByCidNumberMediaRoleProfileAtSync(
    List<String> cidNumberValues,
    List<String> mediaRoleValues,
    List<int> profileAtValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      mediaRoleValues.length == len && profileAtValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], mediaRoleValues[i], profileAtValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_media_role_profile_at', values);
  }

  Future<int> deleteAllByCidNumberMediaRoleProfileAt(
    List<String> cidNumberValues,
    List<String> mediaRoleValues,
    List<int> profileAtValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      mediaRoleValues.length == len && profileAtValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], mediaRoleValues[i], profileAtValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_media_role_profile_at', values);
  }

  int deleteAllByCidNumberMediaRoleProfileAtSync(
    List<String> cidNumberValues,
    List<String> mediaRoleValues,
    List<int> profileAtValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      mediaRoleValues.length == len && profileAtValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], mediaRoleValues[i], profileAtValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_media_role_profile_at', values);
  }

  Future<Id> putByCidNumberMediaRoleProfileAt(ProfileMedia object) {
    return putByIndex(r'cid_number_media_role_profile_at', object);
  }

  Id putByCidNumberMediaRoleProfileAtSync(
    ProfileMedia object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'cid_number_media_role_profile_at',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByCidNumberMediaRoleProfileAt(
    List<ProfileMedia> objects,
  ) {
    return putAllByIndex(r'cid_number_media_role_profile_at', objects);
  }

  List<Id> putAllByCidNumberMediaRoleProfileAtSync(
    List<ProfileMedia> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_media_role_profile_at',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ProfileMediaQueryWhereSort
    on QueryBuilder<ProfileMedia, ProfileMedia, QWhere> {
  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProfileMediaQueryWhere
    on QueryBuilder<ProfileMedia, ProfileMedia, QWhereClause> {
  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause> rowIdEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause> rowIdNotEqualTo(
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberEqualToAnyMediaRoleProfileAt(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_media_role_profile_at',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberNotEqualToAnyMediaRoleProfileAt(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleEqualToAnyProfileAt(String cidNumber, String mediaRole) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_media_role_profile_at',
          value: [cidNumber, mediaRole],
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberEqualToMediaRoleNotEqualToAnyProfileAt(
    String cidNumber,
    String mediaRole,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber],
                upper: [cidNumber, mediaRole],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber],
                upper: [cidNumber, mediaRole],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleProfileAtEqualTo(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_media_role_profile_at',
          value: [cidNumber, mediaRole, profileAt],
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleEqualToProfileAtNotEqualTo(
    String cidNumber,
    String mediaRole,
    int profileAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole],
                upper: [cidNumber, mediaRole, profileAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole, profileAt],
                includeLower: false,
                upper: [cidNumber, mediaRole],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole, profileAt],
                includeLower: false,
                upper: [cidNumber, mediaRole],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_media_role_profile_at',
                lower: [cidNumber, mediaRole],
                upper: [cidNumber, mediaRole, profileAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleEqualToProfileAtGreaterThan(
    String cidNumber,
    String mediaRole,
    int profileAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_media_role_profile_at',
          lower: [cidNumber, mediaRole, profileAt],
          includeLower: include,
          upper: [cidNumber, mediaRole],
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleEqualToProfileAtLessThan(
    String cidNumber,
    String mediaRole,
    int profileAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_media_role_profile_at',
          lower: [cidNumber, mediaRole],
          upper: [cidNumber, mediaRole, profileAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterWhereClause>
  cidNumberMediaRoleEqualToProfileAtBetween(
    String cidNumber,
    String mediaRole,
    int lowerProfileAt,
    int upperProfileAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_media_role_profile_at',
          lower: [cidNumber, mediaRole, lowerProfileAt],
          includeLower: includeLower,
          upper: [cidNumber, mediaRole, upperProfileAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProfileMediaQueryFilter
    on QueryBuilder<ProfileMedia, ProfileMedia, QFilterCondition> {
  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  bodyHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_bytes', value: value),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'media_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'media_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'media_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'media_bytes', length, true, length, true);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'media_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'media_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'media_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'media_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'media_role',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'media_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'media_role',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_role', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  mediaRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'media_role', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'object_key',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'object_key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'object_key',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'object_key', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  objectKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'object_key', value: ''),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  profileAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'profile_at', value: value),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  profileAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'profile_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  profileAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'profile_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  profileAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'profile_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition> rowIdBetween(
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

extension ProfileMediaQueryObject
    on QueryBuilder<ProfileMedia, ProfileMedia, QFilterCondition> {}

extension ProfileMediaQueryLinks
    on QueryBuilder<ProfileMedia, ProfileMedia, QFilterCondition> {}

extension ProfileMediaQuerySortBy
    on QueryBuilder<ProfileMedia, ProfileMedia, QSortBy> {
  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByMediaRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByMediaRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByObjectKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'object_key', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByObjectKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'object_key', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByProfileAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_at', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> sortByProfileAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_at', Sort.desc);
    });
  }
}

extension ProfileMediaQuerySortThenBy
    on QueryBuilder<ProfileMedia, ProfileMedia, QSortThenBy> {
  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByMediaRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByMediaRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByObjectKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'object_key', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByObjectKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'object_key', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByProfileAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_at', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByProfileAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profile_at', Sort.desc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ProfileMediaQueryWhereDistinct
    on QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> {
  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByBodyHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByMediaBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_bytes');
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByMediaRole({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_role', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByObjectKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'object_key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QDistinct> distinctByProfileAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profile_at');
    });
  }
}

extension ProfileMediaQueryProperty
    on QueryBuilder<ProfileMedia, ProfileMedia, QQueryProperty> {
  QueryBuilder<ProfileMedia, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<ProfileMedia, String, QQueryOperations> bodyHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_hash');
    });
  }

  QueryBuilder<ProfileMedia, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<ProfileMedia, List<int>, QQueryOperations> mediaBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_bytes');
    });
  }

  QueryBuilder<ProfileMedia, String, QQueryOperations> mediaRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_role');
    });
  }

  QueryBuilder<ProfileMedia, String, QQueryOperations> objectKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'object_key');
    });
  }

  QueryBuilder<ProfileMedia, int, QQueryOperations> profileAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profile_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIdentityCollection on Isar {
  IsarCollection<Identity> get identitys => this.collection();
}

const IdentitySchema = CollectionSchema(
  name: r'identity',
  id: -4484375294813923678,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'cid_number': PropertySchema(
      id: 1,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'identity_data': PropertySchema(
      id: 2,
      name: r'identity_data',
      type: IsarType.string,
    ),
    r'updated_at': PropertySchema(
      id: 3,
      name: r'updated_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _identityEstimateSize,
  serialize: _identitySerialize,
  deserialize: _identityDeserialize,
  deserializeProp: _identityDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number': IndexSchema(
      id: 5073804840546792610,
      name: r'cid_number',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
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
  },
  links: {},
  embeddedSchemas: {},

  getId: _identityGetId,
  getLinks: _identityGetLinks,
  attach: _identityAttach,
  version: '3.3.2',
);

int _identityEstimateSize(
  Identity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.accountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.identityData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _identitySerialize(
  Identity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeString(offsets[2], object.identityData);
  writer.writeLong(offsets[3], object.updatedAt);
}

Identity _identityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Identity();
  object.accountId = reader.readStringOrNull(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.identityData = reader.readStringOrNull(offsets[2]);
  object.rowId = id;
  object.updatedAt = reader.readLong(offsets[3]);
  return object;
}

P _identityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _identityGetId(Identity object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _identityGetLinks(Identity object) {
  return [];
}

void _identityAttach(IsarCollection<dynamic> col, Id id, Identity object) {
  object.rowId = id;
}

extension IdentityQueryWhereSort on QueryBuilder<Identity, Identity, QWhere> {
  QueryBuilder<Identity, Identity, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IdentityQueryWhere on QueryBuilder<Identity, Identity, QWhereClause> {
  QueryBuilder<Identity, Identity, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> rowIdNotEqualTo(
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

  QueryBuilder<Identity, Identity, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Identity, Identity, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> cidNumberNotEqualTo(
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

  QueryBuilder<Identity, Identity, QAfterWhereClause> accountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [null]),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> accountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'account_id',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> accountIdEqualTo(
    String? accountId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'account_id', value: [accountId]),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterWhereClause> accountIdNotEqualTo(
    String? accountId,
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

extension IdentityQueryFilter
    on QueryBuilder<Identity, Identity, QFilterCondition> {
  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'account_id'),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'account_id'),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdEqualTo(
    String? value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdGreaterThan(
    String? value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdLessThan(
    String? value, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdStartsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdEndsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdContains(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdMatches(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'identity_data'),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'identity_data'),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'identity_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'identity_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> identityDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'identity_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'identity_data', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'identity_data', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Identity, Identity, QAfterFilterCondition> updatedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updated_at', value: value),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> updatedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> updatedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> updatedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updated_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IdentityQueryObject
    on QueryBuilder<Identity, Identity, QFilterCondition> {}

extension IdentityQueryLinks
    on QueryBuilder<Identity, Identity, QFilterCondition> {}

extension IdentityQuerySortBy on QueryBuilder<Identity, Identity, QSortBy> {
  QueryBuilder<Identity, Identity, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByIdentityData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identity_data', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByIdentityDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identity_data', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension IdentityQuerySortThenBy
    on QueryBuilder<Identity, Identity, QSortThenBy> {
  QueryBuilder<Identity, Identity, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIdentityData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identity_data', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIdentityDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identity_data', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension IdentityQueryWhereDistinct
    on QueryBuilder<Identity, Identity, QDistinct> {
  QueryBuilder<Identity, Identity, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByIdentityData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'identity_data',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Identity, Identity, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated_at');
    });
  }
}

extension IdentityQueryProperty
    on QueryBuilder<Identity, Identity, QQueryProperty> {
  QueryBuilder<Identity, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Identity, String?, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Identity, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Identity, String?, QQueryOperations> identityDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identity_data');
    });
  }

  QueryBuilder<Identity, int, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetContactCollection on Isar {
  IsarCollection<Contact> get contacts => this.collection();
}

const ContactSchema = CollectionSchema(
  name: r'contact',
  id: 213978983763356937,
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

  estimateSize: _contactEstimateSize,
  serialize: _contactSerialize,
  deserialize: _contactDeserialize,
  deserializeProp: _contactDeserializeProp,
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

  getId: _contactGetId,
  getLinks: _contactGetLinks,
  attach: _contactAttach,
  version: '3.3.2',
);

int _contactEstimateSize(
  Contact object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.stateKind.length * 3;
  return bytesCount;
}

void _contactSerialize(
  Contact object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyData);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeString(offsets[2], object.stateKind);
}

Contact _contactDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Contact();
  object.bodyData = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.rowId = id;
  object.stateKind = reader.readString(offsets[2]);
  return object;
}

P _contactDeserializeProp<P>(
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

Id _contactGetId(Contact object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _contactGetLinks(Contact object) {
  return [];
}

void _contactAttach(IsarCollection<dynamic> col, Id id, Contact object) {
  object.rowId = id;
}

extension ContactByIndex on IsarCollection<Contact> {
  Future<Contact?> getByCidNumberStateKind(String cidNumber, String stateKind) {
    return getByIndex(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Contact? getByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return getByIndexSync(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Future<bool> deleteByCidNumberStateKind(String cidNumber, String stateKind) {
    return deleteByIndex(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  bool deleteByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return deleteByIndexSync(r'cid_number_state_kind', [cidNumber, stateKind]);
  }

  Future<List<Contact?>> getAllByCidNumberStateKind(
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

  List<Contact?> getAllByCidNumberStateKindSync(
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

  Future<Id> putByCidNumberStateKind(Contact object) {
    return putByIndex(r'cid_number_state_kind', object);
  }

  Id putByCidNumberStateKindSync(Contact object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'cid_number_state_kind',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByCidNumberStateKind(List<Contact> objects) {
    return putAllByIndex(r'cid_number_state_kind', objects);
  }

  List<Id> putAllByCidNumberStateKindSync(
    List<Contact> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_state_kind',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ContactQueryWhereSort on QueryBuilder<Contact, Contact, QWhere> {
  QueryBuilder<Contact, Contact, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ContactQueryWhere on QueryBuilder<Contact, Contact, QWhereClause> {
  QueryBuilder<Contact, Contact, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Contact, Contact, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
  cidNumberEqualToAnyStateKind(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_state_kind',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

  QueryBuilder<Contact, Contact, QAfterWhereClause> cidNumberStateKindEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterWhereClause>
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

extension ContactQueryFilter
    on QueryBuilder<Contact, Contact, QFilterCondition> {
  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataStartsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataEndsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataContains(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataMatches(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_data', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindEqualTo(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindGreaterThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindLessThan(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindBetween(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindStartsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindEndsWith(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindContains(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindMatches(
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state_kind', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state_kind', value: ''),
      );
    });
  }
}

extension ContactQueryObject
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQueryLinks
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQuerySortBy on QueryBuilder<Contact, Contact, QSortBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.desc);
    });
  }
}

extension ContactQuerySortThenBy
    on QueryBuilder<Contact, Contact, QSortThenBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_data', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_kind', Sort.desc);
    });
  }
}

extension ContactQueryWhereDistinct
    on QueryBuilder<Contact, Contact, QDistinct> {
  QueryBuilder<Contact, Contact, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByStateKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state_kind', caseSensitive: caseSensitive);
    });
  }
}

extension ContactQueryProperty
    on QueryBuilder<Contact, Contact, QQueryProperty> {
  QueryBuilder<Contact, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_data');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> stateKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state_kind');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoticeCollection on Isar {
  IsarCollection<Notice> get notices => this.collection();
}

const NoticeSchema = CollectionSchema(
  name: r'notice',
  id: 8554081893797905452,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'pending_data': PropertySchema(
      id: 1,
      name: r'pending_data',
      type: IsarType.string,
    ),
    r'state_data': PropertySchema(
      id: 2,
      name: r'state_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _noticeEstimateSize,
  serialize: _noticeSerialize,
  deserialize: _noticeDeserialize,
  deserializeProp: _noticeDeserializeProp,
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

  getId: _noticeGetId,
  getLinks: _noticeGetLinks,
  attach: _noticeAttach,
  version: '3.3.2',
);

int _noticeEstimateSize(
  Notice object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.pendingData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.stateData.length * 3;
  return bytesCount;
}

void _noticeSerialize(
  Notice object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.pendingData);
  writer.writeString(offsets[2], object.stateData);
}

Notice _noticeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Notice();
  object.cidNumber = reader.readString(offsets[0]);
  object.pendingData = reader.readStringOrNull(offsets[1]);
  object.rowId = id;
  object.stateData = reader.readString(offsets[2]);
  return object;
}

P _noticeDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _noticeGetId(Notice object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _noticeGetLinks(Notice object) {
  return [];
}

void _noticeAttach(IsarCollection<dynamic> col, Id id, Notice object) {
  object.rowId = id;
}

extension NoticeByIndex on IsarCollection<Notice> {
  Future<Notice?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  Notice? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<Notice?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<Notice?> getAllByCidNumberSync(List<String> cidNumberValues) {
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

  Future<Id> putByCidNumber(Notice object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(Notice object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<Notice> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<Notice> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension NoticeQueryWhereSort on QueryBuilder<Notice, Notice, QWhere> {
  QueryBuilder<Notice, Notice, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NoticeQueryWhere on QueryBuilder<Notice, Notice, QWhereClause> {
  QueryBuilder<Notice, Notice, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Notice, Notice, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Notice, Notice, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterWhereClause> cidNumberNotEqualTo(
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

extension NoticeQueryFilter on QueryBuilder<Notice, Notice, QFilterCondition> {
  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pending_data'),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pending_data'),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pending_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pending_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pending_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pending_data', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pending_data', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'state_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'state_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state_data', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state_data', value: ''),
      );
    });
  }
}

extension NoticeQueryObject on QueryBuilder<Notice, Notice, QFilterCondition> {}

extension NoticeQueryLinks on QueryBuilder<Notice, Notice, QFilterCondition> {}

extension NoticeQuerySortBy on QueryBuilder<Notice, Notice, QSortBy> {
  QueryBuilder<Notice, Notice, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByStateData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByStateDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_data', Sort.desc);
    });
  }
}

extension NoticeQuerySortThenBy on QueryBuilder<Notice, Notice, QSortThenBy> {
  QueryBuilder<Notice, Notice, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByStateData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByStateDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state_data', Sort.desc);
    });
  }
}

extension NoticeQueryWhereDistinct on QueryBuilder<Notice, Notice, QDistinct> {
  QueryBuilder<Notice, Notice, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Notice, Notice, QDistinct> distinctByPendingData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pending_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Notice, Notice, QDistinct> distinctByStateData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state_data', caseSensitive: caseSensitive);
    });
  }
}

extension NoticeQueryProperty on QueryBuilder<Notice, Notice, QQueryProperty> {
  QueryBuilder<Notice, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Notice, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Notice, String?, QQueryOperations> pendingDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pending_data');
    });
  }

  QueryBuilder<Notice, String, QQueryOperations> stateDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state_data');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSettingCollection on Isar {
  IsarCollection<Setting> get settings => this.collection();
}

const SettingSchema = CollectionSchema(
  name: r'setting',
  id: -823090073715780110,
  properties: {
    r'bank_order': PropertySchema(
      id: 0,
      name: r'bank_order',
      type: IsarType.stringList,
    ),
    r'chat_home': PropertySchema(
      id: 1,
      name: r'chat_home',
      type: IsarType.bool,
    ),
    r'council_order': PropertySchema(
      id: 2,
      name: r'council_order',
      type: IsarType.stringList,
    ),
    r'guide_seen': PropertySchema(
      id: 3,
      name: r'guide_seen',
      type: IsarType.bool,
    ),
  },

  estimateSize: _settingEstimateSize,
  serialize: _settingSerialize,
  deserialize: _settingDeserialize,
  deserializeProp: _settingDeserializeProp,
  idName: r'row_id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _settingGetId,
  getLinks: _settingGetLinks,
  attach: _settingAttach,
  version: '3.3.2',
);

int _settingEstimateSize(
  Setting object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bankOrder.length * 3;
  {
    for (var i = 0; i < object.bankOrder.length; i++) {
      final value = object.bankOrder[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.councilOrder.length * 3;
  {
    for (var i = 0; i < object.councilOrder.length; i++) {
      final value = object.councilOrder[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _settingSerialize(
  Setting object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.bankOrder);
  writer.writeBool(offsets[1], object.chatHome);
  writer.writeStringList(offsets[2], object.councilOrder);
  writer.writeBool(offsets[3], object.guideSeen);
}

Setting _settingDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Setting();
  object.bankOrder = reader.readStringList(offsets[0]) ?? [];
  object.chatHome = reader.readBool(offsets[1]);
  object.councilOrder = reader.readStringList(offsets[2]) ?? [];
  object.guideSeen = reader.readBool(offsets[3]);
  object.rowId = id;
  return object;
}

P _settingDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readStringList(offset) ?? []) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _settingGetId(Setting object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _settingGetLinks(Setting object) {
  return [];
}

void _settingAttach(IsarCollection<dynamic> col, Id id, Setting object) {
  object.rowId = id;
}

extension SettingQueryWhereSort on QueryBuilder<Setting, Setting, QWhere> {
  QueryBuilder<Setting, Setting, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SettingQueryWhere on QueryBuilder<Setting, Setting, QWhereClause> {
  QueryBuilder<Setting, Setting, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Setting, Setting, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> rowIdBetween(
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

extension SettingQueryFilter
    on QueryBuilder<Setting, Setting, QFilterCondition> {
  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bank_order',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'bank_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'bank_order',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bank_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bank_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'bank_order', length, true, length, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'bank_order', 0, true, 0, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'bank_order', 0, false, 999999, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'bank_order', 0, true, length, include);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  bankOrderLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'bank_order', length, include, 999999, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> bankOrderLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bank_order',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> chatHomeEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chat_home', value: value),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'council_order',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'council_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'council_order',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'council_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'council_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'council_order', length, true, length, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> councilOrderIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'council_order', 0, true, 0, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'council_order', 0, false, 999999, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'council_order', 0, true, length, include);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'council_order', length, include, 999999, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  councilOrderLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'council_order',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> guideSeenEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'guide_seen', value: value),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Setting, Setting, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Setting, Setting, QAfterFilterCondition> rowIdBetween(
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

extension SettingQueryObject
    on QueryBuilder<Setting, Setting, QFilterCondition> {}

extension SettingQueryLinks
    on QueryBuilder<Setting, Setting, QFilterCondition> {}

extension SettingQuerySortBy on QueryBuilder<Setting, Setting, QSortBy> {
  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatHome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chat_home', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatHomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chat_home', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByGuideSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'guide_seen', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByGuideSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'guide_seen', Sort.desc);
    });
  }
}

extension SettingQuerySortThenBy
    on QueryBuilder<Setting, Setting, QSortThenBy> {
  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatHome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chat_home', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatHomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chat_home', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByGuideSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'guide_seen', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByGuideSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'guide_seen', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension SettingQueryWhereDistinct
    on QueryBuilder<Setting, Setting, QDistinct> {
  QueryBuilder<Setting, Setting, QDistinct> distinctByBankOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bank_order');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByChatHome() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chat_home');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByCouncilOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'council_order');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByGuideSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'guide_seen');
    });
  }
}

extension SettingQueryProperty
    on QueryBuilder<Setting, Setting, QQueryProperty> {
  QueryBuilder<Setting, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Setting, List<String>, QQueryOperations> bankOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bank_order');
    });
  }

  QueryBuilder<Setting, bool, QQueryOperations> chatHomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chat_home');
    });
  }

  QueryBuilder<Setting, List<String>, QQueryOperations> councilOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'council_order');
    });
  }

  QueryBuilder<Setting, bool, QQueryOperations> guideSeenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'guide_seen');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFollowCollection on Isar {
  IsarCollection<Follow> get follows => this.collection();
}

const FollowSchema = CollectionSchema(
  name: r'follow',
  id: -6022719189966030500,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'peer_cid': PropertySchema(
      id: 1,
      name: r'peer_cid',
      type: IsarType.string,
    ),
  },

  estimateSize: _followEstimateSize,
  serialize: _followSerialize,
  deserialize: _followDeserialize,
  deserializeProp: _followDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_peer_cid': IndexSchema(
      id: 5724213696030659010,
      name: r'cid_number_peer_cid',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'peer_cid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _followGetId,
  getLinks: _followGetLinks,
  attach: _followAttach,
  version: '3.3.2',
);

int _followEstimateSize(
  Follow object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.peerCid.length * 3;
  return bytesCount;
}

void _followSerialize(
  Follow object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.peerCid);
}

Follow _followDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Follow();
  object.cidNumber = reader.readString(offsets[0]);
  object.peerCid = reader.readString(offsets[1]);
  object.rowId = id;
  return object;
}

P _followDeserializeProp<P>(
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

Id _followGetId(Follow object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _followGetLinks(Follow object) {
  return [];
}

void _followAttach(IsarCollection<dynamic> col, Id id, Follow object) {
  object.rowId = id;
}

extension FollowByIndex on IsarCollection<Follow> {
  Future<Follow?> getByCidNumberPeerCid(String cidNumber, String peerCid) {
    return getByIndex(r'cid_number_peer_cid', [cidNumber, peerCid]);
  }

  Follow? getByCidNumberPeerCidSync(String cidNumber, String peerCid) {
    return getByIndexSync(r'cid_number_peer_cid', [cidNumber, peerCid]);
  }

  Future<bool> deleteByCidNumberPeerCid(String cidNumber, String peerCid) {
    return deleteByIndex(r'cid_number_peer_cid', [cidNumber, peerCid]);
  }

  bool deleteByCidNumberPeerCidSync(String cidNumber, String peerCid) {
    return deleteByIndexSync(r'cid_number_peer_cid', [cidNumber, peerCid]);
  }

  Future<List<Follow?>> getAllByCidNumberPeerCid(
    List<String> cidNumberValues,
    List<String> peerCidValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      peerCidValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], peerCidValues[i]]);
    }

    return getAllByIndex(r'cid_number_peer_cid', values);
  }

  List<Follow?> getAllByCidNumberPeerCidSync(
    List<String> cidNumberValues,
    List<String> peerCidValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      peerCidValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], peerCidValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_peer_cid', values);
  }

  Future<int> deleteAllByCidNumberPeerCid(
    List<String> cidNumberValues,
    List<String> peerCidValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      peerCidValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], peerCidValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_peer_cid', values);
  }

  int deleteAllByCidNumberPeerCidSync(
    List<String> cidNumberValues,
    List<String> peerCidValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      peerCidValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], peerCidValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_peer_cid', values);
  }

  Future<Id> putByCidNumberPeerCid(Follow object) {
    return putByIndex(r'cid_number_peer_cid', object);
  }

  Id putByCidNumberPeerCidSync(Follow object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_peer_cid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberPeerCid(List<Follow> objects) {
    return putAllByIndex(r'cid_number_peer_cid', objects);
  }

  List<Id> putAllByCidNumberPeerCidSync(
    List<Follow> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_peer_cid',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension FollowQueryWhereSort on QueryBuilder<Follow, Follow, QWhere> {
  QueryBuilder<Follow, Follow, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FollowQueryWhere on QueryBuilder<Follow, Follow, QWhereClause> {
  QueryBuilder<Follow, Follow, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Follow, Follow, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Follow, Follow, QAfterWhereClause> cidNumberEqualToAnyPeerCid(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_peer_cid',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause> cidNumberNotEqualToAnyPeerCid(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause> cidNumberPeerCidEqualTo(
    String cidNumber,
    String peerCid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_peer_cid',
          value: [cidNumber, peerCid],
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterWhereClause>
  cidNumberEqualToPeerCidNotEqualTo(String cidNumber, String peerCid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber],
                upper: [cidNumber, peerCid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber, peerCid],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber, peerCid],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_peer_cid',
                lower: [cidNumber],
                upper: [cidNumber, peerCid],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension FollowQueryFilter on QueryBuilder<Follow, Follow, QFilterCondition> {
  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'peer_cid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'peer_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'peer_cid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'peer_cid', value: ''),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> peerCidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'peer_cid', value: ''),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Follow, Follow, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> rowIdBetween(
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

extension FollowQueryObject on QueryBuilder<Follow, Follow, QFilterCondition> {}

extension FollowQueryLinks on QueryBuilder<Follow, Follow, QFilterCondition> {}

extension FollowQuerySortBy on QueryBuilder<Follow, Follow, QSortBy> {
  QueryBuilder<Follow, Follow, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> sortByPeerCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_cid', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> sortByPeerCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_cid', Sort.desc);
    });
  }
}

extension FollowQuerySortThenBy on QueryBuilder<Follow, Follow, QSortThenBy> {
  QueryBuilder<Follow, Follow, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByPeerCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_cid', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByPeerCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_cid', Sort.desc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension FollowQueryWhereDistinct on QueryBuilder<Follow, Follow, QDistinct> {
  QueryBuilder<Follow, Follow, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Follow, Follow, QDistinct> distinctByPeerCid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peer_cid', caseSensitive: caseSensitive);
    });
  }
}

extension FollowQueryProperty on QueryBuilder<Follow, Follow, QQueryProperty> {
  QueryBuilder<Follow, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Follow, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Follow, String, QQueryOperations> peerCidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peer_cid');
    });
  }
}
