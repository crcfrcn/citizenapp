// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_isar.dart';

// ignore_for_file: experimental_member_use

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
  idName: r'row_id',
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
  object.provinceCode = reader.readString(offsets[1]);
  object.regionName = reader.readString(offsets[2]);
  object.rowId = id;
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

  QueryBuilder<Region, Region, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
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
          property: r'row_id',
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
          property: r'row_id',
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
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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

  QueryBuilder<Region, Region, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Region, Region, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
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
      return query.addPropertyName(r'row_id');
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
  object.isLegal = reader.readBoolOrNull(offsets[8]);
  object.legalAccount = reader.readStringOrNull(offsets[9]);
  object.legalCid = reader.readStringOrNull(offsets[10]);
  object.orgCode = reader.readString(offsets[11]);
  object.parentCid = reader.readStringOrNull(offsets[12]);
  object.provinceCode = reader.readString(offsets[13]);
  object.rowId = id;
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

  QueryBuilder<Entity, Entity, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
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
          property: r'row_id',
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
          property: r'row_id',
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
          property: r'row_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
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

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Entity, Entity, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
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
      return query.addPropertyName(r'row_id');
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
  name: r'version',
  id: -3425991338577364869,
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
  idName: r'row_id',
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
  object.provinceData = reader.readStringOrNull(offsets[2]);
  object.rowId = id;
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

  QueryBuilder<Version, Version, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
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
          property: r'row_id',
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
          property: r'row_id',
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

  QueryBuilder<Version, Version, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Version, Version, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
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
      return query.addPropertyName(r'row_id');
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
  idName: r'row_id',
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
  object.provinceCodes = reader.readStringList(offsets[0]) ?? [];
  object.rowId = id;
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

  QueryBuilder<Catalog, Catalog, QAfterFilterCondition> rowIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
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
          property: r'row_id',
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
          property: r'row_id',
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

extension CatalogQueryObject
    on QueryBuilder<Catalog, Catalog, QFilterCondition> {}

extension CatalogQueryLinks
    on QueryBuilder<Catalog, Catalog, QFilterCondition> {}

extension CatalogQuerySortBy on QueryBuilder<Catalog, Catalog, QSortBy> {}

extension CatalogQuerySortThenBy
    on QueryBuilder<Catalog, Catalog, QSortThenBy> {
  QueryBuilder<Catalog, Catalog, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Catalog, Catalog, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
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
      return query.addPropertyName(r'row_id');
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
  idName: r'row_id',
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
  object.provinceCode = reader.readString(offsets[1]);
  object.rowId = id;
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

  QueryBuilder<Province, Province, QAfterFilterCondition> rowIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'row_id', value: value),
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
          property: r'row_id',
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
          property: r'row_id',
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

  QueryBuilder<Province, Province, QAfterSortBy> thenByRowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.asc);
    });
  }

  QueryBuilder<Province, Province, QAfterSortBy> thenByRowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'row_id', Sort.desc);
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
      return query.addPropertyName(r'row_id');
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
