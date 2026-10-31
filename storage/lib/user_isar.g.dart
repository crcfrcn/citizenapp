// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_isar.dart';

// ignore_for_file: experimental_member_use

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRegionCollection on Isar {
  IsarCollection<Region> get regions => this.collection();
}

const RegionSchema = CollectionSchema(
  name: r'region',
  id: 2740768521267464717,
  properties: {
    r'city_code': PropertySchema(
      id: 0,
      name: r'city_code',
      type: IsarType.string,
    ),
    r'province_code': PropertySchema(
      id: 1,
      name: r'province_code',
      type: IsarType.string,
    ),
    r'region_name': PropertySchema(
      id: 2,
      name: r'region_name',
      type: IsarType.string,
    ),
    r'town_code': PropertySchema(
      id: 3,
      name: r'town_code',
      type: IsarType.string,
    ),
  },

  estimateSize: _regionEstimateSize,
  serialize: _regionSerialize,
  deserialize: _regionDeserialize,
  deserializeProp: _regionDeserializeProp,
  idName: r'id',
  indexes: {
    r'province_code_city_code_town_code': IndexSchema(
      id: -3107767146403445762,
      name: r'province_code_city_code_town_code',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'province_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'city_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'town_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _regionGetId,
  getLinks: _regionGetLinks,
  attach: _regionAttach,
  version: '3.3.2',
);

int _regionEstimateSize(
  Region object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cityCode.length * 3;
  bytesCount += 3 + object.provinceCode.length * 3;
  bytesCount += 3 + object.regionName.length * 3;
  bytesCount += 3 + object.townCode.length * 3;
  return bytesCount;
}

void _regionSerialize(
  Region object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cityCode);
  writer.writeString(offsets[1], object.provinceCode);
  writer.writeString(offsets[2], object.regionName);
  writer.writeString(offsets[3], object.townCode);
}

Region _regionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Region();
  object.cityCode = reader.readString(offsets[0]);
  object.rowId = id;
  object.provinceCode = reader.readString(offsets[1]);
  object.regionName = reader.readString(offsets[2]);
  object.townCode = reader.readString(offsets[3]);
  return object;
}

P _regionDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _regionGetId(Region object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _regionGetLinks(Region object) {
  return [];
}

void _regionAttach(IsarCollection<dynamic> col, Id id, Region object) {
  object.rowId = id;
}

extension RegionByIndex on IsarCollection<Region> {
  Future<Region?> getByProvinceCodeCityCodeTownCode(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return getByIndex(r'province_code_city_code_town_code', [
      provinceCode,
      cityCode,
      townCode,
    ]);
  }

  Region? getByProvinceCodeCityCodeTownCodeSync(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return getByIndexSync(r'province_code_city_code_town_code', [
      provinceCode,
      cityCode,
      townCode,
    ]);
  }

  Future<bool> deleteByProvinceCodeCityCodeTownCode(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return deleteByIndex(r'province_code_city_code_town_code', [
      provinceCode,
      cityCode,
      townCode,
    ]);
  }

  bool deleteByProvinceCodeCityCodeTownCodeSync(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return deleteByIndexSync(r'province_code_city_code_town_code', [
      provinceCode,
      cityCode,
      townCode,
    ]);
  }

  Future<List<Region?>> getAllByProvinceCodeCityCodeTownCode(
    List<String> provinceCodeValues,
    List<String> cityCodeValues,
    List<String> townCodeValues,
  ) {
    final len = provinceCodeValues.length;
    assert(
      cityCodeValues.length == len && townCodeValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([provinceCodeValues[i], cityCodeValues[i], townCodeValues[i]]);
    }

    return getAllByIndex(r'province_code_city_code_town_code', values);
  }

  List<Region?> getAllByProvinceCodeCityCodeTownCodeSync(
    List<String> provinceCodeValues,
    List<String> cityCodeValues,
    List<String> townCodeValues,
  ) {
    final len = provinceCodeValues.length;
    assert(
      cityCodeValues.length == len && townCodeValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([provinceCodeValues[i], cityCodeValues[i], townCodeValues[i]]);
    }

    return getAllByIndexSync(r'province_code_city_code_town_code', values);
  }

  Future<int> deleteAllByProvinceCodeCityCodeTownCode(
    List<String> provinceCodeValues,
    List<String> cityCodeValues,
    List<String> townCodeValues,
  ) {
    final len = provinceCodeValues.length;
    assert(
      cityCodeValues.length == len && townCodeValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([provinceCodeValues[i], cityCodeValues[i], townCodeValues[i]]);
    }

    return deleteAllByIndex(r'province_code_city_code_town_code', values);
  }

  int deleteAllByProvinceCodeCityCodeTownCodeSync(
    List<String> provinceCodeValues,
    List<String> cityCodeValues,
    List<String> townCodeValues,
  ) {
    final len = provinceCodeValues.length;
    assert(
      cityCodeValues.length == len && townCodeValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([provinceCodeValues[i], cityCodeValues[i], townCodeValues[i]]);
    }

    return deleteAllByIndexSync(r'province_code_city_code_town_code', values);
  }

  Future<Id> putByProvinceCodeCityCodeTownCode(Region object) {
    return putByIndex(r'province_code_city_code_town_code', object);
  }

  Id putByProvinceCodeCityCodeTownCodeSync(
    Region object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'province_code_city_code_town_code',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByProvinceCodeCityCodeTownCode(List<Region> objects) {
    return putAllByIndex(r'province_code_city_code_town_code', objects);
  }

  List<Id> putAllByProvinceCodeCityCodeTownCodeSync(
    List<Region> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'province_code_city_code_town_code',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension RegionQueryWhereSort on QueryBuilder<Region, Region, QWhere> {
  QueryBuilder<Region, Region, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RegionQueryWhere on QueryBuilder<Region, Region, QWhereClause> {
  QueryBuilder<Region, Region, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Region, Region, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeEqualToAnyCityCodeTownCode(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'province_code_city_code_town_code',
          value: [provinceCode],
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeNotEqualToAnyCityCodeTownCode(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeCityCodeEqualToAnyTownCode(String provinceCode, String cityCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'province_code_city_code_town_code',
          value: [provinceCode, cityCode],
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeEqualToCityCodeNotEqualToAnyTownCode(
    String provinceCode,
    String cityCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode],
                upper: [provinceCode, cityCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode],
                includeLower: false,
                upper: [provinceCode],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode],
                includeLower: false,
                upper: [provinceCode],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode],
                upper: [provinceCode, cityCode],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeCityCodeTownCodeEqualTo(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'province_code_city_code_town_code',
          value: [provinceCode, cityCode, townCode],
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterWhereClause>
  provinceCodeCityCodeEqualToTownCodeNotEqualTo(
    String provinceCode,
    String cityCode,
    String townCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode],
                upper: [provinceCode, cityCode, townCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode, townCode],
                includeLower: false,
                upper: [provinceCode, cityCode],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode, townCode],
                includeLower: false,
                upper: [provinceCode, cityCode],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code_city_code_town_code',
                lower: [provinceCode, cityCode],
                upper: [provinceCode, cityCode, townCode],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension RegionQueryFilter on QueryBuilder<Region, Region, QFilterCondition> {
  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'city_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'city_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'city_code', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> cityCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'city_code', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'province_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'province_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'province_code', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> provinceCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'province_code', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'region_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'region_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'region_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'region_name', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> regionNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'region_name', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'town_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'town_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'town_code', value: ''),
      );
    });
  }

  QueryBuilder<Region, Region, QAfterFilterCondition> townCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'town_code', value: ''),
      );
    });
  }
}

extension RegionQueryObject on QueryBuilder<Region, Region, QFilterCondition> {}

extension RegionQueryLinks on QueryBuilder<Region, Region, QFilterCondition> {}

extension RegionQuerySortBy on QueryBuilder<Region, Region, QSortBy> {
  QueryBuilder<Region, Region, QAfterSortBy> sortByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByRegionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'region_name', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByRegionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'region_name', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> sortByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.desc);
    });
  }
}

extension RegionQuerySortThenBy on QueryBuilder<Region, Region, QSortThenBy> {
  QueryBuilder<Region, Region, QAfterSortBy> thenByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByRegionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'region_name', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByRegionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'region_name', Sort.desc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.desc);
    });
  }
}

