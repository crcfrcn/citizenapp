// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_isar.dart';

// ignore_for_file: experimental_member_use

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReplyCollection on Isar {
  IsarCollection<Reply> get replys => this.collection();
}

const ReplySchema = CollectionSchema(
  name: r'reply',
  id: 8017836045341346032,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'page_data': PropertySchema(
      id: 1,
      name: r'page_data',
      type: IsarType.string,
    ),
    r'pending_data': PropertySchema(
      id: 2,
      name: r'pending_data',
      type: IsarType.string,
    ),
    r'post_id': PropertySchema(id: 3, name: r'post_id', type: IsarType.string),
  },

  estimateSize: _replyEstimateSize,
  serialize: _replySerialize,
  deserialize: _replyDeserialize,
  deserializeProp: _replyDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_post_id': IndexSchema(
      id: -8377155717331402316,
      name: r'cid_number_post_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'post_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _replyGetId,
  getLinks: _replyGetLinks,
  attach: _replyAttach,
  version: '3.3.2',
);

int _replyEstimateSize(
  Reply object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.pageData.length * 3;
  {
    final value = object.pendingData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.postId.length * 3;
  return bytesCount;
}

void _replySerialize(
  Reply object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.pageData);
  writer.writeString(offsets[2], object.pendingData);
  writer.writeString(offsets[3], object.postId);
}

Reply _replyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Reply();
  object.cidNumber = reader.readString(offsets[0]);
  object.pageData = reader.readString(offsets[1]);
  object.pendingData = reader.readStringOrNull(offsets[2]);
  object.postId = reader.readString(offsets[3]);
  object.rowId = id;
  return object;
}

P _replyDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _replyGetId(Reply object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _replyGetLinks(Reply object) {
  return [];
}

void _replyAttach(IsarCollection<dynamic> col, Id id, Reply object) {
  object.rowId = id;
}

extension ReplyByIndex on IsarCollection<Reply> {
  Future<Reply?> getByCidNumberPostId(String cidNumber, String postId) {
    return getByIndex(r'cid_number_post_id', [cidNumber, postId]);
  }

  Reply? getByCidNumberPostIdSync(String cidNumber, String postId) {
    return getByIndexSync(r'cid_number_post_id', [cidNumber, postId]);
  }

  Future<bool> deleteByCidNumberPostId(String cidNumber, String postId) {
    return deleteByIndex(r'cid_number_post_id', [cidNumber, postId]);
  }

  bool deleteByCidNumberPostIdSync(String cidNumber, String postId) {
    return deleteByIndexSync(r'cid_number_post_id', [cidNumber, postId]);
  }

  Future<List<Reply?>> getAllByCidNumberPostId(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return getAllByIndex(r'cid_number_post_id', values);
  }

  List<Reply?> getAllByCidNumberPostIdSync(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_post_id', values);
  }

  Future<int> deleteAllByCidNumberPostId(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_post_id', values);
  }

  int deleteAllByCidNumberPostIdSync(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_post_id', values);
  }

  Future<Id> putByCidNumberPostId(Reply object) {
    return putByIndex(r'cid_number_post_id', object);
  }

  Id putByCidNumberPostIdSync(Reply object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_post_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberPostId(List<Reply> objects) {
    return putAllByIndex(r'cid_number_post_id', objects);
  }

  List<Id> putAllByCidNumberPostIdSync(
    List<Reply> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_post_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ReplyQueryWhereSort on QueryBuilder<Reply, Reply, QWhere> {
  QueryBuilder<Reply, Reply, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReplyQueryWhere on QueryBuilder<Reply, Reply, QWhereClause> {
  QueryBuilder<Reply, Reply, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Reply, Reply, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Reply, Reply, QAfterWhereClause> cidNumberEqualToAnyPostId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_post_id',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause> cidNumberNotEqualToAnyPostId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause> cidNumberPostIdEqualTo(
    String cidNumber,
    String postId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_post_id',
          value: [cidNumber, postId],
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterWhereClause>
  cidNumberEqualToPostIdNotEqualTo(String cidNumber, String postId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                upper: [cidNumber, postId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber, postId],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber, postId],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                upper: [cidNumber, postId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ReplyQueryFilter on QueryBuilder<Reply, Reply, QFilterCondition> {
  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'page_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'page_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'page_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'page_data', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pageDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'page_data', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pending_data'),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pending_data'),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataEqualTo(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataGreaterThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataLessThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataBetween(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataStartsWith(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataEndsWith(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataContains(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataMatches(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pending_data', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> pendingDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pending_data', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Reply, Reply, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Reply, Reply, QAfterFilterCondition> rowIdBetween(
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

extension ReplyQueryObject on QueryBuilder<Reply, Reply, QFilterCondition> {}

extension ReplyQueryLinks on QueryBuilder<Reply, Reply, QFilterCondition> {}

extension ReplyQuerySortBy on QueryBuilder<Reply, Reply, QSortBy> {
  QueryBuilder<Reply, Reply, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPageData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'page_data', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPageDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'page_data', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }
}

extension ReplyQuerySortThenBy on QueryBuilder<Reply, Reply, QSortThenBy> {
  QueryBuilder<Reply, Reply, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPageData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'page_data', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPageDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'page_data', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending_data', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Reply, Reply, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ReplyQueryWhereDistinct on QueryBuilder<Reply, Reply, QDistinct> {
  QueryBuilder<Reply, Reply, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Reply, Reply, QDistinct> distinctByPageData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'page_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Reply, Reply, QDistinct> distinctByPendingData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pending_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Reply, Reply, QDistinct> distinctByPostId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_id', caseSensitive: caseSensitive);
    });
  }
}

extension ReplyQueryProperty on QueryBuilder<Reply, Reply, QQueryProperty> {
  QueryBuilder<Reply, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Reply, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Reply, String, QQueryOperations> pageDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'page_data');
    });
  }

  QueryBuilder<Reply, String?, QQueryOperations> pendingDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pending_data');
    });
  }

  QueryBuilder<Reply, String, QQueryOperations> postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEraseCollection on Isar {
  IsarCollection<Erase> get erases => this.collection();
}

const EraseSchema = CollectionSchema(
  name: r'erase',
  id: 2609326287918503661,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'job_state': PropertySchema(
      id: 1,
      name: r'job_state',
      type: IsarType.string,
    ),
    r'post_id': PropertySchema(id: 2, name: r'post_id', type: IsarType.string),
  },

  estimateSize: _eraseEstimateSize,
  serialize: _eraseSerialize,
  deserialize: _eraseDeserialize,
  deserializeProp: _eraseDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_post_id': IndexSchema(
      id: -8377155717331402316,
      name: r'cid_number_post_id',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'post_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _eraseGetId,
  getLinks: _eraseGetLinks,
  attach: _eraseAttach,
  version: '3.3.2',
);

int _eraseEstimateSize(
  Erase object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.jobState.length * 3;
  bytesCount += 3 + object.postId.length * 3;
  return bytesCount;
}

void _eraseSerialize(
  Erase object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.jobState);
  writer.writeString(offsets[2], object.postId);
}

Erase _eraseDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Erase();
  object.cidNumber = reader.readString(offsets[0]);
  object.jobState = reader.readString(offsets[1]);
  object.postId = reader.readString(offsets[2]);
  object.rowId = id;
  return object;
}

