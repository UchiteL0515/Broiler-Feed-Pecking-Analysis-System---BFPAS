// These are helper functions to be used for database management and handling

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chicken_record.dart';

class DatabaseHelper{
  static const _dbName = 'badmsystem_chicken.db';
  static const _dbVersion = 3; // bumped: metrics are REAL and dashboard uses latest per chicken
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
        feed_duration               REAL NOT NULL,
        peck_frequency              REAL NOT NULL,
        head_movement_variability   REAL NOT NULL,
        pause_interval              REAL NOT NULL,        
        trajectory_pattern          REAL NOT NULL,
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

  // Dashboard query: returns only the newest row for each chicken.
  // History still uses getALL(), so old sessions are preserved.
  Future<List<ChickenRecord>> getLatestPerChicken() async{
    final db = await database;
    final rows = await db.rawQuery('''
    SELECT t.*
    FROM $table t
    INNER JOIN (
      SELECT chicken_id, MAX(timestamp) AS latest_timestamp
      FROM $table
      GROUP BY chicken_id
    ) latest
    ON t.chicken_id = latest.chicken_id
    AND t.timestamp = latest.latest_timestamp
    ORDER BY t.chicken_id ASC
  ''');

  return rows.map(ChickenRecord.fromMap).toList();
}

  // Optional helper if you want only one saved row per chicken.
  // Do not use this if you want full session history.
  Future<int> upsertLatestForChicken(ChickenRecord record) async{
    final db = await database;
    await db.delete(
      table,
      where: 'chicken_id = ?',
      whereArgs: [record.chickenId],
    );
    return db.insert(table, record.toMap());
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