extension RegionQueryWhereDistinct on QueryBuilder<Region, Region, QDistinct> {
  QueryBuilder<Region, Region, QDistinct> distinctByCityCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'city_code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Region, Region, QDistinct> distinctByProvinceCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'province_code',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Region, Region, QDistinct> distinctByRegionName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'region_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Region, Region, QDistinct> distinctByTownCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'town_code', caseSensitive: caseSensitive);
    });
  }
}

extension RegionQueryProperty on QueryBuilder<Region, Region, QQueryProperty> {
  QueryBuilder<Region, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Region, String, QQueryOperations> cityCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'city_code');
    });
  }

  QueryBuilder<Region, String, QQueryOperations> provinceCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'province_code');
    });
  }

  QueryBuilder<Region, String, QQueryOperations> regionNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'region_name');
    });
  }

  QueryBuilder<Region, String, QQueryOperations> townCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'town_code');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEntityCollection on Isar {
  IsarCollection<Entity> get entitys => this.collection();
}

const EntitySchema = CollectionSchema(
  name: r'entity',
  id: -5285054254130720380,
  properties: {
    r'account_count': PropertySchema(
      id: 0,
      name: r'account_count',
      type: IsarType.long,
    ),
    r'account_names': PropertySchema(
      id: 1,
      name: r'account_names',
      type: IsarType.stringList,
    ),
    r'cid_number': PropertySchema(
      id: 2,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'cid_state': PropertySchema(
      id: 3,
      name: r'cid_state',
      type: IsarType.string,
    ),
    r'city_code': PropertySchema(
      id: 4,
      name: r'city_code',
      type: IsarType.string,
    ),
    r'family_name': PropertySchema(
      id: 5,
      name: r'family_name',
      type: IsarType.string,
    ),
    r'full_name': PropertySchema(
      id: 6,
      name: r'full_name',
      type: IsarType.string,
    ),
    r'given_name': PropertySchema(
      id: 7,
      name: r'given_name',
      type: IsarType.string,
    ),
    r'is_legal': PropertySchema(id: 8, name: r'is_legal', type: IsarType.bool),
    r'legal_account': PropertySchema(
      id: 9,
      name: r'legal_account',
      type: IsarType.string,
    ),
    r'legal_cid': PropertySchema(
      id: 10,
      name: r'legal_cid',
      type: IsarType.string,
    ),
    r'org_code': PropertySchema(
      id: 11,
      name: r'org_code',
      type: IsarType.string,
    ),
    r'parent_cid': PropertySchema(
      id: 12,
      name: r'parent_cid',
      type: IsarType.string,
    ),
    r'province_code': PropertySchema(
      id: 13,
      name: r'province_code',
      type: IsarType.string,
    ),
    r'short_name': PropertySchema(
      id: 14,
      name: r'short_name',
      type: IsarType.string,
    ),
    r'town_code': PropertySchema(
      id: 15,
      name: r'town_code',
      type: IsarType.string,
    ),
  },

  estimateSize: _entityEstimateSize,
  serialize: _entitySerialize,
  deserialize: _entityDeserialize,
  deserializeProp: _entityDeserializeProp,
  idName: r'id',
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
    r'province_code': IndexSchema(
      id: -1375055343093744486,
      name: r'province_code',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'province_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'city_code': IndexSchema(
      id: -2665912997744194428,
      name: r'city_code',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'city_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'org_code': IndexSchema(
      id: 3833321281016999750,
      name: r'org_code',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'org_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _entityGetId,
  getLinks: _entityGetLinks,
  attach: _entityAttach,
  version: '3.3.2',
);

int _entityEstimateSize(
  Entity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountNames.length * 3;
  {
    for (var i = 0; i < object.accountNames.length; i++) {
      final value = object.accountNames[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.cidState.length * 3;
  bytesCount += 3 + object.cityCode.length * 3;
  {
    final value = object.familyName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.fullName.length * 3;
  {
    final value = object.givenName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.legalAccount;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.legalCid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.orgCode.length * 3;
  {
    final value = object.parentCid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.provinceCode.length * 3;
  {
    final value = object.shortName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.townCode.length * 3;
  return bytesCount;
}

void _entitySerialize(
  Entity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.accountCount);
  writer.writeStringList(offsets[1], object.accountNames);
  writer.writeString(offsets[2], object.cidNumber);
  writer.writeString(offsets[3], object.cidState);
  writer.writeString(offsets[4], object.cityCode);
  writer.writeString(offsets[5], object.familyName);
  writer.writeString(offsets[6], object.fullName);
  writer.writeString(offsets[7], object.givenName);
  writer.writeBool(offsets[8], object.isLegal);
  writer.writeString(offsets[9], object.legalAccount);
  writer.writeString(offsets[10], object.legalCid);
  writer.writeString(offsets[11], object.orgCode);
  writer.writeString(offsets[12], object.parentCid);
  writer.writeString(offsets[13], object.provinceCode);
  writer.writeString(offsets[14], object.shortName);
  writer.writeString(offsets[15], object.townCode);
}

Entity _entityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Entity();
  object.accountCount = reader.readLong(offsets[0]);
  object.accountNames = reader.readStringList(offsets[1]) ?? [];
  object.cidNumber = reader.readString(offsets[2]);
  object.cidState = reader.readString(offsets[3]);
  object.cityCode = reader.readString(offsets[4]);
  object.familyName = reader.readStringOrNull(offsets[5]);
  object.fullName = reader.readString(offsets[6]);
  object.givenName = reader.readStringOrNull(offsets[7]);
  object.rowId = id;
  object.isLegal = reader.readBoolOrNull(offsets[8]);
  object.legalAccount = reader.readStringOrNull(offsets[9]);
  object.legalCid = reader.readStringOrNull(offsets[10]);
  object.orgCode = reader.readString(offsets[11]);
  object.parentCid = reader.readStringOrNull(offsets[12]);
  object.provinceCode = reader.readString(offsets[13]);
  object.shortName = reader.readStringOrNull(offsets[14]);
  object.townCode = reader.readString(offsets[15]);
  return object;
}

P _entityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringList(offset) ?? []) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readBoolOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _entityGetId(Entity object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _entityGetLinks(Entity object) {
  return [];
}

void _entityAttach(IsarCollection<dynamic> col, Id id, Entity object) {
  object.rowId = id;
}

extension EntityByIndex on IsarCollection<Entity> {
  Future<Entity?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cid_number', [cidNumber]);
  }

  Entity? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cid_number', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cid_number', [cidNumber]);
  }

  Future<List<Entity?>> getAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cid_number', values);
  }

  List<Entity?> getAllByCidNumberSync(List<String> cidNumberValues) {
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

  Future<Id> putByCidNumber(Entity object) {
    return putByIndex(r'cid_number', object);
  }

  Id putByCidNumberSync(Entity object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<Entity> objects) {
    return putAllByIndex(r'cid_number', objects);
  }

  List<Id> putAllByCidNumberSync(
    List<Entity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number', objects, saveLinks: saveLinks);
  }
}

extension EntityQueryWhereSort on QueryBuilder<Entity, Entity, QWhere> {
  QueryBuilder<Entity, Entity, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EntityQueryWhere on QueryBuilder<Entity, Entity, QWhereClause> {
  QueryBuilder<Entity, Entity, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Entity, Entity, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Entity, Entity, QAfterWhereClause> cidNumberEqualTo(
    String cidNumber,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cid_number', value: [cidNumber]),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> cidNumberNotEqualTo(
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

  QueryBuilder<Entity, Entity, QAfterWhereClause> provinceCodeEqualTo(
    String provinceCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'province_code',
          value: [provinceCode],
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> provinceCodeNotEqualTo(
    String provinceCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> cityCodeEqualTo(
    String cityCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'city_code', value: [cityCode]),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> cityCodeNotEqualTo(
    String cityCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'city_code',
                lower: [],
                upper: [cityCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'city_code',
                lower: [cityCode],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'city_code',
                lower: [cityCode],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'city_code',
                lower: [],
                upper: [cityCode],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> orgCodeEqualTo(
    String orgCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'org_code', value: [orgCode]),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterWhereClause> orgCodeNotEqualTo(
    String orgCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'org_code',
                lower: [],
                upper: [orgCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'org_code',
                lower: [orgCode],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'org_code',
                lower: [orgCode],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'org_code',
                lower: [],
                upper: [orgCode],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension EntityQueryFilter on QueryBuilder<Entity, Entity, QFilterCondition> {
  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_count', value: value),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_count',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_names',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_names',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_names',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_names', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_names', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountNamesLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'account_names', length, true, length, true);
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountNamesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'account_names', 0, true, 0, true);
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountNamesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'account_names', 0, false, 999999, true);
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'account_names', 0, true, length, include);
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition>
  accountNamesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'account_names', length, include, 999999, true);
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> accountNamesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'account_names',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberEqualTo(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberGreaterThan(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberLessThan(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberBetween(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberStartsWith(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberEndsWith(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberContains(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberMatches(
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_number', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cid_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cid_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cid_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cid_state', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cidStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cid_state', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'city_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'city_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'city_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'city_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> cityCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'city_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'family_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'family_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'family_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'family_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'family_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'family_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> familyNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'family_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'full_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'full_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'full_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'full_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> fullNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'full_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'given_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'given_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'given_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'given_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'given_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'given_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> givenNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'given_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> isLegalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'is_legal'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> isLegalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'is_legal'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> isLegalEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'is_legal', value: value),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'legal_account'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'legal_account'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'legal_account',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'legal_account',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'legal_account',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'legal_account', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalAccountIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'legal_account', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'legal_cid'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'legal_cid'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'legal_cid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'legal_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'legal_cid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'legal_cid', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> legalCidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'legal_cid', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'org_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'org_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'org_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'org_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> orgCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'org_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parent_cid'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parent_cid'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parent_cid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'parent_cid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'parent_cid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'parent_cid', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> parentCidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'parent_cid', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'province_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'province_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'province_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> provinceCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'province_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'short_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'short_name'),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'short_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'short_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'short_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'short_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> shortNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'short_name', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'town_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'town_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'town_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'town_code', value: ''),
      );
    });
  }

  QueryBuilder<Entity, Entity, QAfterFilterCondition> townCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'town_code', value: ''),
      );
    });
  }
}

extension EntityQueryObject on QueryBuilder<Entity, Entity, QFilterCondition> {}

extension EntityQueryLinks on QueryBuilder<Entity, Entity, QFilterCondition> {}

extension EntityQuerySortBy on QueryBuilder<Entity, Entity, QSortBy> {
  QueryBuilder<Entity, Entity, QAfterSortBy> sortByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_count', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByAccountCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_count', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCidState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_state', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCidStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_state', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByFamilyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'family_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByFamilyNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'family_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByFullName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'full_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByFullNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'full_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByGivenName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'given_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByGivenNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'given_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByIsLegal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_legal', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByIsLegalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_legal', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByLegalAccount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_account', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByLegalAccountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_account', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByLegalCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_cid', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByLegalCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_cid', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByOrgCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'org_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByOrgCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'org_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByParentCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parent_cid', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByParentCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parent_cid', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByShortName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'short_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByShortNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'short_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> sortByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.desc);
    });
  }
}

extension EntityQuerySortThenBy on QueryBuilder<Entity, Entity, QSortThenBy> {
  QueryBuilder<Entity, Entity, QAfterSortBy> thenByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_count', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByAccountCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_count', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_number', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCidState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_state', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCidStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cid_state', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'city_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByFamilyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'family_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByFamilyNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'family_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByFullName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'full_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByFullNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'full_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByGivenName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'given_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByGivenNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'given_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByIsLegal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_legal', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByIsLegalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'is_legal', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByLegalAccount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_account', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByLegalAccountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_account', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByLegalCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_cid', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByLegalCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legal_cid', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByOrgCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'org_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByOrgCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'org_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByParentCid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parent_cid', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByParentCidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parent_cid', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByShortName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'short_name', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByShortNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'short_name', Sort.desc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'town_code', Sort.desc);
    });
  }
}