P _eraseDeserializeProp<P>(
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

Id _eraseGetId(Erase object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _eraseGetLinks(Erase object) {
  return [];
}

void _eraseAttach(IsarCollection<dynamic> col, Id id, Erase object) {
  object.rowId = id;
}

extension EraseByIndex on IsarCollection<Erase> {
  Future<Erase?> getByCidNumberPostId(String cidNumber, String postId) {
    return getByIndex(r'cid_number_post_id', [cidNumber, postId]);
  }

  Erase? getByCidNumberPostIdSync(String cidNumber, String postId) {
    return getByIndexSync(r'cid_number_post_id', [cidNumber, postId]);
  }

  Future<bool> deleteByCidNumberPostId(String cidNumber, String postId) {
    return deleteByIndex(r'cid_number_post_id', [cidNumber, postId]);
  }

  bool deleteByCidNumberPostIdSync(String cidNumber, String postId) {
    return deleteByIndexSync(r'cid_number_post_id', [cidNumber, postId]);
  }

  Future<List<Erase?>> getAllByCidNumberPostId(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return getAllByIndex(r'cid_number_post_id', values);
  }

  List<Erase?> getAllByCidNumberPostIdSync(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_post_id', values);
  }

  Future<int> deleteAllByCidNumberPostId(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_post_id', values);
  }

  int deleteAllByCidNumberPostIdSync(
    List<String> cidNumberValues,
    List<String> postIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      postIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], postIdValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_post_id', values);
  }

  Future<Id> putByCidNumberPostId(Erase object) {
    return putByIndex(r'cid_number_post_id', object);
  }

  Id putByCidNumberPostIdSync(Erase object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_post_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberPostId(List<Erase> objects) {
    return putAllByIndex(r'cid_number_post_id', objects);
  }

  List<Id> putAllByCidNumberPostIdSync(
    List<Erase> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_post_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension EraseQueryWhereSort on QueryBuilder<Erase, Erase, QWhere> {
  QueryBuilder<Erase, Erase, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EraseQueryWhere on QueryBuilder<Erase, Erase, QWhereClause> {
  QueryBuilder<Erase, Erase, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Erase, Erase, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Erase, Erase, QAfterWhereClause> cidNumberEqualToAnyPostId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_post_id',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause> cidNumberNotEqualToAnyPostId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause> cidNumberPostIdEqualTo(
    String cidNumber,
    String postId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_post_id',
          value: [cidNumber, postId],
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterWhereClause>
  cidNumberEqualToPostIdNotEqualTo(String cidNumber, String postId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                upper: [cidNumber, postId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber, postId],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber, postId],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_post_id',
                lower: [cidNumber],
                upper: [cidNumber, postId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension EraseQueryFilter on QueryBuilder<Erase, Erase, QFilterCondition> {
  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateEqualTo(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateGreaterThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateLessThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateBetween(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateStartsWith(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateEndsWith(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateContains(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateMatches(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> jobStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Erase, Erase, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Erase, Erase, QAfterFilterCondition> rowIdBetween(
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

extension EraseQueryObject on QueryBuilder<Erase, Erase, QFilterCondition> {}

extension EraseQueryLinks on QueryBuilder<Erase, Erase, QFilterCondition> {}

extension EraseQuerySortBy on QueryBuilder<Erase, Erase, QSortBy> {
  QueryBuilder<Erase, Erase, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> sortByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> sortByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }
}

extension EraseQuerySortThenBy on QueryBuilder<Erase, Erase, QSortThenBy> {
  QueryBuilder<Erase, Erase, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Erase, Erase, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension EraseQueryWhereDistinct on QueryBuilder<Erase, Erase, QDistinct> {
  QueryBuilder<Erase, Erase, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Erase, Erase, QDistinct> distinctByJobState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'job_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Erase, Erase, QDistinct> distinctByPostId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_id', caseSensitive: caseSensitive);
    });
  }
}

extension EraseQueryProperty on QueryBuilder<Erase, Erase, QQueryProperty> {
  QueryBuilder<Erase, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Erase, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Erase, String, QQueryOperations> jobStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'job_state');
    });
  }

  QueryBuilder<Erase, String, QQueryOperations> postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPostCollection on Isar {
  IsarCollection<Post> get posts => this.collection();
}

const PostSchema = CollectionSchema(
  name: r'post',
  id: 8455340087031252076,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'chain_block': PropertySchema(
      id: 1,
      name: r'chain_block',
      type: IsarType.long,
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
    r'manifest_bytes': PropertySchema(
      id: 4,
      name: r'manifest_bytes',
      type: IsarType.byteList,
    ),
    r'post_category': PropertySchema(
      id: 5,
      name: r'post_category',
      type: IsarType.string,
    ),
    r'post_id': PropertySchema(id: 6, name: r'post_id', type: IsarType.string),
    r'post_state': PropertySchema(
      id: 7,
      name: r'post_state',
      type: IsarType.string,
    ),
    r'post_type': PropertySchema(
      id: 8,
      name: r'post_type',
      type: IsarType.string,
    ),
    r'published_at': PropertySchema(
      id: 9,
      name: r'published_at',
      type: IsarType.long,
    ),
    r'receipt_id': PropertySchema(
      id: 10,
      name: r'receipt_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _postEstimateSize,
  serialize: _postSerialize,
  deserialize: _postDeserialize,
  deserializeProp: _postDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'post_id': IndexSchema(
      id: 7337727291460660483,
      name: r'post_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'post_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
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
    r'published_at': IndexSchema(
      id: 8582188653944161576,
      name: r'published_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'published_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _postGetId,
  getLinks: _postGetLinks,
  attach: _postAttach,
  version: '3.3.2',
);

int _postEstimateSize(
  Post object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentHash.length * 3;
  bytesCount += 3 + object.manifestBytes.length;
  bytesCount += 3 + object.postCategory.length * 3;
  bytesCount += 3 + object.postId.length * 3;
  bytesCount += 3 + object.postState.length * 3;
  bytesCount += 3 + object.postType.length * 3;
  bytesCount += 3 + object.receiptId.length * 3;
  return bytesCount;
}

void _postSerialize(
  Post object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.chainBlock);
  writer.writeString(offsets[2], object.cidNumber);
  writer.writeString(offsets[3], object.contentHash);
  writer.writeByteList(offsets[4], object.manifestBytes);
  writer.writeString(offsets[5], object.postCategory);
  writer.writeString(offsets[6], object.postId);
  writer.writeString(offsets[7], object.postState);
  writer.writeString(offsets[8], object.postType);
  writer.writeLong(offsets[9], object.publishedAt);
  writer.writeString(offsets[10], object.receiptId);
}

Post _postDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Post();
  object.accountId = reader.readString(offsets[0]);
  object.chainBlock = reader.readLongOrNull(offsets[1]);
  object.cidNumber = reader.readString(offsets[2]);
  object.contentHash = reader.readString(offsets[3]);
  object.manifestBytes = reader.readByteList(offsets[4]) ?? [];
  object.postCategory = reader.readString(offsets[5]);
  object.postId = reader.readString(offsets[6]);
  object.postState = reader.readString(offsets[7]);
  object.postType = reader.readString(offsets[8]);
  object.publishedAt = reader.readLong(offsets[9]);
  object.receiptId = reader.readString(offsets[10]);
  object.rowId = id;
  return object;
}

P _postDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readByteList(offset) ?? []) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _postGetId(Post object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _postGetLinks(Post object) {
  return [];
}

void _postAttach(IsarCollection<dynamic> col, Id id, Post object) {
  object.rowId = id;
}

extension PostByIndex on IsarCollection<Post> {
  Future<Post?> getByPostId(String postId) {
    return getByIndex(r'post_id', [postId]);
  }

  Post? getByPostIdSync(String postId) {
    return getByIndexSync(r'post_id', [postId]);
  }

  Future<bool> deleteByPostId(String postId) {
    return deleteByIndex(r'post_id', [postId]);
  }

  bool deleteByPostIdSync(String postId) {
    return deleteByIndexSync(r'post_id', [postId]);
  }

  Future<List<Post?>> getAllByPostId(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'post_id', values);
  }

  List<Post?> getAllByPostIdSync(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'post_id', values);
  }

  Future<int> deleteAllByPostId(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'post_id', values);
  }

  int deleteAllByPostIdSync(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'post_id', values);
  }

  Future<Id> putByPostId(Post object) {
    return putByIndex(r'post_id', object);
  }

  Id putByPostIdSync(Post object, {bool saveLinks = true}) {
    return putByIndexSync(r'post_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPostId(List<Post> objects) {
    return putAllByIndex(r'post_id', objects);
  }

  List<Id> putAllByPostIdSync(List<Post> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'post_id', objects, saveLinks: saveLinks);
  }
}

extension PostQueryWhereSort on QueryBuilder<Post, Post, QWhere> {
  QueryBuilder<Post, Post, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Post, Post, QAfterWhere> anyPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'published_at'),
      );
    });
  }
}

extension PostQueryWhere on QueryBuilder<Post, Post, QWhereClause> {
  QueryBuilder<Post, Post, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Post, Post, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Post, Post, QAfterWhereClause> postIdEqualTo(String postId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'post_id', value: [postId]),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> postIdNotEqualTo(String postId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'post_id',
                lower: [],
                upper: [postId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'post_id',
                lower: [postId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'post_id',
                lower: [postId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'post_id',
                lower: [],
                upper: [postId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> cidNumberNotEqualTo(
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

  QueryBuilder<Post, Post, QAfterWhereClause> publishedAtEqualTo(
    int publishedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'published_at',
          value: [publishedAt],
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> publishedAtNotEqualTo(
    int publishedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'published_at',
                lower: [],
                upper: [publishedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'published_at',
                lower: [publishedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'published_at',
                lower: [publishedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'published_at',
                lower: [],
                upper: [publishedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> publishedAtGreaterThan(
    int publishedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'published_at',
          lower: [publishedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> publishedAtLessThan(
    int publishedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'published_at',
          lower: [],
          upper: [publishedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterWhereClause> publishedAtBetween(
    int lowerPublishedAt,
    int upperPublishedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'published_at',
          lower: [lowerPublishedAt],
          includeLower: includeLower,
          upper: [upperPublishedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PostQueryFilter on QueryBuilder<Post, Post, QFilterCondition> {
  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdEqualTo(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdGreaterThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdLessThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdBetween(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdStartsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdEndsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdContains(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdMatches(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'chain_block'),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'chain_block'),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chain_block', value: value),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'chain_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'chain_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> chainBlockBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'chain_block',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashEqualTo(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashGreaterThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashLessThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashBetween(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashStartsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashEndsWith(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashContains(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashMatches(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> contentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesElementEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'manifest_bytes', value: value),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition>
  manifestBytesElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'manifest_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'manifest_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'manifest_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', length, true, length, true);
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition>
  manifestBytesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> manifestBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifest_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_category',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_category', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_category', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_state', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_state', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> postTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> publishedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'published_at', value: value),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> publishedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> publishedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> publishedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'published_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receipt_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'receipt_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receipt_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> receiptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'receipt_id', value: ''),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Post, Post, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Post, Post, QAfterFilterCondition> rowIdBetween(
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

extension PostQueryObject on QueryBuilder<Post, Post, QFilterCondition> {}

extension PostQueryLinks on QueryBuilder<Post, Post, QFilterCondition> {}

extension PostQuerySortBy on QueryBuilder<Post, Post, QSortBy> {
  QueryBuilder<Post, Post, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_state', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_state', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> sortByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.desc);
    });
  }
}

extension PostQuerySortThenBy on QueryBuilder<Post, Post, QSortThenBy> {
  QueryBuilder<Post, Post, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_state', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_state', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.desc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Post, Post, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension PostQueryWhereDistinct on QueryBuilder<Post, Post, QDistinct> {
  QueryBuilder<Post, Post, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chain_block');
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByContentHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByManifestBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'manifest_bytes');
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByPostCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'post_category',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByPostId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByPostState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByPostType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'published_at');
    });
  }

  QueryBuilder<Post, Post, QDistinct> distinctByReceiptId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receipt_id', caseSensitive: caseSensitive);
    });
  }
}

extension PostQueryProperty on QueryBuilder<Post, Post, QQueryProperty> {
  QueryBuilder<Post, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Post, int?, QQueryOperations> chainBlockProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chain_block');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> contentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_hash');
    });
  }

  QueryBuilder<Post, List<int>, QQueryOperations> manifestBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'manifest_bytes');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> postCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_category');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_id');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> postStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_state');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> postTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_type');
    });
  }

  QueryBuilder<Post, int, QQueryOperations> publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'published_at');
    });
  }

  QueryBuilder<Post, String, QQueryOperations> receiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receipt_id');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDraftCollection on Isar {
  IsarCollection<Draft> get drafts => this.collection();
}

