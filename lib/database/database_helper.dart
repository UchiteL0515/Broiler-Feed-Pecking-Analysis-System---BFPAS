// These are helper functions to be used for database management and handling

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chicken_record.dart';

class DatabaseHelper{
  static const _dbName = 'badmsystem_chicken.db';
  static const _dbVersion = 2; // bump whenever the schema changes
  static const table = 'chicken_behavior';

  // Singleton instance
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async{
    _db ??= await  _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async{
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async{
    await db.execute('''
      CREATE TABLE $table(
        id                          INTEGER PRIMARY KEY AUTOINCREMENT,
        chicken_id                  INTEGER NOT NULL,
        status                      TEXT NOT NULL CHECK(status IN ('Normal', 'Anomaly')),
        feed_duration               INTEGER NOT NULL,
        peck_frequency              INTEGER NOT NULL,
        head_movement_variability   INTEGER NOT NULL,
        pause_interval              INTEGER NOT NULL,        
        trajectory_pattern          INTEGER NOT NULL,
        timestamp                   TEXT NOT NULL
      )
    ''');
  }

  // DURING DEVELOPMENT: drop and recreate so the schema is always fresh...
  // IN PRODUCTION: make a proper handle for schema changes -- ALTER TABLE migrations instead
  Future<void>  _onUpgrade(Database db, int oldVersion, int newVersion) async{
    await db.execute('DROP TABLE IF EXISTS $table');
    await _onCreate(db, newVersion);
  }

  // -- CRUD --
  Future<int> insert(ChickenRecord record) async{
    final db = await database;
    return db.insert(table, record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChickenRecord>> getALL() async{
    final db = await database;
    final rows = await db.query(table, orderBy: 'timestamp DESC');
    return rows.map(ChickenRecord.fromMap).toList();
  }

  Future<List<ChickenRecord>> getByStatus(String status) async{
    final db = await database;
    final rows = await db.query(table,
      where: 'status = ?', whereArgs: [status], orderBy: 'timestamp DESC');
    return rows.map(ChickenRecord.fromMap).toList();
  }

  Future<int> count() async{
    final db = await database;
    final result = 
      await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteAll() async{
    final db = await database;
    await db.delete(table);
  }
}