extension EntityQueryWhereDistinct on QueryBuilder<Entity, Entity, QDistinct> {
  QueryBuilder<Entity, Entity, QDistinct> distinctByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_count');
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByAccountNames() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_names');
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByCidState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByCityCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'city_code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByFamilyName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'family_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByFullName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'full_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByGivenName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'given_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByIsLegal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'is_legal');
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByLegalAccount({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'legal_account',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByLegalCid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'legal_cid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByOrgCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'org_code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByParentCid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parent_cid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByProvinceCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'province_code',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByShortName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'short_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entity, Entity, QDistinct> distinctByTownCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'town_code', caseSensitive: caseSensitive);
    });
  }
}

extension EntityQueryProperty on QueryBuilder<Entity, Entity, QQueryProperty> {
  QueryBuilder<Entity, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Entity, int, QQueryOperations> accountCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_count');
    });
  }

  QueryBuilder<Entity, List<String>, QQueryOperations> accountNamesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_names');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> cidStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_state');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> cityCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'city_code');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> familyNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'family_name');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> fullNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'full_name');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> givenNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'given_name');
    });
  }

  QueryBuilder<Entity, bool?, QQueryOperations> isLegalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'is_legal');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> legalAccountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'legal_account');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> legalCidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'legal_cid');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> orgCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'org_code');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> parentCidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parent_cid');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> provinceCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'province_code');
    });
  }

  QueryBuilder<Entity, String?, QQueryOperations> shortNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'short_name');
    });
  }

  QueryBuilder<Entity, String, QQueryOperations> townCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'town_code');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVersionCollection on Isar {
  IsarCollection<Version> get versions => this.collection();
}

const VersionSchema = CollectionSchema(
  name: r'sync',
  id: 5087843069960744560,
  properties: {
    r'data_kind': PropertySchema(
      id: 0,
      name: r'data_kind',
      type: IsarType.string,
    ),
    r'global_version': PropertySchema(
      id: 1,
      name: r'global_version',
      type: IsarType.string,
    ),
    r'province_data': PropertySchema(
      id: 2,
      name: r'province_data',
      type: IsarType.string,
    ),
  },

  estimateSize: _versionEstimateSize,
  serialize: _versionSerialize,
  deserialize: _versionDeserialize,
  deserializeProp: _versionDeserializeProp,
  idName: r'id',
  indexes: {
    r'data_kind': IndexSchema(
      id: 6181061561542844749,
      name: r'data_kind',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'data_kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _versionGetId,
  getLinks: _versionGetLinks,
  attach: _versionAttach,
  version: '3.3.2',
);

int _versionEstimateSize(
  Version object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dataKind.length * 3;
  {
    final value = object.globalVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.provinceData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _versionSerialize(
  Version object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.dataKind);
  writer.writeString(offsets[1], object.globalVersion);
  writer.writeString(offsets[2], object.provinceData);
}

Version _versionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Version();
  object.dataKind = reader.readString(offsets[0]);
  object.globalVersion = reader.readStringOrNull(offsets[1]);
  object.rowId = id;
  object.provinceData = reader.readStringOrNull(offsets[2]);
  return object;
}

P _versionDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _versionGetId(Version object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _versionGetLinks(Version object) {
  return [];
}

void _versionAttach(IsarCollection<dynamic> col, Id id, Version object) {
  object.rowId = id;
}

extension VersionByIndex on IsarCollection<Version> {
  Future<Version?> getByDataKind(String dataKind) {
    return getByIndex(r'data_kind', [dataKind]);
  }

  Version? getByDataKindSync(String dataKind) {
    return getByIndexSync(r'data_kind', [dataKind]);
  }

  Future<bool> deleteByDataKind(String dataKind) {
    return deleteByIndex(r'data_kind', [dataKind]);
  }

  bool deleteByDataKindSync(String dataKind) {
    return deleteByIndexSync(r'data_kind', [dataKind]);
  }

  Future<List<Version?>> getAllByDataKind(List<String> dataKindValues) {
    final values = dataKindValues.map((e) => [e]).toList();
    return getAllByIndex(r'data_kind', values);
  }

  List<Version?> getAllByDataKindSync(List<String> dataKindValues) {
    final values = dataKindValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'data_kind', values);
  }

  Future<int> deleteAllByDataKind(List<String> dataKindValues) {
    final values = dataKindValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'data_kind', values);
  }

  int deleteAllByDataKindSync(List<String> dataKindValues) {
    final values = dataKindValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'data_kind', values);
  }

  Future<Id> putByDataKind(Version object) {
    return putByIndex(r'data_kind', object);
  }

  Id putByDataKindSync(Version object, {bool saveLinks = true}) {
    return putByIndexSync(r'data_kind', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDataKind(List<Version> objects) {
    return putAllByIndex(r'data_kind', objects);
  }

  List<Id> putAllByDataKindSync(
    List<Version> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'data_kind', objects, saveLinks: saveLinks);
  }
}

extension VersionQueryWhereSort on QueryBuilder<Version, Version, QWhere> {
  QueryBuilder<Version, Version, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension VersionQueryWhere on QueryBuilder<Version, Version, QWhereClause> {
  QueryBuilder<Version, Version, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Version, Version, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Version, Version, QAfterWhereClause> dataKindEqualTo(
    String dataKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'data_kind', value: [dataKind]),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterWhereClause> dataKindNotEqualTo(
    String dataKind,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'data_kind',
                lower: [],
                upper: [dataKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'data_kind',
                lower: [dataKind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'data_kind',
                lower: [dataKind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'data_kind',
                lower: [],
                upper: [dataKind],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension VersionQueryFilter
    on QueryBuilder<Version, Version, QFilterCondition> {
  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'data_kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'data_kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'data_kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data_kind', value: ''),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> dataKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data_kind', value: ''),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'global_version'),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition>
  globalVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'global_version'),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition>
  globalVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'global_version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'global_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'global_version',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> globalVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'global_version', value: ''),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition>
  globalVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'global_version', value: ''),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'province_data'),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition>
  provinceDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'province_data'),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'province_data',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'province_data',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'province_data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition> provinceDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'province_data', value: ''),
      );
    });
  }

  QueryBuilder<Version, Version, QAfterFilterCondition>
  provinceDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'province_data', value: ''),
      );
    });
  }
}