const DraftSchema = CollectionSchema(
  name: r'draft',
  id: 1941013616773274821,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'draft_id': PropertySchema(
      id: 1,
      name: r'draft_id',
      type: IsarType.string,
    ),
    r'media_data': PropertySchema(
      id: 2,
      name: r'media_data',
      type: IsarType.string,
    ),
    r'post_text': PropertySchema(
      id: 3,
      name: r'post_text',
      type: IsarType.string,
    ),
    r'post_title': PropertySchema(
      id: 4,
      name: r'post_title',
      type: IsarType.string,
    ),
    r'post_type': PropertySchema(
      id: 5,
      name: r'post_type',
      type: IsarType.string,
    ),
    r'section_data': PropertySchema(
      id: 6,
      name: r'section_data',
      type: IsarType.string,
    ),
    r'updated_at': PropertySchema(
      id: 7,
      name: r'updated_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _draftEstimateSize,
  serialize: _draftSerialize,
  deserialize: _draftDeserialize,
  deserializeProp: _draftDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_draft_id': IndexSchema(
      id: -1510474736432074356,
      name: r'cid_number_draft_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'draft_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'updated_at': IndexSchema(
      id: -1449665799000962892,
      name: r'updated_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updated_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _draftGetId,
  getLinks: _draftGetLinks,
  attach: _draftAttach,
  version: '3.3.2',
);

int _draftEstimateSize(
  Draft object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.draftId.length * 3;
  bytesCount += 3 + object.mediaData.length * 3;
  bytesCount += 3 + object.text.length * 3;
  {
    final value = object.title;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.postType.length * 3;
  {
    final value = object.sectionData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _draftSerialize(
  Draft object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.draftId);
  writer.writeString(offsets[2], object.mediaData);
  writer.writeString(offsets[3], object.text);
  writer.writeString(offsets[4], object.title);
  writer.writeString(offsets[5], object.postType);
  writer.writeString(offsets[6], object.sectionData);
  writer.writeLong(offsets[7], object.updatedAt);
}

Draft _draftDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Draft();
  object.cidNumber = reader.readString(offsets[0]);
  object.draftId = reader.readString(offsets[1]);
  object.mediaData = reader.readString(offsets[2]);
  object.text = reader.readString(offsets[3]);
  object.title = reader.readStringOrNull(offsets[4]);
  object.postType = reader.readString(offsets[5]);
  object.rowId = id;
  object.sectionData = reader.readStringOrNull(offsets[6]);
  object.updatedAt = reader.readLong(offsets[7]);
  return object;
}

P _draftDeserializeProp<P>(
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
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _draftGetId(Draft object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _draftGetLinks(Draft object) {
  return [];
}

void _draftAttach(IsarCollection<dynamic> col, Id id, Draft object) {
  object.rowId = id;
}

extension DraftByIndex on IsarCollection<Draft> {
  Future<Draft?> getByCidNumberDraftId(String cidNumber, String draftId) {
    return getByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Draft? getByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return getByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<bool> deleteByCidNumberDraftId(String cidNumber, String draftId) {
    return deleteByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  bool deleteByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return deleteByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<List<Draft?>> getAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndex(r'cid_number_draft_id', values);
  }

  List<Draft?> getAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<int> deleteAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_draft_id', values);
  }

  int deleteAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<Id> putByCidNumberDraftId(Draft object) {
    return putByIndex(r'cid_number_draft_id', object);
  }

  Id putByCidNumberDraftIdSync(Draft object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_draft_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberDraftId(List<Draft> objects) {
    return putAllByIndex(r'cid_number_draft_id', objects);
  }

  List<Id> putAllByCidNumberDraftIdSync(
    List<Draft> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_draft_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension DraftQueryWhereSort on QueryBuilder<Draft, Draft, QWhere> {
  QueryBuilder<Draft, Draft, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updated_at'),
      );
    });
  }
}

extension DraftQueryWhere on QueryBuilder<Draft, Draft, QWhereClause> {
  QueryBuilder<Draft, Draft, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Draft, Draft, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Draft, Draft, QAfterWhereClause> cidNumberEqualToAnyDraftId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> cidNumberNotEqualToAnyDraftId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> cidNumberDraftIdEqualTo(
    String cidNumber,
    String draftId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber, draftId],
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause>
  cidNumberEqualToDraftIdNotEqualTo(String cidNumber, String draftId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> updatedAtEqualTo(
    int updatedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'updated_at', value: [updatedAt]),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> updatedAtNotEqualTo(
    int updatedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> updatedAtGreaterThan(
    int updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [updatedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> updatedAtLessThan(
    int updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [],
          upper: [updatedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterWhereClause> updatedAtBetween(
    int lowerUpdatedAt,
    int upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [lowerUpdatedAt],
          includeLower: includeLower,
          upper: [upperUpdatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DraftQueryFilter on QueryBuilder<Draft, Draft, QFilterCondition> {
  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'draft_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'draft_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> draftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'media_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'media_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'media_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_data', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> mediaDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'media_data', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_text',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_text',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_text',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_text', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_text', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'post_title'),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'post_title'),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_title', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_title', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> postTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'section_data'),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'section_data'),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'section_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'section_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'section_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'section_data', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> sectionDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'section_data', value: ''),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> updatedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updated_at', value: value),
      );
    });
  }

  QueryBuilder<Draft, Draft, QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<Draft, Draft, QAfterFilterCondition> updatedAtBetween(
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

extension DraftQueryObject on QueryBuilder<Draft, Draft, QFilterCondition> {}

extension DraftQueryLinks on QueryBuilder<Draft, Draft, QFilterCondition> {}

extension DraftQuerySortBy on QueryBuilder<Draft, Draft, QSortBy> {
  QueryBuilder<Draft, Draft, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByMediaData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_data', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByMediaDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_data', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_text', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_text', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_title', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_title', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortBySectionData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'section_data', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortBySectionDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'section_data', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension DraftQuerySortThenBy on QueryBuilder<Draft, Draft, QSortThenBy> {
  QueryBuilder<Draft, Draft, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByMediaData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_data', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByMediaDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_data', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_text', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_text', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_title', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_title', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenBySectionData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'section_data', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenBySectionDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'section_data', Sort.desc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<Draft, Draft, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension DraftQueryWhereDistinct on QueryBuilder<Draft, Draft, QDistinct> {
  QueryBuilder<Draft, Draft, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByDraftId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draft_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByMediaData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByText({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_text', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByPostType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctBySectionData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'section_data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Draft, Draft, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated_at');
    });
  }
}

extension DraftQueryProperty on QueryBuilder<Draft, Draft, QQueryProperty> {
  QueryBuilder<Draft, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Draft, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Draft, String, QQueryOperations> draftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draft_id');
    });
  }

  QueryBuilder<Draft, String, QQueryOperations> mediaDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_data');
    });
  }

  QueryBuilder<Draft, String, QQueryOperations> textProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_text');
    });
  }

  QueryBuilder<Draft, String?, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_title');
    });
  }

  QueryBuilder<Draft, String, QQueryOperations> postTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_type');
    });
  }

  QueryBuilder<Draft, String?, QQueryOperations> sectionDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'section_data');
    });
  }

  QueryBuilder<Draft, int, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPostCursorCollection on Isar {
  IsarCollection<PostCursor> get postCursors => this.collection();
}

