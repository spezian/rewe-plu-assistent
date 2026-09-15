import 'dart:convert';

import 'package:intl/intl.dart';

import '../core/app_constants.dart';

enum ProductCodeType { plu, price, barcode, cashierTile, info }

extension ProductCodeTypeX on ProductCodeType {
  String get databaseValue => name;

  String get label => switch (this) {
    ProductCodeType.plu => 'PLU',
    ProductCodeType.price => 'Preis',
    ProductCodeType.barcode => 'Barcode',
    ProductCodeType.cashierTile => 'Kassenkachel',
    ProductCodeType.info => 'Info',
  };

  String get inputHint => switch (this) {
    ProductCodeType.plu => 'z. B. 4011',
    ProductCodeType.price => 'z. B. 1,49',
    ProductCodeType.barcode => 'Nummer scannen oder eingeben',
    ProductCodeType.cashierTile => 'z. B. Kachel 6 oder Drachenfrucht',
    ProductCodeType.info => 'z. B. Nur stückweise verkaufen',
  };

  bool get canShowBarcode =>
      this == ProductCodeType.plu || this == ProductCodeType.barcode;

  static ProductCodeType fromDatabase(String value) =>
      ProductCodeType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => ProductCodeType.plu,
      );
}

class ProductCode {
  const ProductCode({
    required this.id,
    required this.productId,
    required this.type,
    required this.value,
    required this.isActive,
    required this.createdAt,
    this.note = '',
    this.displayCategory,
    this.retiredAt,
  });

  final String id;
  final String productId;
  final ProductCodeType type;
  final String value;
  final bool isActive;
  final String note;
  final String? displayCategory;
  final DateTime createdAt;
  final DateTime? retiredAt;

  String get displayValue {
    if (type != ProductCodeType.price) return value;
    final normalized = value.replaceAll(',', '.');
    final price = double.tryParse(normalized);
    if (price == null) return '$value €';
    return NumberFormat.currency(locale: 'de_DE', symbol: '€').format(price);
  }

  String get accessibilityLabel =>
      ['${type.label} $displayValue', ?secondaryDisplay].join(', ');

  String? get secondaryDisplay =>
      type == ProductCodeType.cashierTile && displayCategory?.isNotEmpty == true
      ? 'unter $displayCategory'
      : null;

