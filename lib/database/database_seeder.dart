// NOTE: Use this for seeding demo data for testing functionaility
// USAGE: For debug builds only -- call inside main.dart
//        E.g. if(kDebugMode) await DatabaseSeeder.seed();
//
// If app is ready for release, remove the line above from inside main.dart

import 'package:flutter/foundation.dart';
import '../models/chicken_record.dart';
import 'database_helper.dart';

class DatabaseSeeder{
  DatabaseSeeder._(); // non-instantiable

  // Seeds the database with demo data
  //
  // Safe to re-run as this skips entirely if any rows already exists
  // this runs once per fresh app install.
  static Future<void> seed() async{
    if(!kDebugMode) return; // never runs in release builds

    final db = DatabaseHelper.instance;
    final existing = await db.count();
    if(existing > 0){
      debugPrint('[Seeder] Table already has $existing row(s) -- skipping.');
      return;
    }

    debugPrint('[Seeder] Empty table detected -- inserting demo records...');

    final now = DateTime.now();

    // Helper: produces a timestamp offset by [minutesAgo] minutes
    DateTime ts(int minutesAgo) =>
      now.subtract(Duration(minutes: minutesAgo));

    final records = <ChickenRecord>[
      // NORMAL CHICKENS
      // HEALTHY: regular peck rate, moderate feed duration, low pause gaps -- example only
      ChickenRecord(
        chickenId: 1,
        status: 'Normal',
        feedDuration: 32,
        peckFrequency: 24,
        headMovementVariability: 5,
        pauseInterval: 4,
        trajectoryPattern: 5,
        timestamp: ts(10),
      ),

      ChickenRecord(
        chickenId: 2,
        status: 'Normal',
        feedDuration: 28,
        peckFrequency: 21,
        headMovementVariability: 6,
        pauseInterval: 5,
        trajectoryPattern: 4,
        timestamp: ts(8),
      ),

      // ANOMALOUS CHICKEN
      // LETHARGIC: very short feed duration, low peck rate, long pauses -- example only
      ChickenRecord(
        chickenId: 3,
        status: 'Anomaly',
        feedDuration: 5,
        peckFrequency: 4,
        headMovementVariability: 2,
        pauseInterval: 22,
        trajectoryPattern: 1,
        timestamp: ts(5),
      ),
    ];

    for (final record in records){
      await db.insert(record);
    }

    debugPrint('[Seeder] Inserted ${records.length} demo records '
      '(${records.where((r) => r.status == 'Normal').length} normal, '
      '${records.where((r) => r.status == 'Anomaly').length}).');
  }

  // Force re-seed by wiping the table first
  // Useful during active UI development: call MANUALLY, never on auto-start
  static Future<void> reseed() async{
    if(!kDebugMode) return;
    await DatabaseHelper.instance.deleteAll();
    debugPrint('[Seeder] Table cleared -- reseeding...');
    await seed();
  }
}