const PostCursorSchema = CollectionSchema(
  name: r'cursor',
  id: -7058571471948605105,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'post_id': PropertySchema(id: 1, name: r'post_id', type: IsarType.string),
    r'published_at': PropertySchema(
      id: 2,
      name: r'published_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _postCursorEstimateSize,
  serialize: _postCursorSerialize,
  deserialize: _postCursorDeserialize,
  deserializeProp: _postCursorDeserializeProp,
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

  getId: _postCursorGetId,
  getLinks: _postCursorGetLinks,
  attach: _postCursorAttach,
  version: '3.3.2',
);

int _postCursorEstimateSize(
  PostCursor object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.postId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _postCursorSerialize(
  PostCursor object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.postId);
  writer.writeLong(offsets[2], object.publishedAt);
}

PostCursor _postCursorDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PostCursor();
  object.cidNumber = reader.readString(offsets[0]);
  object.postId = reader.readStringOrNull(offsets[1]);
  object.publishedAt = reader.readLong(offsets[2]);
  object.rowId = id;
  return object;
}

P _postCursorDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _postCursorGetId(PostCursor object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _postCursorGetLinks(PostCursor object) {
  return [];
}

void _postCursorAttach(IsarCollection<dynamic> col, Id id, PostCursor object) {
  object.rowId = id;
}

extension PostCursorByIndex on IsarCollection<PostCursor> {
  Future<PostCursor?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  PostCursor? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<PostCursor?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<PostCursor?> getAllByCidNumberSync(List<String> cidNumberValues) {
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

  Future<Id> putByCidNumber(PostCursor object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(PostCursor object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<PostCursor> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<PostCursor> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension PostCursorQueryWhereSort
    on QueryBuilder<PostCursor, PostCursor, QWhere> {
  QueryBuilder<PostCursor, PostCursor, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PostCursorQueryWhere
    on QueryBuilder<PostCursor, PostCursor, QWhereClause> {
  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> rowIdEqualTo(
    Id rowId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> rowIdNotEqualTo(
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

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterWhereClause> cidNumberNotEqualTo(
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

extension PostCursorQueryFilter
    on QueryBuilder<PostCursor, PostCursor, QFilterCondition> {
  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'post_id'),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  postIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'post_id'),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  publishedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'published_at', value: value),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  publishedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  publishedAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition>
  publishedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'published_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<PostCursor, PostCursor, QAfterFilterCondition> rowIdBetween(
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

extension PostCursorQueryObject
    on QueryBuilder<PostCursor, PostCursor, QFilterCondition> {}

extension PostCursorQueryLinks
    on QueryBuilder<PostCursor, PostCursor, QFilterCondition> {}

extension PostCursorQuerySortBy
    on QueryBuilder<PostCursor, PostCursor, QSortBy> {
  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> sortByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }
}

extension PostCursorQuerySortThenBy
    on QueryBuilder<PostCursor, PostCursor, QSortThenBy> {
  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension PostCursorQueryWhereDistinct
    on QueryBuilder<PostCursor, PostCursor, QDistinct> {
  QueryBuilder<PostCursor, PostCursor, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QDistinct> distinctByPostId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostCursor, PostCursor, QDistinct> distinctByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'published_at');
    });
  }
}

extension PostCursorQueryProperty
    on QueryBuilder<PostCursor, PostCursor, QQueryProperty> {
  QueryBuilder<PostCursor, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<PostCursor, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<PostCursor, String?, QQueryOperations> postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_id');
    });
  }

  QueryBuilder<PostCursor, int, QQueryOperations> publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'published_at');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCleanupCollection on Isar {
  IsarCollection<Cleanup> get cleanups => this.collection();
}

const CleanupSchema = CollectionSchema(
  name: r'cleanup',
  id: -1097883712433237478,
  properties: {
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'cleanup_kind': PropertySchema(
      id: 1,
      name: r'cleanup_kind',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 2,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'draft_id': PropertySchema(
      id: 3,
      name: r'draft_id',
      type: IsarType.string,
    ),
    r'last_error': PropertySchema(
      id: 4,
      name: r'last_error',
      type: IsarType.string,
    ),
    r'try_count': PropertySchema(
      id: 5,
      name: r'try_count',
      type: IsarType.long,
    ),
  },

  estimateSize: _cleanupEstimateSize,
  serialize: _cleanupSerialize,
  deserialize: _cleanupDeserialize,
  deserializeProp: _cleanupDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_draft_id': IndexSchema(
      id: -1510474736432074356,
      name: r'cid_number_draft_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'draft_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _cleanupGetId,
  getLinks: _cleanupGetLinks,
  attach: _cleanupAttach,
  version: '3.3.2',
);

int _cleanupEstimateSize(
  Cleanup object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.cleanupKind.length * 3;
  bytesCount += 3 + object.draftId.length * 3;
  {
    final value = object.lastError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _cleanupSerialize(
  Cleanup object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.cleanupKind);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.draftId);
  writer.writeString(offsets[4], object.lastError);
  writer.writeLong(offsets[5], object.tryCount);
}

Cleanup _cleanupDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Cleanup();
  object.cidNumber = reader.readString(offsets[0]);
  object.cleanupKind = reader.readString(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.draftId = reader.readString(offsets[3]);
  object.lastError = reader.readStringOrNull(offsets[4]);
  object.rowId = id;
  object.tryCount = reader.readLong(offsets[5]);
  return object;
}

P _cleanupDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cleanupGetId(Cleanup object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _cleanupGetLinks(Cleanup object) {
  return [];
}

void _cleanupAttach(IsarCollection<dynamic> col, Id id, Cleanup object) {
  object.rowId = id;
}

extension CleanupByIndex on IsarCollection<Cleanup> {
  Future<Cleanup?> getByCidNumberDraftId(String cidNumber, String draftId) {
    return getByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Cleanup? getByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return getByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<bool> deleteByCidNumberDraftId(String cidNumber, String draftId) {
    return deleteByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  bool deleteByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return deleteByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<List<Cleanup?>> getAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndex(r'cid_number_draft_id', values);
  }

  List<Cleanup?> getAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<int> deleteAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_draft_id', values);
  }

  int deleteAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<Id> putByCidNumberDraftId(Cleanup object) {
    return putByIndex(r'cid_number_draft_id', object);
  }

  Id putByCidNumberDraftIdSync(Cleanup object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_draft_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberDraftId(List<Cleanup> objects) {
    return putAllByIndex(r'cid_number_draft_id', objects);
  }

  List<Id> putAllByCidNumberDraftIdSync(
    List<Cleanup> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_draft_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension CleanupQueryWhereSort on QueryBuilder<Cleanup, Cleanup, QWhere> {
  QueryBuilder<Cleanup, Cleanup, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CleanupQueryWhere on QueryBuilder<Cleanup, Cleanup, QWhereClause> {
  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> cidNumberEqualToAnyDraftId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause>
  cidNumberNotEqualToAnyDraftId(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause> cidNumberDraftIdEqualTo(
    String cidNumber,
    String draftId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber, draftId],
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterWhereClause>
  cidNumberEqualToDraftIdNotEqualTo(String cidNumber, String draftId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension CleanupQueryFilter
    on QueryBuilder<Cleanup, Cleanup, QFilterCondition> {
  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cleanup_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cleanup_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cleanup_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> cleanupKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cleanup_kind', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition>
  cleanupKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cleanup_kind', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> createdAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'draft_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'draft_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> draftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'last_error'),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'last_error'),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'last_error',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'last_error',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'last_error',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'last_error', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'last_error', value: ''),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> tryCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'try_count', value: value),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> tryCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'try_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> tryCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'try_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterFilterCondition> tryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'try_count',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CleanupQueryObject
    on QueryBuilder<Cleanup, Cleanup, QFilterCondition> {}

extension CleanupQueryLinks
    on QueryBuilder<Cleanup, Cleanup, QFilterCondition> {}

extension CleanupQuerySortBy on QueryBuilder<Cleanup, Cleanup, QSortBy> {
  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCleanupKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanup_kind', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCleanupKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanup_kind', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'last_error', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'last_error', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByTryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'try_count', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> sortByTryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'try_count', Sort.desc);
    });
  }
}

extension CleanupQuerySortThenBy
    on QueryBuilder<Cleanup, Cleanup, QSortThenBy> {
  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCleanupKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanup_kind', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCleanupKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanup_kind', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'last_error', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'last_error', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByTryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'try_count', Sort.asc);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QAfterSortBy> thenByTryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'try_count', Sort.desc);
    });
  }
}

extension CleanupQueryWhereDistinct
    on QueryBuilder<Cleanup, Cleanup, QDistinct> {
  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByCleanupKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cleanup_kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByDraftId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draft_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByLastError({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'last_error', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Cleanup, Cleanup, QDistinct> distinctByTryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'try_count');
    });
  }
}