  ProductCode copyWith({
    String? id,
    String? productId,
    ProductCodeType? type,
    String? value,
    bool? isActive,
    String? note,
    String? displayCategory,
    DateTime? createdAt,
    DateTime? retiredAt,
    bool clearRetiredAt = false,
  }) {
    return ProductCode(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      displayCategory: displayCategory ?? this.displayCategory,
      createdAt: createdAt ?? this.createdAt,
      retiredAt: clearRetiredAt ? null : (retiredAt ?? this.retiredAt),
    );
  }

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'product_id': productId,
    'type': type.databaseValue,
    'value': value,
    'is_active': isActive ? 1 : 0,
    'note': note,
    'display_category': displayCategory,
    'created_at': createdAt.toUtc().toIso8601String(),
    'retired_at': retiredAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toRemoteMap() => {
    'id': id,
    'product_id': productId,
    'type': type.databaseValue,
    'value': value,
    'is_active': isActive,
    'note': note,
    'display_category': displayCategory,
    'created_at': createdAt.toUtc().toIso8601String(),
    'retired_at': retiredAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toQueueMap() => toRemoteMap();

  factory ProductCode.fromDatabaseMap(Map<String, Object?> map) => ProductCode(
    id: map['id']! as String,
    productId: map['product_id']! as String,
    type: ProductCodeTypeX.fromDatabase(map['type']! as String),
    value: map['value']! as String,
    isActive: (map['is_active']! as int) == 1,
    note: (map['note'] as String?) ?? '',
    displayCategory: map['display_category'] as String?,
    createdAt: DateTime.parse(map['created_at']! as String).toLocal(),
    retiredAt: map['retired_at'] == null
        ? null
        : DateTime.parse(map['retired_at']! as String).toLocal(),
  );

  factory ProductCode.fromRemoteMap(Map<String, dynamic> map) => ProductCode(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    type: ProductCodeTypeX.fromDatabase(map['type'] as String),
    value: map['value'] as String,
    isActive: map['is_active'] as bool? ?? false,
    note: map['note'] as String? ?? '',
    displayCategory: map['display_category'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    retiredAt: map['retired_at'] == null
        ? null
        : DateTime.parse(map['retired_at'] as String).toLocal(),
  );
}

class ProductImageData {
  const ProductImageData({
    required this.id,
    required this.productId,
    required this.sortOrder,
    required this.createdAt,
    this.localPath,
    this.localThumbnailPath,
    this.remoteUrl,
    this.remoteThumbnailUrl,
    this.sourcePageUrl,
    this.attribution,
    this.license,
  });

  final String id;
  final String productId;
  final String? localPath;
  final String? localThumbnailPath;
  final String? remoteUrl;
  final String? remoteThumbnailUrl;
  final String? sourcePageUrl;
  final String? attribution;
  final String? license;
  final int sortOrder;
  final DateTime createdAt;

  ProductImageData copyWith({
    String? id,
    String? productId,
    String? localPath,
    String? localThumbnailPath,
    String? remoteUrl,
    String? remoteThumbnailUrl,
    String? sourcePageUrl,
    String? attribution,
    String? license,
    int? sortOrder,
    DateTime? createdAt,
  }) => ProductImageData(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    localPath: localPath ?? this.localPath,
    localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    remoteThumbnailUrl: remoteThumbnailUrl ?? this.remoteThumbnailUrl,
    sourcePageUrl: sourcePageUrl ?? this.sourcePageUrl,
    attribution: attribution ?? this.attribution,
    license: license ?? this.license,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'product_id': productId,
    'local_path': localPath,
    'local_thumbnail_path': localThumbnailPath,
    'remote_url': remoteUrl,
    'remote_thumbnail_url': remoteThumbnailUrl,
    'source_page_url': sourcePageUrl,
    'attribution': attribution,
    'license': license,
    'sort_order': sortOrder,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toRemoteMap() => {
    'id': id,
    'product_id': productId,
    'remote_url': remoteUrl,
    'remote_thumbnail_url': remoteThumbnailUrl,
    'source_page_url': sourcePageUrl,
    'attribution': attribution,
    'license': license,
    'sort_order': sortOrder,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toQueueMap() => toDatabaseMap();

  factory ProductImageData.fromDatabaseMap(Map<String, Object?> map) =>
      ProductImageData(
        id: map['id']! as String,
        productId: map['product_id']! as String,
        localPath: map['local_path'] as String?,
        localThumbnailPath: map['local_thumbnail_path'] as String?,
        remoteUrl: map['remote_url'] as String?,
        remoteThumbnailUrl: map['remote_thumbnail_url'] as String?,
        sourcePageUrl: map['source_page_url'] as String?,
        attribution: map['attribution'] as String?,
        license: map['license'] as String?,
        sortOrder: map['sort_order']! as int,
        createdAt: DateTime.parse(map['created_at']! as String).toLocal(),
      );

  factory ProductImageData.fromRemoteMap(
    Map<String, dynamic> map, {
    String? existingLocalPath,
    String? existingLocalThumbnailPath,
  }) => ProductImageData(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    localPath: existingLocalPath,
    localThumbnailPath: existingLocalThumbnailPath,
    remoteUrl: map['remote_url'] as String?,
    remoteThumbnailUrl: map['remote_thumbnail_url'] as String?,
    sourcePageUrl: map['source_page_url'] as String?,
    attribution: map['attribution'] as String?,
    license: map['license'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    required this.codes,
    this.description = '',
    this.aliases = const [],
    this.images = const [],
    this.isPinned = false,
    this.isOrganic = false,
    this.isPromotion = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> aliases;
  final List<ProductImageData> images;
  final bool isPinned;
  final bool isOrganic;
  final bool isPromotion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductCode> codes;

  ProductImageData? get primaryImage => images.isEmpty ? null : images.first;
  String? get imagePath => primaryImage?.localPath;
  String? get imageUrl => primaryImage?.remoteUrl;
  String? get thumbnailPath => primaryImage?.localThumbnailPath;
  String? get thumbnailUrl => primaryImage?.remoteThumbnailUrl;
  bool get isObsolete => activeCode == null;

  ProductCode? get activeCode {
    for (final code in codes) {
      if (code.isActive) return code;
    }
    return null;
  }

  List<ProductCode> get retiredCodes =>
      codes.where((code) => !code.isActive).toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    List<String>? aliases,
    List<ProductImageData>? images,
    bool? isPinned,
    bool? isOrganic,
    bool? isPromotion,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductCode>? codes,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      aliases: aliases ?? this.aliases,
      images: images ?? this.images,
      isPinned: isPinned ?? this.isPinned,
      isOrganic: isOrganic ?? this.isOrganic,
      isPromotion: isPromotion ?? this.isPromotion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      codes: codes ?? this.codes,
    );
  }

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'aliases': jsonEncode(aliases),
    'is_pinned': isPinned ? 1 : 0,
    'is_organic': isOrganic ? 1 : 0,
    'is_promotion': isPromotion ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toRemoteMap() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'aliases': aliases,
    'is_pinned': isPinned,
    'is_organic': isOrganic,
    'is_promotion': isPromotion,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toQueueMap() => {
    'product': toRemoteMap(),
    'codes': codes.map((code) => code.toQueueMap()).toList(),
    'images': images.map((image) => image.toQueueMap()).toList(),
  };

  factory Product.fromDatabaseMap(
    Map<String, Object?> map,
    List<ProductCode> codes,
    List<ProductImageData> images,
  ) => Product(
    id: map['id']! as String,
    name: map['name']! as String,
    category: normalizeProductCategory(map['category']! as String),
    description: map['description'] as String? ?? '',
    aliases: _decodeAliases(map['aliases']),
    images: images,
    isPinned: (map['is_pinned']! as int) == 1,
    isOrganic: (map['is_organic'] as int? ?? 0) == 1,
    isPromotion: (map['is_promotion'] as int? ?? 0) == 1,
    createdAt: DateTime.parse(map['created_at']! as String).toLocal(),
    updatedAt: DateTime.parse(map['updated_at']! as String).toLocal(),
    codes: codes,
  );

  factory Product.fromRemoteMap(
    Map<String, dynamic> map,
    List<ProductCode> codes, {
    required List<ProductImageData> images,
  }) => Product(
    id: map['id'] as String,
    name: map['name'] as String,
    category: normalizeProductCategory(map['category'] as String),
    description: map['description'] as String? ?? '',
    aliases: (map['aliases'] as List<dynamic>? ?? const [])
        .map((alias) => alias.toString())
        .toList(growable: false),
    images: images,
    isPinned: map['is_pinned'] as bool? ?? false,
    isOrganic: map['is_organic'] as bool? ?? false,
    isPromotion: map['is_promotion'] as bool? ?? false,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    codes: codes,
  );

  static List<String> _decodeAliases(Object? value) {
    if (value == null) return const [];
    try {
      return (jsonDecode(value as String) as List<dynamic>)
          .map((alias) => alias.toString())
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