extension VersionQueryObject
    on QueryBuilder<Version, Version, QFilterCondition> {}

extension VersionQueryLinks
    on QueryBuilder<Version, Version, QFilterCondition> {}

extension VersionQuerySortBy on QueryBuilder<Version, Version, QSortBy> {
  QueryBuilder<Version, Version, QAfterSortBy> sortByDataKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_kind', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> sortByDataKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_kind', Sort.desc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> sortByGlobalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'global_version', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> sortByGlobalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'global_version', Sort.desc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> sortByProvinceData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_data', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> sortByProvinceDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_data', Sort.desc);
    });
  }
}

extension VersionQuerySortThenBy
    on QueryBuilder<Version, Version, QSortThenBy> {
  QueryBuilder<Version, Version, QAfterSortBy> thenByDataKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_kind', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByDataKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_kind', Sort.desc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByGlobalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'global_version', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByGlobalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'global_version', Sort.desc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByProvinceData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_data', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByProvinceDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_data', Sort.desc);
    });
  }
}

extension VersionQueryWhereDistinct
    on QueryBuilder<Version, Version, QDistinct> {
  QueryBuilder<Version, Version, QDistinct> distinctByDataKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data_kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Version, Version, QDistinct> distinctByGlobalVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'global_version',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Version, Version, QDistinct> distinctByProvinceData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'province_data',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension VersionQueryProperty
    on QueryBuilder<Version, Version, QQueryProperty> {
  QueryBuilder<Version, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Version, String, QQueryOperations> dataKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data_kind');
    });
  }

  QueryBuilder<Version, String?, QQueryOperations> globalVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'global_version');
    });
  }

  QueryBuilder<Version, String?, QQueryOperations> provinceDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'province_data');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCatalogCollection on Isar {
  IsarCollection<Catalog> get catalogs => this.collection();
}

const CatalogSchema = CollectionSchema(
  name: r'catalog',
  id: -4681382007173525892,
  properties: {
    r'province_codes': PropertySchema(
      id: 0,
      name: r'province_codes',
      type: IsarType.stringList,
    ),
  },

  estimateSize: _catalogEstimateSize,
  serialize: _catalogSerialize,
  deserialize: _catalogDeserialize,
  deserializeProp: _catalogDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _catalogGetId,
  getLinks: _catalogGetLinks,
  attach: _catalogAttach,
  version: '3.3.2',
);

int _catalogEstimateSize(
  Catalog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.provinceCodes.length * 3;
  {
    for (var i = 0; i < object.provinceCodes.length; i++) {
      final value = object.provinceCodes[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _catalogSerialize(
  Catalog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.provinceCodes);
}

Catalog _catalogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Catalog();
  object.rowId = id;
  object.provinceCodes = reader.readStringList(offsets[0]) ?? [];
  return object;
}

P _catalogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _catalogGetId(Catalog object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _catalogGetLinks(Catalog object) {
  return [];
}

void _catalogAttach(IsarCollection<dynamic> col, Id id, Catalog object) {
  object.rowId = id;
}

extension CatalogQueryWhereSort on QueryBuilder<Catalog, Catalog, QWhere> {
  QueryBuilder<Catalog, Catalog, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CatalogQueryWhere on QueryBuilder<Catalog, Catalog, QWhereClause> {
  QueryBuilder<Catalog, Catalog, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterWhereClause> rowIdNotEqualTo(Id rowId) {
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

  QueryBuilder<Catalog, Catalog, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterWhereClause> rowIdBetween(
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

extension CatalogQueryFilter
    on QueryBuilder<Catalog, Catalog, QFilterCondition> {
  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'province_codes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'province_codes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'province_codes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'province_codes', value: ''),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'province_codes', value: ''),
      );
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'province_codes', length, true, length, true);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> provinceCodesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'province_codes', 0, true, 0, true);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'province_codes', 0, false, 999999, true);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'province_codes', 0, true, length, include);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'province_codes', length, include, 999999, true);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition>
  provinceCodesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'province_codes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension CatalogQueryObject
    on QueryBuilder<Catalog, Catalog, QFilterCondition> {}

extension CatalogQueryLinks
    on QueryBuilder<Catalog, Catalog, QFilterCondition> {}

extension CatalogQuerySortBy on QueryBuilder<Catalog, Catalog, QSortBy> {}

extension CatalogQuerySortThenBy
    on QueryBuilder<Catalog, Catalog, QSortThenBy> {
  QueryBuilder<Catalog, Catalog, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension CatalogQueryWhereDistinct
    on QueryBuilder<Catalog, Catalog, QDistinct> {
  QueryBuilder<Catalog, Catalog, QDistinct> distinctByProvinceCodes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'province_codes');
    });
  }
}

extension CatalogQueryProperty
    on QueryBuilder<Catalog, Catalog, QQueryProperty> {
  QueryBuilder<Catalog, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Catalog, List<String>, QQueryOperations>
  provinceCodesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'province_codes');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProvinceCollection on Isar {
  IsarCollection<Province> get provinces => this.collection();
}

const ProvinceSchema = CollectionSchema(
  name: r'province',
  id: -6035047385865569949,
  properties: {
    r'data_version': PropertySchema(
      id: 0,
      name: r'data_version',
      type: IsarType.string,
    ),
    r'province_code': PropertySchema(
      id: 1,
      name: r'province_code',
      type: IsarType.string,
    ),
  },

  estimateSize: _provinceEstimateSize,
  serialize: _provinceSerialize,
  deserialize: _provinceDeserialize,
  deserializeProp: _provinceDeserializeProp,
  idName: r'id',
  indexes: {
    r'province_code': IndexSchema(
      id: -1375055343093744486,
      name: r'province_code',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'province_code',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _provinceGetId,
  getLinks: _provinceGetLinks,
  attach: _provinceAttach,
  version: '3.3.2',
);

int _provinceEstimateSize(
  Province object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dataVersion.length * 3;
  bytesCount += 3 + object.provinceCode.length * 3;
  return bytesCount;
}

void _provinceSerialize(
  Province object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.dataVersion);
  writer.writeString(offsets[1], object.provinceCode);
}

Province _provinceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Province();
  object.dataVersion = reader.readString(offsets[0]);
  object.rowId = id;
  object.provinceCode = reader.readString(offsets[1]);
  return object;
}

