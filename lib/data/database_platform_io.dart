import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<String> prepareDatabasePath(String databaseName) async =>
    path.join(await getDatabasesPath(), databaseName);