extension CleanupQueryProperty
    on QueryBuilder<Cleanup, Cleanup, QQueryProperty> {
  QueryBuilder<Cleanup, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Cleanup, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Cleanup, String, QQueryOperations> cleanupKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cleanup_kind');
    });
  }

  QueryBuilder<Cleanup, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<Cleanup, String, QQueryOperations> draftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draft_id');
    });
  }

  QueryBuilder<Cleanup, String?, QQueryOperations> lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'last_error');
    });
  }

  QueryBuilder<Cleanup, int, QQueryOperations> tryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'try_count');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMediaCollection on Isar {
  IsarCollection<Media> get medias => this.collection();
}

const MediaSchema = CollectionSchema(
  name: r'media',
  id: -460020576612860404,
  properties: {
    r'body_hash': PropertySchema(
      id: 0,
      name: r'body_hash',
      type: IsarType.string,
    ),
    r'byte_size': PropertySchema(
      id: 1,
      name: r'byte_size',
      type: IsarType.long,
    ),
    r'cid_number': PropertySchema(
      id: 2,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'content_type': PropertySchema(
      id: 3,
      name: r'content_type',
      type: IsarType.string,
    ),
    r'is_complete': PropertySchema(
      id: 4,
      name: r'is_complete',
      type: IsarType.bool,
    ),
    r'media_kind': PropertySchema(
      id: 5,
      name: r'media_kind',
      type: IsarType.string,
    ),
  },

  estimateSize: _mediaEstimateSize,
  serialize: _mediaSerialize,
  deserialize: _mediaDeserialize,
  deserializeProp: _mediaDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_body_hash': IndexSchema(
      id: -8445791805654470301,
      name: r'cid_number_body_hash',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'body_hash',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mediaGetId,
  getLinks: _mediaGetLinks,
  attach: _mediaAttach,
  version: '3.3.2',
);

int _mediaEstimateSize(
  Media object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyHash.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentType.length * 3;
  bytesCount += 3 + object.mediaKind.length * 3;
  return bytesCount;
}

void _mediaSerialize(
  Media object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyHash);
  writer.writeLong(offsets[1], object.byteSize);
  writer.writeString(offsets[2], object.cidNumber);
  writer.writeString(offsets[3], object.contentType);
  writer.writeBool(offsets[4], object.isComplete);
  writer.writeString(offsets[5], object.mediaKind);
}

Media _mediaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Media();
  object.bodyHash = reader.readString(offsets[0]);
  object.byteSize = reader.readLong(offsets[1]);
  object.cidNumber = reader.readString(offsets[2]);
  object.contentType = reader.readString(offsets[3]);
  object.isComplete = reader.readBool(offsets[4]);
  object.mediaKind = reader.readString(offsets[5]);
  object.rowId = id;
  return object;
}

P _mediaDeserializeProp<P>(
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
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mediaGetId(Media object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _mediaGetLinks(Media object) {
  return [];
}

void _mediaAttach(IsarCollection<dynamic> col, Id id, Media object) {
  object.rowId = id;
}

extension MediaByIndex on IsarCollection<Media> {
  Future<Media?> getByCidNumberBodyHash(String cidNumber, String bodyHash) {
    return getByIndex(r'cid_number_body_hash', [cidNumber, bodyHash]);
  }

  Media? getByCidNumberBodyHashSync(String cidNumber, String bodyHash) {
    return getByIndexSync(r'cid_number_body_hash', [cidNumber, bodyHash]);
  }

  Future<bool> deleteByCidNumberBodyHash(String cidNumber, String bodyHash) {
    return deleteByIndex(r'cid_number_body_hash', [cidNumber, bodyHash]);
  }

  bool deleteByCidNumberBodyHashSync(String cidNumber, String bodyHash) {
    return deleteByIndexSync(r'cid_number_body_hash', [cidNumber, bodyHash]);
  }

  Future<List<Media?>> getAllByCidNumberBodyHash(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i]]);
    }

    return getAllByIndex(r'cid_number_body_hash', values);
  }

  List<Media?> getAllByCidNumberBodyHashSync(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_body_hash', values);
  }

  Future<int> deleteAllByCidNumberBodyHash(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_body_hash', values);
  }

  int deleteAllByCidNumberBodyHashSync(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_body_hash', values);
  }

  Future<Id> putByCidNumberBodyHash(Media object) {
    return putByIndex(r'cid_number_body_hash', object);
  }

  Id putByCidNumberBodyHashSync(Media object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'cid_number_body_hash',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByCidNumberBodyHash(List<Media> objects) {
    return putAllByIndex(r'cid_number_body_hash', objects);
  }

  List<Id> putAllByCidNumberBodyHashSync(
    List<Media> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_body_hash',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension MediaQueryWhereSort on QueryBuilder<Media, Media, QWhere> {
  QueryBuilder<Media, Media, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MediaQueryWhere on QueryBuilder<Media, Media, QWhereClause> {
  QueryBuilder<Media, Media, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Media, Media, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Media, Media, QAfterWhereClause> cidNumberEqualToAnyBodyHash(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_body_hash',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause> cidNumberNotEqualToAnyBodyHash(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause> cidNumberBodyHashEqualTo(
    String cidNumber,
    String bodyHash,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_body_hash',
          value: [cidNumber, bodyHash],
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterWhereClause>
  cidNumberEqualToBodyHashNotEqualTo(String cidNumber, String bodyHash) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber],
                upper: [cidNumber, bodyHash],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber, bodyHash],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber, bodyHash],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash',
                lower: [cidNumber],
                upper: [cidNumber, bodyHash],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MediaQueryFilter on QueryBuilder<Media, Media, QFilterCondition> {
  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashGreaterThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashLessThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashBetween(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> bodyHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> byteSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'byte_size', value: value),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> byteSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'byte_size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> byteSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'byte_size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> byteSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'byte_size',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content_type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content_type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_type', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> contentTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_type', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> isCompleteEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'is_complete', value: value),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'media_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'media_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'media_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_kind', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> mediaKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'media_kind', value: ''),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Media, Media, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Media, Media, QAfterFilterCondition> rowIdBetween(
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

extension MediaQueryObject on QueryBuilder<Media, Media, QFilterCondition> {}

extension MediaQueryLinks on QueryBuilder<Media, Media, QFilterCondition> {}

extension MediaQuerySortBy on QueryBuilder<Media, Media, QSortBy> {
  QueryBuilder<Media, Media, QAfterSortBy> sortByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByIsComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_complete', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByIsCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_complete', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByMediaKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_kind', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> sortByMediaKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_kind', Sort.desc);
    });
  }
}

extension MediaQuerySortThenBy on QueryBuilder<Media, Media, QSortThenBy> {
  QueryBuilder<Media, Media, QAfterSortBy> thenByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByIsComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_complete', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByIsCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_complete', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByMediaKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_kind', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByMediaKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_kind', Sort.desc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Media, Media, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension MediaQueryWhereDistinct on QueryBuilder<Media, Media, QDistinct> {
  QueryBuilder<Media, Media, QDistinct> distinctByBodyHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Media, Media, QDistinct> distinctByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'byte_size');
    });
  }

  QueryBuilder<Media, Media, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Media, Media, QDistinct> distinctByContentType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Media, Media, QDistinct> distinctByIsComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'is_complete');
    });
  }

  QueryBuilder<Media, Media, QDistinct> distinctByMediaKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_kind', caseSensitive: caseSensitive);
    });
  }
}

extension MediaQueryProperty on QueryBuilder<Media, Media, QQueryProperty> {
  QueryBuilder<Media, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Media, String, QQueryOperations> bodyHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_hash');
    });
  }

  QueryBuilder<Media, int, QQueryOperations> byteSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'byte_size');
    });
  }

  QueryBuilder<Media, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Media, String, QQueryOperations> contentTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_type');
    });
  }

  QueryBuilder<Media, bool, QQueryOperations> isCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'is_complete');
    });
  }

  QueryBuilder<Media, String, QQueryOperations> mediaKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_kind');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChunkCollection on Isar {
  IsarCollection<Chunk> get chunks => this.collection();
}

const ChunkSchema = CollectionSchema(
  name: r'chunk',
  id: 8438847523455501592,
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
    r'part_bytes': PropertySchema(
      id: 2,
      name: r'part_bytes',
      type: IsarType.byteList,
    ),
    r'part_hash': PropertySchema(
      id: 3,
      name: r'part_hash',
      type: IsarType.string,
    ),
    r'part_index': PropertySchema(
      id: 4,
      name: r'part_index',
      type: IsarType.long,
    ),
  },

  estimateSize: _chunkEstimateSize,
  serialize: _chunkSerialize,
  deserialize: _chunkDeserialize,
  deserializeProp: _chunkDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_body_hash_part_index': IndexSchema(
      id: 4214752058065696176,
      name: r'cid_number_body_hash_part_index',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'body_hash',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'part_index',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chunkGetId,
  getLinks: _chunkGetLinks,
  attach: _chunkAttach,
  version: '3.3.2',
);

int _chunkEstimateSize(
  Chunk object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyHash.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.partBytes.length;
  bytesCount += 3 + object.partHash.length * 3;
  return bytesCount;
}

