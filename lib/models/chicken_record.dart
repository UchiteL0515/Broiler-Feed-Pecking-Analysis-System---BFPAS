// This is the model that the records to be inserted in the database will be following

class ChickenRecord{
  final int? id;
  final int chickenId;
  final String status; // 'Normal' or 'Anomaly'
  final int feedDuration; // seconds
  final int peckFrequency; // pecks per minute
  final int headMovementVariability;
  final int pauseInterval; // seconds
  final int trajectoryPattern;
  final DateTime timestamp;

  ChickenRecord({
    this.id,
    required this.chickenId,
    required this.status,
    required this.feedDuration,
    required this.peckFrequency,
    required this.headMovementVariability,
    required this.pauseInterval,
    required this.trajectoryPattern,
    required this.timestamp,
  });

  // Convert a record to a Map for SQLite insertion
  Map<String, dynamic> toMap(){
    return{
      if(id != null) 'id': id,
      'chicken_id': chickenId,
      'status': status,
      'feed_duration': feedDuration,
      'peck_frequency': peckFrequency,
      'head_movement_variability': headMovementVariability,
      'pause_interval': pauseInterval,
      'trajectory_pattern': trajectoryPattern,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create a record from a SQLite row Map
  factory ChickenRecord.fromMap(Map<String, dynamic> map){
    return ChickenRecord(
      id: map['id'] as int?,
      chickenId: map['chicken_id'] as int,
      status: map['status'] as String,
      feedDuration: map['feed_duration'] as int,
      peckFrequency: map['peck_frequency'] as int,
      headMovementVariability: map['head_movement_variability'] as int,
      pauseInterval: map['pause_interval'] as int,
      trajectoryPattern: map['trajectory_pattern'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString(){
    return 'ChickenRecord(id: $id, chickenId: $chickenId, status: $status, '
      'feedDuration: ${feedDuration}s, peckFrequency: $peckFrequency ppm, '
      'headMovVariability: $headMovementVariability, '
      'pauseInterval: ${pauseInterval}s, trajectory: $trajectoryPattern, '
      'timestamp: $timestamp)';
  }
}