P _provinceDeserializeProp<P>(
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

Id _provinceGetId(Province object) {
  return object.rowId;
}

List<IsarLinkBase<dynamic>> _provinceGetLinks(Province object) {
  return [];
}

void _provinceAttach(IsarCollection<dynamic> col, Id id, Province object) {
  object.rowId = id;
}

extension ProvinceByIndex on IsarCollection<Province> {
  Future<Province?> getByProvinceCode(String provinceCode) {
    return getByIndex(r'province_code', [provinceCode]);
  }

  Province? getByProvinceCodeSync(String provinceCode) {
    return getByIndexSync(r'province_code', [provinceCode]);
  }

  Future<bool> deleteByProvinceCode(String provinceCode) {
    return deleteByIndex(r'province_code', [provinceCode]);
  }

  bool deleteByProvinceCodeSync(String provinceCode) {
    return deleteByIndexSync(r'province_code', [provinceCode]);
  }

  Future<List<Province?>> getAllByProvinceCode(
    List<String> provinceCodeValues,
  ) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return getAllByIndex(r'province_code', values);
  }

  List<Province?> getAllByProvinceCodeSync(List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'province_code', values);
  }

  Future<int> deleteAllByProvinceCode(List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'province_code', values);
  }

  int deleteAllByProvinceCodeSync(List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'province_code', values);
  }

  Future<Id> putByProvinceCode(Province object) {
    return putByIndex(r'province_code', object);
  }

  Id putByProvinceCodeSync(Province object, {bool saveLinks = true}) {
    return putByIndexSync(r'province_code', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProvinceCode(List<Province> objects) {
    return putAllByIndex(r'province_code', objects);
  }

  List<Id> putAllByProvinceCodeSync(
    List<Province> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'province_code', objects, saveLinks: saveLinks);
  }
}

extension ProvinceQueryWhereSort on QueryBuilder<Province, Province, QWhere> {
  QueryBuilder<Province, Province, QAfterWhere> anyRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProvinceQueryWhere on QueryBuilder<Province, Province, QWhereClause> {
  QueryBuilder<Province, Province, QAfterWhereClause> rowIdEqualTo(Id rowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: rowId, upper: rowId),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterWhereClause> rowIdNotEqualTo(
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

  QueryBuilder<Province, Province, QAfterWhereClause> rowIdGreaterThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: rowId, includeLower: include),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterWhereClause> rowIdLessThan(
    Id rowId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: rowId, includeUpper: include),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterWhereClause> rowIdBetween(
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

  QueryBuilder<Province, Province, QAfterWhereClause> provinceCodeEqualTo(
    String provinceCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'province_code',
          value: [provinceCode],
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterWhereClause> provinceCodeNotEqualTo(
    String provinceCode,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [provinceCode],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'province_code',
                lower: [],
                upper: [provinceCode],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ProvinceQueryFilter
    on QueryBuilder<Province, Province, QFilterCondition> {
  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  dataVersionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'data_version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'data_version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'data_version',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> dataVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data_version', value: ''),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  dataVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data_version', value: ''),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> rowIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> rowIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> rowIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  provinceCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'province_code',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  provinceCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'province_code',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition> provinceCodeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'province_code',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  provinceCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'province_code', value: ''),
      );
    });
  }

  QueryBuilder<Province, Province, QAfterFilterCondition>
  provinceCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'province_code', value: ''),
      );
    });
  }
}

extension ProvinceQueryObject
    on QueryBuilder<Province, Province, QFilterCondition> {}

extension ProvinceQueryLinks
    on QueryBuilder<Province, Province, QFilterCondition> {}

extension ProvinceQuerySortBy on QueryBuilder<Province, Province, QSortBy> {
  QueryBuilder<Province, Province, QAfterSortBy> sortByDataVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_version', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> sortByDataVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_version', Sort.desc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> sortByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> sortByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }
}

extension ProvinceQuerySortThenBy
    on QueryBuilder<Province, Province, QSortThenBy> {
  QueryBuilder<Province, Province, QAfterSortBy> thenByDataVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_version', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByDataVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data_version', Sort.desc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'province_code', Sort.desc);
    });
  }
}

extension ProvinceQueryWhereDistinct
    on QueryBuilder<Province, Province, QDistinct> {
  QueryBuilder<Province, Province, QDistinct> distinctByDataVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data_version', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Province, Province, QDistinct> distinctByProvinceCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'province_code',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension ProvinceQueryProperty
    on QueryBuilder<Province, Province, QQueryProperty> {
  QueryBuilder<Province, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Province, String, QQueryOperations> dataVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data_version');
    });
  }

  QueryBuilder<Province, String, QQueryOperations> provinceCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'province_code');
    });
  }
}

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
    r'request': PropertySchema(id: 4, name: r'request', type: IsarType.string),
    r'response': PropertySchema(
      id: 5,
      name: r'response',
      type: IsarType.string,
    ),
    r'state': PropertySchema(id: 6, name: r'state', type: IsarType.string),
  },

  estimateSize: _editEstimateSize,
  serialize: _editSerialize,
  deserialize: _editDeserialize,
  deserializeProp: _editDeserializeProp,
  idName: r'id',
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
  bytesCount += 3 + object.requestData.length * 3;
  {
    final value = object.responseData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.jobState.length * 3;
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
  writer.writeString(offsets[4], object.requestData);
  writer.writeString(offsets[5], object.responseData);
  writer.writeString(offsets[6], object.jobState);
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
  object.rowId = id;
  object.requestData = reader.readString(offsets[4]);
  object.responseData = reader.readStringOrNull(offsets[5]);
  object.jobState = reader.readString(offsets[6]);
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
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
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

  QueryBuilder<Edit, Edit, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
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
          property: r'request',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'request', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> requestDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'request', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'response'),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'response'),
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
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
          property: r'response',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'response', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> responseDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'response', value: ''),
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: ''),
      );
    });
  }

  QueryBuilder<Edit, Edit, QAfterFilterCondition> jobStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state', value: ''),
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

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByRequestData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByRequestDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByResponseData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByResponseDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> sortByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRequestData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByRequestDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'request', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByResponseData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByResponseDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'response', Sort.desc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByJobState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Edit, Edit, QAfterSortBy> thenByJobStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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

  QueryBuilder<Edit, Edit, QDistinct> distinctByRequestData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'request', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByResponseData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'response', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Edit, Edit, QDistinct> distinctByJobState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
    });
  }
}

extension EditQueryProperty on QueryBuilder<Edit, Edit, QQueryProperty> {
  QueryBuilder<Edit, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
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

  QueryBuilder<Edit, String, QQueryOperations> requestDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'request');
    });
  }

  QueryBuilder<Edit, String?, QQueryOperations> responseDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'response');
    });
  }

  QueryBuilder<Edit, String, QQueryOperations> jobStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
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
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
  },

  estimateSize: _profileEstimateSize,
  serialize: _profileSerialize,
  deserialize: _profileDeserialize,
  deserializeProp: _profileDeserializeProp,
  idName: r'id',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> profileDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition>
  profileDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Profile, Profile, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> sortByProfileDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByProfileDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Profile, Profile, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }
}

extension ProfileQueryProperty
    on QueryBuilder<Profile, Profile, QQueryProperty> {
  QueryBuilder<Profile, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Profile, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Profile, String, QQueryOperations> profileDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
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
  idName: r'id',
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
  object.rowId = id;
  object.mediaBytes = reader.readByteList(offsets[2]) ?? [];
  object.mediaRole = reader.readString(offsets[3]);
  object.objectKey = reader.readString(offsets[4]);
  object.profileAt = reader.readLong(offsets[5]);
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ProfileMedia, ProfileMedia, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'data': PropertySchema(id: 2, name: r'data', type: IsarType.string),
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
  idName: r'id',
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
        const FilterCondition.isNull(property: r'data'),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'data'),
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition>
  identityDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Identity, Identity, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> sortByIdentityDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByIdentityDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Identity, Identity, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
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
      return query.addPropertyName(r'id');
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
      return query.addPropertyName(r'data');
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
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
    r'kind': PropertySchema(id: 2, name: r'kind', type: IsarType.string),
  },

  estimateSize: _contactEstimateSize,
  serialize: _contactSerialize,
  deserialize: _contactDeserialize,
  deserializeProp: _contactDeserializeProp,
  idName: r'id',
  indexes: {
    r'cid_number_kind': IndexSchema(
      id: 1590166177890203393,
      name: r'cid_number_kind',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'kind',
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
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.stateKind.length * 3;
  return bytesCount;
}

void _contactSerialize(
  Contact object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.bodyData);
  writer.writeString(offsets[2], object.stateKind);
}