void _chunkSerialize(
  Chunk object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyHash);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeByteList(offsets[2], object.partBytes);
  writer.writeString(offsets[3], object.partHash);
  writer.writeLong(offsets[4], object.partIndex);
}

Chunk _chunkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Chunk();
  object.bodyHash = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.partBytes = reader.readByteList(offsets[2]) ?? [];
  object.partHash = reader.readString(offsets[3]);
  object.partIndex = reader.readLong(offsets[4]);
  object.rowId = id;
  return object;
}

P _chunkDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chunkGetId(Chunk object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _chunkGetLinks(Chunk object) {
  return [];
}

void _chunkAttach(IsarCollection<dynamic> col, Id id, Chunk object) {
  object.rowId = id;
}

extension ChunkByIndex on IsarCollection<Chunk> {
  Future<Chunk?> getByCidNumberBodyHashPartIndex(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return getByIndex(r'cid_number_body_hash_part_index', [
      cidNumber,
      bodyHash,
      partIndex,
    ]);
  }

  Chunk? getByCidNumberBodyHashPartIndexSync(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return getByIndexSync(r'cid_number_body_hash_part_index', [
      cidNumber,
      bodyHash,
      partIndex,
    ]);
  }

  Future<bool> deleteByCidNumberBodyHashPartIndex(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return deleteByIndex(r'cid_number_body_hash_part_index', [
      cidNumber,
      bodyHash,
      partIndex,
    ]);
  }

  bool deleteByCidNumberBodyHashPartIndexSync(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return deleteByIndexSync(r'cid_number_body_hash_part_index', [
      cidNumber,
      bodyHash,
      partIndex,
    ]);
  }

  Future<List<Chunk?>> getAllByCidNumberBodyHashPartIndex(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
    List<int> partIndexValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len && partIndexValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i], partIndexValues[i]]);
    }

    return getAllByIndex(r'cid_number_body_hash_part_index', values);
  }

  List<Chunk?> getAllByCidNumberBodyHashPartIndexSync(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
    List<int> partIndexValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len && partIndexValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i], partIndexValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_body_hash_part_index', values);
  }

  Future<int> deleteAllByCidNumberBodyHashPartIndex(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
    List<int> partIndexValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len && partIndexValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i], partIndexValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_body_hash_part_index', values);
  }

  int deleteAllByCidNumberBodyHashPartIndexSync(
    List<String> cidNumberValues,
    List<String> bodyHashValues,
    List<int> partIndexValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      bodyHashValues.length == len && partIndexValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], bodyHashValues[i], partIndexValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_body_hash_part_index', values);
  }

  Future<Id> putByCidNumberBodyHashPartIndex(Chunk object) {
    return putByIndex(r'cid_number_body_hash_part_index', object);
  }

  Id putByCidNumberBodyHashPartIndexSync(
    Chunk object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'cid_number_body_hash_part_index',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByCidNumberBodyHashPartIndex(List<Chunk> objects) {
    return putAllByIndex(r'cid_number_body_hash_part_index', objects);
  }

  List<Id> putAllByCidNumberBodyHashPartIndexSync(
    List<Chunk> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_body_hash_part_index',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChunkQueryWhereSort on QueryBuilder<Chunk, Chunk, QWhere> {
  QueryBuilder<Chunk, Chunk, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChunkQueryWhere on QueryBuilder<Chunk, Chunk, QWhereClause> {
  QueryBuilder<Chunk, Chunk, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Chunk, Chunk, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberEqualToAnyBodyHashPartIndex(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_body_hash_part_index',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberNotEqualToAnyBodyHashPartIndex(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashEqualToAnyPartIndex(String cidNumber, String bodyHash) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_body_hash_part_index',
          value: [cidNumber, bodyHash],
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberEqualToBodyHashNotEqualToAnyPartIndex(
    String cidNumber,
    String bodyHash,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber],
                upper: [cidNumber, bodyHash],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber],
                upper: [cidNumber, bodyHash],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashPartIndexEqualTo(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_body_hash_part_index',
          value: [cidNumber, bodyHash, partIndex],
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashEqualToPartIndexNotEqualTo(
    String cidNumber,
    String bodyHash,
    int partIndex,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash],
                upper: [cidNumber, bodyHash, partIndex],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash, partIndex],
                includeLower: false,
                upper: [cidNumber, bodyHash],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash, partIndex],
                includeLower: false,
                upper: [cidNumber, bodyHash],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_body_hash_part_index',
                lower: [cidNumber, bodyHash],
                upper: [cidNumber, bodyHash, partIndex],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashEqualToPartIndexGreaterThan(
    String cidNumber,
    String bodyHash,
    int partIndex, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_body_hash_part_index',
          lower: [cidNumber, bodyHash, partIndex],
          includeLower: include,
          upper: [cidNumber, bodyHash],
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashEqualToPartIndexLessThan(
    String cidNumber,
    String bodyHash,
    int partIndex, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_body_hash_part_index',
          lower: [cidNumber, bodyHash],
          upper: [cidNumber, bodyHash, partIndex],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterWhereClause>
  cidNumberBodyHashEqualToPartIndexBetween(
    String cidNumber,
    String bodyHash,
    int lowerPartIndex,
    int upperPartIndex, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cid_number_body_hash_part_index',
          lower: [cidNumber, bodyHash, lowerPartIndex],
          includeLower: includeLower,
          upper: [cidNumber, bodyHash, upperPartIndex],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChunkQueryFilter on QueryBuilder<Chunk, Chunk, QFilterCondition> {
  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashGreaterThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashLessThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashBetween(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> bodyHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesElementEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'part_bytes', value: value),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'part_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'part_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'part_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'part_bytes', length, true, length, true);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'part_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'part_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'part_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'part_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'part_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'part_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'part_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'part_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'part_hash', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'part_hash', value: ''),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partIndexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'part_index', value: value),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'part_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'part_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> partIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'part_index',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Chunk, Chunk, QAfterFilterCondition> rowIdBetween(
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

extension ChunkQueryObject on QueryBuilder<Chunk, Chunk, QFilterCondition> {}

extension ChunkQueryLinks on QueryBuilder<Chunk, Chunk, QFilterCondition> {}

extension ChunkQuerySortBy on QueryBuilder<Chunk, Chunk, QSortBy> {
  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByPartHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_hash', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByPartHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_hash', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByPartIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_index', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> sortByPartIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_index', Sort.desc);
    });
  }
}

extension ChunkQuerySortThenBy on QueryBuilder<Chunk, Chunk, QSortThenBy> {
  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByPartHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_hash', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByPartHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_hash', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByPartIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_index', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByPartIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'part_index', Sort.desc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Chunk, Chunk, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension ChunkQueryWhereDistinct on QueryBuilder<Chunk, Chunk, QDistinct> {
  QueryBuilder<Chunk, Chunk, QDistinct> distinctByBodyHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Chunk, Chunk, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Chunk, Chunk, QDistinct> distinctByPartBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'part_bytes');
    });
  }

  QueryBuilder<Chunk, Chunk, QDistinct> distinctByPartHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'part_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Chunk, Chunk, QDistinct> distinctByPartIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'part_index');
    });
  }
}

extension ChunkQueryProperty on QueryBuilder<Chunk, Chunk, QQueryProperty> {
  QueryBuilder<Chunk, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Chunk, String, QQueryOperations> bodyHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_hash');
    });
  }

  QueryBuilder<Chunk, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Chunk, List<int>, QQueryOperations> partBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'part_bytes');
    });
  }

  QueryBuilder<Chunk, String, QQueryOperations> partHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'part_hash');
    });
  }

  QueryBuilder<Chunk, int, QQueryOperations> partIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'part_index');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMediaLinkCollection on Isar {
  IsarCollection<MediaLink> get mediaLinks => this.collection();
}

const MediaLinkSchema = CollectionSchema(
  name: r'link',
  id: 1895339948848804316,
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
    r'content_id': PropertySchema(
      id: 2,
      name: r'content_id',
      type: IsarType.string,
    ),
    r'content_kind': PropertySchema(
      id: 3,
      name: r'content_kind',
      type: IsarType.string,
    ),
    r'media_index': PropertySchema(
      id: 4,
      name: r'media_index',
      type: IsarType.long,
    ),
    r'media_role': PropertySchema(
      id: 5,
      name: r'media_role',
      type: IsarType.string,
    ),
  },

  estimateSize: _mediaLinkEstimateSize,
  serialize: _mediaLinkSerialize,
  deserialize: _mediaLinkDeserialize,
  deserializeProp: _mediaLinkDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'body_hash_cid_number': IndexSchema(
      id: 1442480815105803372,
      name: r'body_hash_cid_number',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'body_hash',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'content_id_cid_number_content_kind': IndexSchema(
      id: 8072973519240647616,
      name: r'content_id_cid_number_content_kind',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'content_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'content_kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mediaLinkGetId,
  getLinks: _mediaLinkGetLinks,
  attach: _mediaLinkAttach,
  version: '3.3.2',
);

int _mediaLinkEstimateSize(
  MediaLink object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyHash.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentId.length * 3;
  bytesCount += 3 + object.contentKind.length * 3;
  bytesCount += 3 + object.mediaRole.length * 3;
  return bytesCount;
}

void _mediaLinkSerialize(
  MediaLink object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyHash);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeString(offsets[2], object.contentId);
  writer.writeString(offsets[3], object.contentKind);
  writer.writeLong(offsets[4], object.mediaIndex);
  writer.writeString(offsets[5], object.mediaRole);
}

