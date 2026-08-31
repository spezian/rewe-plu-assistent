import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.productId,
    required this.action,
    required this.payload,
    required this.attempts,
  });

  final int id;
  final String productId;
  final String action;
  final Map<String, dynamic> payload;
  final int attempts;
}

class LocalDatabase {
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final databasePath = path.join(
      await getDatabasesPath(),
      'rewe_plu_assistent.db',
    );
    _database = await openDatabase(
      databasePath,
      version: 5,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            aliases TEXT NOT NULL DEFAULT '[]',
            image_path TEXT,
            image_url TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_organic INTEGER NOT NULL DEFAULT 0,
            is_promotion INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE product_codes (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
            type TEXT NOT NULL,
            value TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 0,
            note TEXT NOT NULL DEFAULT '',
            display_category TEXT,
            created_at TEXT NOT NULL,
            retired_at TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE product_images (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
            local_path TEXT,
            remote_url TEXT,
            source_page_url TEXT,
            attribution TEXT,
            license TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id TEXT NOT NULL,
            action TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_codes_product ON product_codes(product_id)',
        );
        await database.execute(
          'CREATE INDEX idx_codes_active ON product_codes(product_id, is_active)',
        );
        await database.execute(
          'CREATE INDEX idx_images_product ON product_images(product_id, sort_order)',
        );
        await database.execute(
          'CREATE INDEX idx_sync_created ON sync_queue(created_at)',
        );
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE products ADD COLUMN aliases TEXT NOT NULL DEFAULT '[]'",
          );
          await database.execute('''
            CREATE TABLE product_images (
              id TEXT PRIMARY KEY,
              product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
              local_path TEXT,
              remote_url TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            INSERT INTO product_images (
              id, product_id, local_path, remote_url, sort_order, created_at
            )
            SELECT id, id, image_path, image_url, 0, created_at
            FROM products
            WHERE image_path IS NOT NULL OR image_url IS NOT NULL
          ''');
          await database.execute(
            'CREATE INDEX idx_images_product '
            'ON product_images(product_id, sort_order)',
          );
        }
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE product_images ADD COLUMN source_page_url TEXT',
          );
          await database.execute(
            'ALTER TABLE product_images ADD COLUMN attribution TEXT',
          );
          await database.execute(
            'ALTER TABLE product_images ADD COLUMN license TEXT',
          );
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE products ADD COLUMN is_organic INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE products ADD COLUMN is_promotion INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 5) {
          await database.execute(
            'ALTER TABLE product_codes ADD COLUMN display_category TEXT',
          );
        }
      },
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Datenbank ist nicht initialisiert.');
    }
    return database;
  }

  Future<List<Product>> getProducts() async {
    final productRows = await _db.query('products');
    final codeRows = await _db.query('product_codes');
    final imageRows = await _db.query(
      'product_images',
      orderBy: 'product_id, sort_order',
    );
    final codesByProduct = <String, List<ProductCode>>{};
    final imagesByProduct = <String, List<ProductImageData>>{};
    for (final row in codeRows) {
      final code = ProductCode.fromDatabaseMap(row);
      codesByProduct.putIfAbsent(code.productId, () => []).add(code);
    }
    for (final row in imageRows) {
      final image = ProductImageData.fromDatabaseMap(row);
      imagesByProduct.putIfAbsent(image.productId, () => []).add(image);
    }
    return productRows
        .map(
          (row) => Product.fromDatabaseMap(
            row,
            codesByProduct[row['id']] ?? const [],
            imagesByProduct[row['id']] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<Product?> getProduct(String id) async {
    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final codeRows = await _db.query(
      'product_codes',
      where: 'product_id = ?',
      whereArgs: [id],
    );
    final imageRows = await _db.query(
      'product_images',
      where: 'product_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    return Product.fromDatabaseMap(
      rows.single,
      codeRows.map(ProductCode.fromDatabaseMap).toList(),
      imageRows.map(ProductImageData.fromDatabaseMap).toList(),
    );
  }

  Future<void> saveProduct(Product product, {bool enqueue = true}) async {
    await _db.transaction((transaction) async {
      await _writeProduct(transaction, product);
      if (enqueue) {
        await _replaceQueueEntry(
          transaction,
          product.id,
          'upsert',
          product.toQueueMap(),
        );
      }
    });
  }

  Future<void> applyRemoteProduct(Product product) async {
    await _db.transaction((transaction) => _writeProduct(transaction, product));
  }

  Future<void> _writeProduct(
    DatabaseExecutor transaction,
    Product product,
  ) async {
    await transaction.insert(
      'products',
      product.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await transaction.delete(
      'product_codes',
      where: 'product_id = ?',
      whereArgs: [product.id],
    );
    for (final code in product.codes) {
      await transaction.insert(
        'product_codes',
        code.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final image in product.images) {
      await transaction.insert(
        'product_images',
        image.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteProduct(String productId, {bool enqueue = true}) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((transaction) async {
      await transaction.delete(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (enqueue) {
        await _replaceQueueEntry(transaction, productId, 'delete', {
          'deleted_at': deletedAt,
        });
      }
    });
  }

  Future<void> _replaceQueueEntry(
    DatabaseExecutor transaction,
    String productId,
    String action,
    Map<String, Object?> payload,
  ) async {
    await transaction.delete(
      'sync_queue',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    await transaction.insert('sync_queue', {
      'product_id': productId,
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    });
  }

  Future<List<SyncQueueEntry>> getQueue() async {
    final rows = await _db.query('sync_queue', orderBy: 'created_at ASC');
    return rows
        .map(
          (row) => SyncQueueEntry(
            id: row['id']! as int,
            productId: row['product_id']! as String,
            action: row['action']! as String,
            payload:
                jsonDecode(row['payload']! as String) as Map<String, dynamic>,
            attempts: row['attempts']! as int,
          ),
        )
        .toList(growable: false);
  }

  Future<bool> hasPendingChange(String productId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_queue WHERE product_id = ?',
      [productId],
    );
    return Sqflite.firstIntValue(result)! > 0;
  }

  Future<int> pendingCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> completeQueueEntry(int id) =>
      _db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);

  Future<void> failQueueEntry(int id, Object error) => _db.rawUpdate(
    'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?',
    [error.toString(), id],
  );

  Future<void> updateRemoteImageUrl(String imageId, String imageUrl) async {
    await _db.update(
      'product_images',
      {'remote_url': imageUrl},
      where: 'id = ?',
      whereArgs: [imageId],
    );
  }
}
