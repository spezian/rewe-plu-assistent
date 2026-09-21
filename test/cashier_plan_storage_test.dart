import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/local_database.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late LocalDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cashier-plan-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    database = LocalDatabase();
    await database.initialize();
    database.setActiveMarket('market-a');
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(
      '${directory.path}/rewe_plu_assistent.db',
    );
    await directory.delete(recursive: true);
  });

  test(
    'persists imports and roles in one pending patch, isolated by market',
    () async {
      await database.saveCashierPlanPatch({
        'people': {'anna': 'Becker, Anna'},
      });
      await database.saveCashierPlanPatch({
        'roles': {'anna': 'cashier'},
      });
      expect((await database.getQueue()).length, 1);
      final patch = (await database.getQueue()).single.payload;
      expect(patch['people']['anna'], 'Becker, Anna');
      expect(patch['roles']['anna'], 'cashier');
      final reopened = LocalDatabase();
      await reopened.initialize();
      reopened.setActiveMarket('market-a');
      expect(
        (await reopened.getCashierPlan()).people.single.name,
        'Becker, Anna',
      );
      database.setActiveMarket('market-b');
      expect((await database.getCashierPlan()).people, isEmpty);
      expect(await database.getQueue(), isEmpty);
      await database.saveCashierPlanPatch({
        'people': {'ben': 'Wolf, Ben'},
      });
      database.setActiveMarket('market-a');
      expect((await database.getCashierPlan()).people.single.id, 'anna');
      database.setActiveMarket(null);
      expect((await database.getCashierPlan()).people, isEmpty);
      expect(() => database.saveCashierPlanPatch({}), throwsStateError);
    },
  );

  test(
    'an in-flight upload cannot acknowledge or overwrite newer local edits',
    () async {
      await database.saveCashierPlanPatch({
        'people': {'anna': 'Becker, Anna'},
      });
      final inFlight = (await database.getQueue()).single;
      await database.saveCashierPlanPatch({
        'roles': {'anna': 'manager'},
      });
      await database.completeQueueEntry(inFlight.id);
      expect((await database.getQueue()).length, 1);
      await database.applyRemoteCashierPlan('market-a', {
        'people': {'ben': 'Wolf, Ben'},
      });
      expect((await database.getCashierPlan()).people.single.id, 'anna');
      final queued = (await database.getQueue()).single;
      await database.completeQueueEntry(queued.id);
      await database.applyRemoteCashierPlan('market-a', queued.payload);
      expect(
        (await database.getCashierPlan()).people.single.role.name,
        'manager',
      );
    },
  );

  test(
    'a remote result is stored in its original market after switching',
    () async {
      database.setActiveMarket('market-b');
      await database.applyRemoteCashierPlan('market-a', {
        'people': {'anna': 'Becker, Anna'},
      });
      expect((await database.getCashierPlan()).people, isEmpty);
      database.setActiveMarket('market-a');
      expect((await database.getCashierPlan()).people.single.id, 'anna');
    },
  );

  test('repository refuses plan writes without editor access', () {
    final repository = ProductRepository();
    expect(
      () => repository.saveCashierPlanPatch({
        'roles': {'anna': 'manager'},
      }),
      throwsStateError,
    );
  });
}