MediaLink _mediaLinkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MediaLink();
  object.bodyHash = reader.readString(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.contentId = reader.readString(offsets[2]);
  object.contentKind = reader.readString(offsets[3]);
  object.mediaIndex = reader.readLong(offsets[4]);
  object.mediaRole = reader.readString(offsets[5]);
  object.rowId = id;
  return object;
}

P _mediaLinkDeserializeProp<P>(
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
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mediaLinkGetId(MediaLink object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _mediaLinkGetLinks(MediaLink object) {
  return [];
}

void _mediaLinkAttach(IsarCollection<dynamic> col, Id id, MediaLink object) {
  object.rowId = id;
}

extension MediaLinkQueryWhereSort
    on QueryBuilder<MediaLink, MediaLink, QWhere> {
  QueryBuilder<MediaLink, MediaLink, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MediaLinkQueryWhere
    on QueryBuilder<MediaLink, MediaLink, QWhereClause> {
  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause> rowIdNotEqualTo(
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

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  bodyHashEqualToAnyCidNumber(String bodyHash) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'body_hash_cid_number',
          value: [bodyHash],
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  bodyHashNotEqualToAnyCidNumber(String bodyHash) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [],
                upper: [bodyHash],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [],
                upper: [bodyHash],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  bodyHashCidNumberEqualTo(String bodyHash, String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'body_hash_cid_number',
          value: [bodyHash, cidNumber],
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  bodyHashEqualToCidNumberNotEqualTo(String bodyHash, String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash],
                upper: [bodyHash, cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash, cidNumber],
                includeLower: false,
                upper: [bodyHash],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash, cidNumber],
                includeLower: false,
                upper: [bodyHash],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'body_hash_cid_number',
                lower: [bodyHash],
                upper: [bodyHash, cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdEqualToAnyCidNumberContentKind(String contentId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'content_id_cid_number_content_kind',
          value: [contentId],
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdNotEqualToAnyCidNumberContentKind(String contentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [],
                upper: [contentId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [],
                upper: [contentId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdCidNumberEqualToAnyContentKind(String contentId, String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'content_id_cid_number_content_kind',
          value: [contentId, cidNumber],
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdEqualToCidNumberNotEqualToAnyContentKind(
    String contentId,
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId],
                upper: [contentId, cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber],
                includeLower: false,
                upper: [contentId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber],
                includeLower: false,
                upper: [contentId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId],
                upper: [contentId, cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdCidNumberContentKindEqualTo(
    String contentId,
    String cidNumber,
    String contentKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'content_id_cid_number_content_kind',
          value: [contentId, cidNumber, contentKind],
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterWhereClause>
  contentIdCidNumberEqualToContentKindNotEqualTo(
    String contentId,
    String cidNumber,
    String contentKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber],
                upper: [contentId, cidNumber, contentKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber, contentKind],
                includeLower: false,
                upper: [contentId, cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber, contentKind],
                includeLower: false,
                upper: [contentId, cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'content_id_cid_number_content_kind',
                lower: [contentId, cidNumber],
                upper: [contentId, cidNumber, contentKind],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MediaLinkQueryFilter
    on QueryBuilder<MediaLink, MediaLink, QFilterCondition> {
  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashGreaterThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashLessThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashBetween(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> bodyHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  bodyHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body_hash', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_id', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_id', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentKindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> contentKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_kind', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  contentKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_kind', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaIndexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_index', value: value),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  mediaIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'media_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'media_index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'media_index',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleLessThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleBetween(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> mediaRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'media_role', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition>
  mediaRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'media_role', value: ''),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<MediaLink, MediaLink, QAfterFilterCondition> rowIdBetween(
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

extension MediaLinkQueryObject
    on QueryBuilder<MediaLink, MediaLink, QFilterCondition> {}

extension MediaLinkQueryLinks
    on QueryBuilder<MediaLink, MediaLink, QFilterCondition> {}

extension MediaLinkQuerySortBy on QueryBuilder<MediaLink, MediaLink, QSortBy> {
  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByContentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_id', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByContentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_id', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByContentKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_kind', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByContentKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_kind', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByMediaIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_index', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByMediaIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_index', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByMediaRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> sortByMediaRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.desc);
    });
  }
}

extension MediaLinkQuerySortThenBy
    on QueryBuilder<MediaLink, MediaLink, QSortThenBy> {
  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByBodyHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByBodyHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body_hash', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByContentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_id', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByContentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_id', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByContentKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_kind', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByContentKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_kind', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByMediaIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_index', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByMediaIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_index', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByMediaRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByMediaRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'media_role', Sort.desc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }
}

extension MediaLinkQueryWhereDistinct
    on QueryBuilder<MediaLink, MediaLink, QDistinct> {
  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByBodyHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByContentId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByContentKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByMediaIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_index');
    });
  }

  QueryBuilder<MediaLink, MediaLink, QDistinct> distinctByMediaRole({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'media_role', caseSensitive: caseSensitive);
    });
  }
}

extension MediaLinkQueryProperty
    on QueryBuilder<MediaLink, MediaLink, QQueryProperty> {
  QueryBuilder<MediaLink, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<MediaLink, String, QQueryOperations> bodyHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body_hash');
    });
  }

  QueryBuilder<MediaLink, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<MediaLink, String, QQueryOperations> contentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_id');
    });
  }

  QueryBuilder<MediaLink, String, QQueryOperations> contentKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_kind');
    });
  }

  QueryBuilder<MediaLink, int, QQueryOperations> mediaIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_index');
    });
  }

  QueryBuilder<MediaLink, String, QQueryOperations> mediaRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media_role');
    });
  }
}
// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPublishCollection on Isar {
  IsarCollection<Publish> get publishs => this.collection();
}