Contact _contactDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Contact();
  object.cidNumber = reader.readString(offsets[0]);
  object.bodyData = reader.readString(offsets[1]);
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
    return getByIndex(r'cid_number_kind', [cidNumber, stateKind]);
  }

  Contact? getByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return getByIndexSync(r'cid_number_kind', [cidNumber, stateKind]);
  }

  Future<bool> deleteByCidNumberStateKind(String cidNumber, String stateKind) {
    return deleteByIndex(r'cid_number_kind', [cidNumber, stateKind]);
  }

  bool deleteByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return deleteByIndexSync(r'cid_number_kind', [cidNumber, stateKind]);
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

    return getAllByIndex(r'cid_number_kind', values);
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

    return getAllByIndexSync(r'cid_number_kind', values);
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

    return deleteAllByIndex(r'cid_number_kind', values);
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

    return deleteAllByIndexSync(r'cid_number_kind', values);
  }

  Future<Id> putByCidNumberStateKind(Contact object) {
    return putByIndex(r'cid_number_kind', object);
  }

  Id putByCidNumberStateKindSync(Contact object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_kind', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberStateKind(List<Contact> objects) {
    return putAllByIndex(r'cid_number_kind', objects);
  }

  List<Id> putAllByCidNumberStateKindSync(
    List<Contact> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number_kind', objects, saveLinks: saveLinks);
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
          indexName: r'cid_number_kind',
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
                indexName: r'cid_number_kind',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
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
          indexName: r'cid_number_kind',
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
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                upper: [cidNumber, stateKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
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

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> stateKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }
}

extension ContactQueryObject
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQueryLinks
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQuerySortBy on QueryBuilder<Contact, Contact, QSortBy> {
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

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }
}

extension ContactQuerySortThenBy
    on QueryBuilder<Contact, Contact, QSortThenBy> {
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

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }
}

extension ContactQueryWhereDistinct
    on QueryBuilder<Contact, Contact, QDistinct> {
  QueryBuilder<Contact, Contact, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByStateKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }
}

extension ContactQueryProperty
    on QueryBuilder<Contact, Contact, QQueryProperty> {
  QueryBuilder<Contact, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Contact, String, QQueryOperations> stateKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
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
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
    r'pending': PropertySchema(id: 2, name: r'pending', type: IsarType.string),
  },

  estimateSize: _noticeEstimateSize,
  serialize: _noticeSerialize,
  deserialize: _noticeDeserialize,
  deserializeProp: _noticeDeserializeProp,
  idName: r'id',
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
  bytesCount += 3 + object.stateData.length * 3;
  {
    final value = object.pendingData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _noticeSerialize(
  Notice object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.stateData);
  writer.writeString(offsets[2], object.pendingData);
}

Notice _noticeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Notice();
  object.cidNumber = reader.readString(offsets[0]);
  object.stateData = reader.readString(offsets[1]);
  object.rowId = id;
  object.pendingData = reader.readStringOrNull(offsets[2]);
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
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
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

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> stateDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pending'),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pending'),
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
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
          property: r'pending',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pending', value: ''),
      );
    });
  }

  QueryBuilder<Notice, Notice, QAfterFilterCondition> pendingDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pending', value: ''),
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

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByStateData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByStateDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> sortByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending', Sort.desc);
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

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByStateData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByStateDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByPendingData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending', Sort.asc);
    });
  }

  QueryBuilder<Notice, Notice, QAfterSortBy> thenByPendingDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pending', Sort.desc);
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

  QueryBuilder<Notice, Notice, QDistinct> distinctByStateData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Notice, Notice, QDistinct> distinctByPendingData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pending', caseSensitive: caseSensitive);
    });
  }
}

extension NoticeQueryProperty on QueryBuilder<Notice, Notice, QQueryProperty> {
  QueryBuilder<Notice, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Notice, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Notice, String, QQueryOperations> stateDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Notice, String?, QQueryOperations> pendingDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pending');
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
    r'square_tab_order': PropertySchema(
      id: 4,
      name: r'square_tab_order',
      type: IsarType.stringList,
    ),
  },

  estimateSize: _settingEstimateSize,
  serialize: _settingSerialize,
  deserialize: _settingDeserialize,
  deserializeProp: _settingDeserializeProp,
  idName: r'id',
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
  bytesCount += 3 + object.squareTabOrder.length * 3;
  {
    for (var i = 0; i < object.squareTabOrder.length; i++) {
      final value = object.squareTabOrder[i];
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
  writer.writeStringList(offsets[4], object.squareTabOrder);
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
  object.squareTabOrder = reader.readStringList(offsets[4]) ?? [];
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
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
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
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'square_tab_order',
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
  squareTabOrderElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'square_tab_order',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'square_tab_order',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'square_tab_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'square_tab_order', value: ''),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'square_tab_order', length, true, length, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'square_tab_order', 0, true, 0, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'square_tab_order', 0, false, 999999, true);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'square_tab_order', 0, true, length, include);
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'square_tab_order',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
  squareTabOrderLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'square_tab_order',
        lower,
        includeLower,
        upper,
        includeUpper,
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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

  QueryBuilder<Setting, Setting, QDistinct> distinctBySquareTabOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'square_tab_order');
    });
  }
}

extension SettingQueryProperty
    on QueryBuilder<Setting, Setting, QQueryProperty> {
  QueryBuilder<Setting, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
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

  QueryBuilder<Setting, List<String>, QQueryOperations>
  squareTabOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'square_tab_order');
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
  idName: r'id',
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
  object.rowId = id;
  object.peerCid = reader.readString(offsets[1]);
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

  QueryBuilder<Follow, Follow, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Follow, Follow, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
  },

  estimateSize: _balanceEstimateSize,
  serialize: _balanceSerialize,
  deserialize: _balanceDeserialize,
  deserializeProp: _balanceDeserializeProp,
  idName: r'id',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Balance, Balance, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Balance, Balance, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }
}

extension BalanceQueryProperty
    on QueryBuilder<Balance, Balance, QQueryProperty> {
  QueryBuilder<Balance, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Balance, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Balance, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
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
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
    r'state': PropertySchema(id: 2, name: r'state', type: IsarType.string),
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
  idName: r'id',
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
  object.rowId = id;
  object.groupState = reader.readStringOrNull(offsets[2]);
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
        const FilterCondition.isNull(property: r'data'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'data'),
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> detailDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'state'),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'state'),
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: ''),
      );
    });
  }

  QueryBuilder<Group, Group, QAfterFilterCondition> groupStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state', value: ''),
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByDetailDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByGroupState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> sortByGroupStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByDetailDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByGroupState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Group, Group, QAfterSortBy> thenByGroupStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Group, Group, QDistinct> distinctByGroupState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
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
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Group, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Group, String?, QQueryOperations> detailDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Group, String?, QQueryOperations> groupStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
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
  idName: r'id',
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
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Scan, Scan, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'data': PropertySchema(id: 0, name: r'data', type: IsarType.string),
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
  idName: r'id',
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
  object.rowId = id;
  object.proposalId = reader.readLong(offsets[1]);
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Summary, Summary, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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
}

extension SummaryQueryObject
    on QueryBuilder<Summary, Summary, QFilterCondition> {}

extension SummaryQueryLinks
    on QueryBuilder<Summary, Summary, QFilterCondition> {}

extension SummaryQuerySortBy on QueryBuilder<Summary, Summary, QSortBy> {
  QueryBuilder<Summary, Summary, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Summary, Summary, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
}