const PublishSchema = CollectionSchema(
  name: r'publish',
  id: 8191142308028790580,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'chain_block': PropertySchema(
      id: 1,
      name: r'chain_block',
      type: IsarType.long,
    ),
    r'chain_hash': PropertySchema(
      id: 2,
      name: r'chain_hash',
      type: IsarType.string,
    ),
    r'cid_number': PropertySchema(
      id: 3,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'content_hash': PropertySchema(
      id: 4,
      name: r'content_hash',
      type: IsarType.string,
    ),
    r'draft_id': PropertySchema(
      id: 5,
      name: r'draft_id',
      type: IsarType.string,
    ),
    r'job_state': PropertySchema(
      id: 6,
      name: r'job_state',
      type: IsarType.string,
    ),
    r'manifest_bytes': PropertySchema(
      id: 7,
      name: r'manifest_bytes',
      type: IsarType.byteList,
    ),
    r'post_category': PropertySchema(
      id: 8,
      name: r'post_category',
      type: IsarType.string,
    ),
    r'post_id': PropertySchema(id: 9, name: r'post_id', type: IsarType.string),
    r'post_type': PropertySchema(
      id: 10,
      name: r'post_type',
      type: IsarType.string,
    ),
    r'published_at': PropertySchema(
      id: 11,
      name: r'published_at',
      type: IsarType.long,
    ),
    r'receipt_id': PropertySchema(
      id: 12,
      name: r'receipt_id',
      type: IsarType.string,
    ),
    r'replace_id': PropertySchema(
      id: 13,
      name: r'replace_id',
      type: IsarType.string,
    ),
    r'tx_hash': PropertySchema(id: 14, name: r'tx_hash', type: IsarType.string),
    r'upload_id': PropertySchema(
      id: 15,
      name: r'upload_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _publishEstimateSize,
  serialize: _publishSerialize,
  deserialize: _publishDeserialize,
  deserializeProp: _publishDeserializeProp,
  idName: r'row_id',
  indexes: {
    r'cid_number_draft_id': IndexSchema(
      id: -1510474736432074356,
      name: r'cid_number_draft_id',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'draft_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _publishGetId,
  getLinks: _publishGetLinks,
  attach: _publishAttach,
  version: '3.3.2',
);

int _publishEstimateSize(
  Publish object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  {
    final value = object.chainHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentHash.length * 3;
  bytesCount += 3 + object.draftId.length * 3;
  bytesCount += 3 + object.jobState.length * 3;
  bytesCount += 3 + object.manifestBytes.length;
  {
    final value = object.postCategory;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.postId.length * 3;
  bytesCount += 3 + object.postType.length * 3;
  bytesCount += 3 + object.receiptId.length * 3;
  {
    final value = object.replaceId;
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
  bytesCount += 3 + object.uploadId.length * 3;
  return bytesCount;
}

void _publishSerialize(
  Publish object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.chainBlock);
  writer.writeString(offsets[2], object.chainHash);
  writer.writeString(offsets[3], object.cidNumber);
  writer.writeString(offsets[4], object.contentHash);
  writer.writeString(offsets[5], object.draftId);
  writer.writeString(offsets[6], object.jobState);
  writer.writeByteList(offsets[7], object.manifestBytes);
  writer.writeString(offsets[8], object.postCategory);
  writer.writeString(offsets[9], object.postId);
  writer.writeString(offsets[10], object.postType);
  writer.writeLong(offsets[11], object.publishedAt);
  writer.writeString(offsets[12], object.receiptId);
  writer.writeString(offsets[13], object.replaceId);
  writer.writeString(offsets[14], object.txHash);
  writer.writeString(offsets[15], object.uploadId);
}

Publish _publishDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Publish();
  object.accountId = reader.readString(offsets[0]);
  object.chainBlock = reader.readLongOrNull(offsets[1]);
  object.chainHash = reader.readStringOrNull(offsets[2]);
  object.cidNumber = reader.readString(offsets[3]);
  object.contentHash = reader.readString(offsets[4]);
  object.draftId = reader.readString(offsets[5]);
  object.jobState = reader.readString(offsets[6]);
  object.manifestBytes = reader.readByteList(offsets[7]) ?? [];
  object.postCategory = reader.readStringOrNull(offsets[8]);
  object.postId = reader.readString(offsets[9]);
  object.postType = reader.readString(offsets[10]);
  object.publishedAt = reader.readLongOrNull(offsets[11]);
  object.receiptId = reader.readString(offsets[12]);
  object.replaceId = reader.readStringOrNull(offsets[13]);
  object.rowId = id;
  object.txHash = reader.readStringOrNull(offsets[14]);
  object.uploadId = reader.readString(offsets[15]);
  return object;
}

P _publishDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readByteList(offset) ?? []) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _publishGetId(Publish object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _publishGetLinks(Publish object) {
  return [];
}

void _publishAttach(IsarCollection<dynamic> col, Id id, Publish object) {
  object.rowId = id;
}

extension PublishByIndex on IsarCollection<Publish> {
  Future<Publish?> getByCidNumberDraftId(String cidNumber, String draftId) {
    return getByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Publish? getByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return getByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<bool> deleteByCidNumberDraftId(String cidNumber, String draftId) {
    return deleteByIndex(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  bool deleteByCidNumberDraftIdSync(String cidNumber, String draftId) {
    return deleteByIndexSync(r'cid_number_draft_id', [cidNumber, draftId]);
  }

  Future<List<Publish?>> getAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndex(r'cid_number_draft_id', values);
  }

  List<Publish?> getAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return getAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<int> deleteAllByCidNumberDraftId(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndex(r'cid_number_draft_id', values);
  }

  int deleteAllByCidNumberDraftIdSync(
    List<String> cidNumberValues,
    List<String> draftIdValues,
  ) {
    final len = cidNumberValues.length;
    assert(
      draftIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([cidNumberValues[i], draftIdValues[i]]);
    }

    return deleteAllByIndexSync(r'cid_number_draft_id', values);
  }

  Future<Id> putByCidNumberDraftId(Publish object) {
    return putByIndex(r'cid_number_draft_id', object);
  }

  Id putByCidNumberDraftIdSync(Publish object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_draft_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberDraftId(List<Publish> objects) {
    return putAllByIndex(r'cid_number_draft_id', objects);
  }

  List<Id> putAllByCidNumberDraftIdSync(
    List<Publish> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'cid_number_draft_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension PublishQueryWhereSort on QueryBuilder<Publish, Publish, QWhere> {
  QueryBuilder<Publish, Publish, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PublishQueryWhere on QueryBuilder<Publish, Publish, QWhereClause> {
  QueryBuilder<Publish, Publish, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Publish, Publish, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Publish, Publish, QAfterWhereClause> cidNumberEqualToAnyDraftId(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber],
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause>
  cidNumberNotEqualToAnyDraftId(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause> cidNumberDraftIdEqualTo(
    String cidNumber,
    String draftId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'cid_number_draft_id',
          value: [cidNumber, draftId],
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterWhereClause>
  cidNumberEqualToDraftIdNotEqualTo(String cidNumber, String draftId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber, draftId],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_draft_id',
                lower: [cidNumber],
                upper: [cidNumber, draftId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension PublishQueryFilter
    on QueryBuilder<Publish, Publish, QFilterCondition> {
  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdEqualTo(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdStartsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdEndsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdContains(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdMatches(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'chain_block'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'chain_block'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chain_block', value: value),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'chain_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'chain_block',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainBlockBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'chain_block',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'chain_hash'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'chain_hash'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'chain_hash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'chain_hash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'chain_hash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chain_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> chainHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'chain_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashEqualTo(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashStartsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashEndsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashContains(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashMatches(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> contentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  contentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'draft_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'draft_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'draft_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> draftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'draft_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateEqualTo(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateStartsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateEndsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateContains(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateMatches(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> jobStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'job_state', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'manifest_bytes', value: value),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'manifest_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'manifest_bytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'manifest_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', length, true, length, true);
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> manifestBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, true, 0, true);
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', 0, true, length, include);
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'manifest_bytes', length, include, 999999, true);
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  manifestBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifest_bytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'post_category'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  postCategoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'post_category'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_category',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_category', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition>
  postCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_category', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'post_type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'post_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'post_type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> postTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'post_type', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'published_at'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'published_at'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'published_at', value: value),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'published_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> publishedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'published_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receipt_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'receipt_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'receipt_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receipt_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> receiptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'receipt_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'replace_id'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'replace_id'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'replace_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'replace_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'replace_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'replace_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> replaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'replace_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> rowIdGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> rowIdLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> rowIdBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'tx_hash'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'tx_hash'),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashEqualTo(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashGreaterThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashLessThan(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashBetween(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashStartsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashEndsWith(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashContains(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashMatches(
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

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tx_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> txHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tx_hash', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'upload_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'upload_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'upload_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'upload_id', value: ''),
      );
    });
  }

  QueryBuilder<Publish, Publish, QAfterFilterCondition> uploadIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'upload_id', value: ''),
      );
    });
  }
}

extension PublishQueryObject
    on QueryBuilder<Publish, Publish, QFilterCondition> {}

extension PublishQueryLinks
    on QueryBuilder<Publish, Publish, QFilterCondition> {}

extension PublishQuerySortBy on QueryBuilder<Publish, Publish, QSortBy> {
  QueryBuilder<Publish, Publish, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByChainHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByChainHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByReplaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replace_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByReplaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replace_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByTxHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByTxHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByUploadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'upload_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> sortByUploadIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'upload_id', Sort.desc);
    });
  }
}

extension PublishQuerySortThenBy
    on QueryBuilder<Publish, Publish, QSortThenBy> {
  QueryBuilder<Publish, Publish, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_block', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByChainHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByChainHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chain_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'job_state', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_category', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'post_type', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'published_at', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receipt_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByReplaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replace_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByReplaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replace_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByTxHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByTxHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tx_hash', Sort.desc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByUploadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'upload_id', Sort.asc);
    });
  }

  QueryBuilder<Publish, Publish, QAfterSortBy> thenByUploadIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'upload_id', Sort.desc);
    });
  }
}

extension PublishQueryWhereDistinct
    on QueryBuilder<Publish, Publish, QDistinct> {
  QueryBuilder<Publish, Publish, QDistinct> distinctByAccountId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chain_block');
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByChainHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chain_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByContentHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByDraftId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draft_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByJobState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'job_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByManifestBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'manifest_bytes');
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByPostCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'post_category',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByPostId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByPostType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'post_type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'published_at');
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByReceiptId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receipt_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByReplaceId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'replace_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByTxHash({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tx_hash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Publish, Publish, QDistinct> distinctByUploadId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'upload_id', caseSensitive: caseSensitive);
    });
  }
}

extension PublishQueryProperty
    on QueryBuilder<Publish, Publish, QQueryProperty> {
  QueryBuilder<Publish, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'row_id');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Publish, int?, QQueryOperations> chainBlockProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chain_block');
    });
  }

  QueryBuilder<Publish, String?, QQueryOperations> chainHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chain_hash');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> contentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_hash');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> draftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draft_id');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> jobStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'job_state');
    });
  }

  QueryBuilder<Publish, List<int>, QQueryOperations> manifestBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'manifest_bytes');
    });
  }

  QueryBuilder<Publish, String?, QQueryOperations> postCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_category');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_id');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> postTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'post_type');
    });
  }

  QueryBuilder<Publish, int?, QQueryOperations> publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'published_at');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> receiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receipt_id');
    });
  }

  QueryBuilder<Publish, String?, QQueryOperations> replaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replace_id');
    });
  }

  QueryBuilder<Publish, String?, QQueryOperations> txHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tx_hash');
    });
  }

  QueryBuilder<Publish, String, QQueryOperations> uploadIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'upload_id');
    });
  }
}