extension SummaryQueryWhereDistinct
    on QueryBuilder<Summary, Summary, QDistinct> {
  QueryBuilder<Summary, Summary, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
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
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Summary, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
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
  idName: r'id',
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
  object.rowId = id;
  object.proposalIds = reader.readLongList(offsets[1]) ?? [];
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

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ProposalList, ProposalList, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'data': PropertySchema(id: 0, name: r'data', type: IsarType.string),
    r'kind': PropertySchema(id: 1, name: r'kind', type: IsarType.string),
    r'proposal_id': PropertySchema(
      id: 2,
      name: r'proposal_id',
      type: IsarType.long,
    ),
  },

  estimateSize: _proposalEstimateSize,
  serialize: _proposalSerialize,
  deserialize: _proposalDeserialize,
  deserializeProp: _proposalDeserializeProp,
  idName: r'id',
  indexes: {
    r'kind_proposal_id': IndexSchema(
      id: -1114706425788016234,
      name: r'kind_proposal_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'kind',
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
  writer.writeString(offsets[1], object.proposalKind);
  writer.writeLong(offsets[2], object.proposalId);
}

Proposal _proposalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Proposal();
  object.bodyData = reader.readString(offsets[0]);
  object.rowId = id;
  object.proposalKind = reader.readString(offsets[1]);
  object.proposalId = reader.readLong(offsets[2]);
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
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
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
    return getByIndex(r'kind_proposal_id', [proposalKind, proposalId]);
  }

  Proposal? getByProposalKindProposalIdSync(
    String proposalKind,
    int proposalId,
  ) {
    return getByIndexSync(r'kind_proposal_id', [proposalKind, proposalId]);
  }

  Future<bool> deleteByProposalKindProposalId(
    String proposalKind,
    int proposalId,
  ) {
    return deleteByIndex(r'kind_proposal_id', [proposalKind, proposalId]);
  }

  bool deleteByProposalKindProposalIdSync(String proposalKind, int proposalId) {
    return deleteByIndexSync(r'kind_proposal_id', [proposalKind, proposalId]);
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

    return getAllByIndex(r'kind_proposal_id', values);
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

    return getAllByIndexSync(r'kind_proposal_id', values);
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

    return deleteAllByIndex(r'kind_proposal_id', values);
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

    return deleteAllByIndexSync(r'kind_proposal_id', values);
  }

  Future<Id> putByProposalKindProposalId(Proposal object) {
    return putByIndex(r'kind_proposal_id', object);
  }

  Id putByProposalKindProposalIdSync(Proposal object, {bool saveLinks = true}) {
    return putByIndexSync(r'kind_proposal_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProposalKindProposalId(List<Proposal> objects) {
    return putAllByIndex(r'kind_proposal_id', objects);
  }

  List<Id> putAllByProposalKindProposalIdSync(
    List<Proposal> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'kind_proposal_id',
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
          indexName: r'kind_proposal_id',
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
                indexName: r'kind_proposal_id',
                lower: [],
                upper: [proposalKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
                lower: [proposalKind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
                lower: [proposalKind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
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
          indexName: r'kind_proposal_id',
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
                indexName: r'kind_proposal_id',
                lower: [proposalKind],
                upper: [proposalKind, proposalId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
                lower: [proposalKind, proposalId],
                includeLower: false,
                upper: [proposalKind],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
                lower: [proposalKind, proposalId],
                includeLower: false,
                upper: [proposalKind],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind_proposal_id',
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
          indexName: r'kind_proposal_id',
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
          indexName: r'kind_proposal_id',
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
          indexName: r'kind_proposal_id',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterFilterCondition>
  proposalKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
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
}

extension ProposalQueryObject
    on QueryBuilder<Proposal, Proposal, QFilterCondition> {}

extension ProposalQueryLinks
    on QueryBuilder<Proposal, Proposal, QFilterCondition> {}

extension ProposalQuerySortBy on QueryBuilder<Proposal, Proposal, QSortBy> {
  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> sortByProposalKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
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
}

extension ProposalQuerySortThenBy
    on QueryBuilder<Proposal, Proposal, QSortThenBy> {
  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Proposal, Proposal, QAfterSortBy> thenByProposalKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
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
}

extension ProposalQueryWhereDistinct
    on QueryBuilder<Proposal, Proposal, QDistinct> {
  QueryBuilder<Proposal, Proposal, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Proposal, Proposal, QDistinct> distinctByProposalKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Proposal, Proposal, QDistinct> distinctByProposalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proposal_id');
    });
  }
}

extension ProposalQueryProperty
    on QueryBuilder<Proposal, Proposal, QQueryProperty> {
  QueryBuilder<Proposal, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Proposal, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Proposal, String, QQueryOperations> proposalKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<Proposal, int, QQueryOperations> proposalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proposal_id');
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
  idName: r'id',
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
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LawSnapshot, LawSnapshot, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'data': PropertySchema(id: 0, name: r'data', type: IsarType.string),
  },

  estimateSize: _adminEstimateSize,
  serialize: _adminSerialize,
  deserialize: _adminDeserialize,
  deserializeProp: _adminDeserializeProp,
  idName: r'id',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Admin, Admin, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }
}

extension AdminQuerySortThenBy on QueryBuilder<Admin, Admin, QSortThenBy> {
  QueryBuilder<Admin, Admin, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Admin, Admin, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension AdminQueryWhereDistinct on QueryBuilder<Admin, Admin, QDistinct> {
  QueryBuilder<Admin, Admin, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }
}

extension AdminQueryProperty on QueryBuilder<Admin, Admin, QQueryProperty> {
  QueryBuilder<Admin, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Admin, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
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
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
    r'kind': PropertySchema(id: 2, name: r'kind', type: IsarType.string),
  },

  estimateSize: _memberEstimateSize,
  serialize: _memberSerialize,
  deserialize: _memberDeserialize,
  deserializeProp: _memberDeserializeProp,
  idName: r'id',
  indexes: {
    r'cid_number_kind': IndexSchema(
      id: 1590166177890203393,
      name: r'cid_number_kind',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cid_number',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'kind',
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
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.bodyData.length * 3;
  bytesCount += 3 + object.stateKind.length * 3;
  return bytesCount;
}

void _memberSerialize(
  Member object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.bodyData);
  writer.writeString(offsets[2], object.stateKind);
}

Member _memberDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Member();
  object.cidNumber = reader.readString(offsets[0]);
  object.bodyData = reader.readString(offsets[1]);
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
    return getByIndex(r'cid_number_kind', [cidNumber, stateKind]);
  }

  Member? getByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return getByIndexSync(r'cid_number_kind', [cidNumber, stateKind]);
  }

  Future<bool> deleteByCidNumberStateKind(String cidNumber, String stateKind) {
    return deleteByIndex(r'cid_number_kind', [cidNumber, stateKind]);
  }

  bool deleteByCidNumberStateKindSync(String cidNumber, String stateKind) {
    return deleteByIndexSync(r'cid_number_kind', [cidNumber, stateKind]);
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

    return getAllByIndex(r'cid_number_kind', values);
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

    return getAllByIndexSync(r'cid_number_kind', values);
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

    return deleteAllByIndex(r'cid_number_kind', values);
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

    return deleteAllByIndexSync(r'cid_number_kind', values);
  }

  Future<Id> putByCidNumberStateKind(Member object) {
    return putByIndex(r'cid_number_kind', object);
  }

  Id putByCidNumberStateKindSync(Member object, {bool saveLinks = true}) {
    return putByIndexSync(r'cid_number_kind', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumberStateKind(List<Member> objects) {
    return putAllByIndex(r'cid_number_kind', objects);
  }

  List<Id> putAllByCidNumberStateKindSync(
    List<Member> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'cid_number_kind', objects, saveLinks: saveLinks);
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
          indexName: r'cid_number_kind',
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
                indexName: r'cid_number_kind',
                lower: [],
                upper: [cidNumber],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
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
          indexName: r'cid_number_kind',
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
                indexName: r'cid_number_kind',
                lower: [cidNumber],
                upper: [cidNumber, stateKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
                lower: [cidNumber, stateKind],
                includeLower: false,
                upper: [cidNumber],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cid_number_kind',
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

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<Member, Member, QAfterFilterCondition> stateKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }
}

extension MemberQueryObject on QueryBuilder<Member, Member, QFilterCondition> {}

extension MemberQueryLinks on QueryBuilder<Member, Member, QFilterCondition> {}

extension MemberQuerySortBy on QueryBuilder<Member, Member, QSortBy> {
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

  QueryBuilder<Member, Member, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> sortByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }
}

extension MemberQuerySortThenBy on QueryBuilder<Member, Member, QSortThenBy> {
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

  QueryBuilder<Member, Member, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByStateKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Member, Member, QAfterSortBy> thenByStateKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }
}

extension MemberQueryWhereDistinct on QueryBuilder<Member, Member, QDistinct> {
  QueryBuilder<Member, Member, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Member, Member, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Member, Member, QDistinct> distinctByStateKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }
}

extension MemberQueryProperty on QueryBuilder<Member, Member, QQueryProperty> {
  QueryBuilder<Member, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Member, String, QQueryOperations> stateKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
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
    r'cid_number': PropertySchema(
      id: 0,
      name: r'cid_number',
      type: IsarType.string,
    ),
    r'data': PropertySchema(id: 1, name: r'data', type: IsarType.string),
  },

  estimateSize: _creatorEstimateSize,
  serialize: _creatorSerialize,
  deserialize: _creatorDeserialize,
  deserializeProp: _creatorDeserializeProp,
  idName: r'id',
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
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.bodyData.length * 3;
  return bytesCount;
}

void _creatorSerialize(
  Creator object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.bodyData);
}

Creator _creatorDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Creator();
  object.cidNumber = reader.readString(offsets[0]);
  object.bodyData = reader.readString(offsets[1]);
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

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> bodyDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Creator, Creator, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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

  QueryBuilder<Creator, Creator, QAfterSortBy> sortByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> sortByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }
}

extension CreatorQuerySortThenBy
    on QueryBuilder<Creator, Creator, QSortThenBy> {
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

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByBodyData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByBodyDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Creator, Creator, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension CreatorQueryWhereDistinct
    on QueryBuilder<Creator, Creator, QDistinct> {
  QueryBuilder<Creator, Creator, QDistinct> distinctByCidNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cid_number', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Creator, Creator, QDistinct> distinctByBodyData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }
}

extension CreatorQueryProperty
    on QueryBuilder<Creator, Creator, QQueryProperty> {
  QueryBuilder<Creator, int, QQueryOperations> rowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Creator, String, QQueryOperations> cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cid_number');
    });
  }

  QueryBuilder<Creator, String, QQueryOperations> bodyDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
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
  idName: r'id',
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
  object.rowId = id;
  object.isFound = reader.readBool(offsets[5]);
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

  QueryBuilder<Account, Account, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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

  QueryBuilder<Account, Account, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Account, Account, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'created_at': PropertySchema(
      id: 1,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'data': PropertySchema(id: 2, name: r'data', type: IsarType.string),
    r'final_at': PropertySchema(id: 3, name: r'final_at', type: IsarType.long),
    r'kind': PropertySchema(id: 4, name: r'kind', type: IsarType.string),
    r'no_count': PropertySchema(id: 5, name: r'no_count', type: IsarType.long),
    r'proposal_id': PropertySchema(
      id: 6,
      name: r'proposal_id',
      type: IsarType.long,
    ),
    r'state': PropertySchema(id: 7, name: r'state', type: IsarType.string),
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
  idName: r'id',
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
    r'kind': IndexSchema(
      id: 1484550194077596484,
      name: r'kind',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'kind',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'state': IndexSchema(
      id: 7917036384617311412,
      name: r'state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'state',
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
  {
    final value = object.snapshotData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.actionKind.length * 3;
  bytesCount += 3 + object.proposalState.length * 3;
  return bytesCount;
}

void _actionSerialize(
  Action object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.snapshotData);
  writer.writeLong(offsets[3], object.finalAt);
  writer.writeString(offsets[4], object.actionKind);
  writer.writeLong(offsets[5], object.noCount);
  writer.writeLong(offsets[6], object.proposalId);
  writer.writeString(offsets[7], object.proposalState);
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
  object.createdAt = reader.readLong(offsets[1]);
  object.snapshotData = reader.readStringOrNull(offsets[2]);
  object.finalAt = reader.readLongOrNull(offsets[3]);
  object.rowId = id;
  object.actionKind = reader.readString(offsets[4]);
  object.noCount = reader.readLong(offsets[5]);
  object.proposalId = reader.readLong(offsets[6]);
  object.proposalState = reader.readString(offsets[7]);
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
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
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
        IndexWhereClause.equalTo(indexName: r'kind', value: [actionKind]),
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
                indexName: r'kind',
                lower: [],
                upper: [actionKind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [actionKind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [actionKind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
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
        IndexWhereClause.equalTo(indexName: r'state', value: [proposalState]),
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
                indexName: r'state',
                lower: [],
                upper: [proposalState],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [proposalState],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [proposalState],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
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

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'data'),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'data'),
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
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
          property: r'data',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'data', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> snapshotDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'data', value: ''),
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

  QueryBuilder<Action, Action, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> actionKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition> proposalStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: ''),
      );
    });
  }

  QueryBuilder<Action, Action, QAfterFilterCondition>
  proposalStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state', value: ''),
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

  QueryBuilder<Action, Action, QAfterSortBy> sortBySnapshotData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortBySnapshotDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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

  QueryBuilder<Action, Action, QAfterSortBy> sortByActionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByActionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
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
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> sortByProposalStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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

  QueryBuilder<Action, Action, QAfterSortBy> thenBySnapshotData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenBySnapshotDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
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

  QueryBuilder<Action, Action, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByActionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByActionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
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
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Action, Action, QAfterSortBy> thenByProposalStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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

  QueryBuilder<Action, Action, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctBySnapshotData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByFinalAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'final_at');
    });
  }

  QueryBuilder<Action, Action, QDistinct> distinctByActionKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
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
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
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
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Action, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<Action, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<Action, String?, QQueryOperations> snapshotDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<Action, int?, QQueryOperations> finalAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'final_at');
    });
  }

  QueryBuilder<Action, String, QQueryOperations> actionKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
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
      return query.addPropertyName(r'state');
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
  idName: r'id',
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
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterFilterCondition>
  rowIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WalletCursor, WalletCursor, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
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
      return query.addPropertyName(r'id');
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
    r'entry_source': PropertySchema(
      id: 7,
      name: r'entry_source',
      type: IsarType.string,
    ),
    r'event_index': PropertySchema(
      id: 8,
      name: r'event_index',
      type: IsarType.long,
    ),
    r'execution_id': PropertySchema(
      id: 9,
      name: r'execution_id',
      type: IsarType.string,
    ),
    r'extrinsic_index': PropertySchema(
      id: 10,
      name: r'extrinsic_index',
      type: IsarType.long,
    ),
    r'fail_reason': PropertySchema(
      id: 11,
      name: r'fail_reason',
      type: IsarType.string,
    ),
    r'fee_amount': PropertySchema(
      id: 12,
      name: r'fee_amount',
      type: IsarType.string,
    ),
    r'from_address': PropertySchema(
      id: 13,
      name: r'from_address',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(id: 14, name: r'kind', type: IsarType.string),
    r'state': PropertySchema(id: 15, name: r'state', type: IsarType.string),
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
  idName: r'id',
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
  bytesCount += 3 + object.entrySource.length * 3;
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
  bytesCount += 3 + object.entryKind.length * 3;
  bytesCount += 3 + object.entryState.length * 3;
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
  writer.writeString(offsets[7], object.entrySource);
  writer.writeLong(offsets[8], object.eventIndex);
  writer.writeString(offsets[9], object.executionId);
  writer.writeLong(offsets[10], object.extrinsicIndex);
  writer.writeString(offsets[11], object.failReason);
  writer.writeString(offsets[12], object.feeAmount);
  writer.writeString(offsets[13], object.fromAddress);
  writer.writeString(offsets[14], object.entryKind);
  writer.writeString(offsets[15], object.entryState);
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
  object.entrySource = reader.readString(offsets[7]);
  object.eventIndex = reader.readLongOrNull(offsets[8]);
  object.executionId = reader.readStringOrNull(offsets[9]);
  object.extrinsicIndex = reader.readLongOrNull(offsets[10]);
  object.failReason = reader.readStringOrNull(offsets[11]);
  object.feeAmount = reader.readStringOrNull(offsets[12]);
  object.fromAddress = reader.readStringOrNull(offsets[13]);
  object.rowId = id;
  object.entryKind = reader.readString(offsets[14]);
  object.entryState = reader.readString(offsets[15]);
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
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
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
        FilterCondition.equalTo(property: r'id', value: value),
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
          property: r'id',
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
          property: r'id',
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
          property: r'id',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
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
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
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
          property: r'state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: ''),
      );
    });
  }

  QueryBuilder<Entry, Entry, QAfterFilterCondition> entryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state', value: ''),
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

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> sortByEntryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<Entry, Entry, QAfterSortBy> thenByEntryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
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

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntrySource({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entry_source', caseSensitive: caseSensitive);
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

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntryKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Entry, Entry, QDistinct> distinctByEntryState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
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
      return query.addPropertyName(r'id');
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

  QueryBuilder<Entry, String, QQueryOperations> entrySourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entry_source');
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

  QueryBuilder<Entry, String, QQueryOperations> entryKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<Entry, String, QQueryOperations> entryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
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
