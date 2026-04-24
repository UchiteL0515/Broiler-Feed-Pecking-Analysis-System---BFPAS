// This is the model used for records inserted into SQLite and records received
// from the Raspberry Pi server.

class ChickenRecord {
  final int? id;
  final int chickenId;
  final String status; // 'Normal' or 'Anomaly'
  final double feedDuration; // active feeding duration in seconds
  final double peckFrequency; // pecks per minute
  final double headMovementVariability; // hmv_std_velocity
  final double pauseInterval; // pause_std_sec
  final double trajectoryPattern; // trajectory_consistency
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

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String get feedDurationText => '${feedDuration.toStringAsFixed(2)}s';
  String get peckFrequencyText => '${peckFrequency.toStringAsFixed(2)} ppm';
  String get headMovementVariabilityText => headMovementVariability.toStringAsFixed(2);
  String get pauseIntervalText => '${pauseInterval.toStringAsFixed(2)}s';
  String get trajectoryPatternText => trajectoryPattern.toStringAsFixed(4);

  factory ChickenRecord.fromServerJson(Map<String, dynamic> json) {
    return ChickenRecord(
      chickenId: _toInt(json['id'] ?? json['chicken_id']),
      status: (json['status'] ?? 'No analysis yet').toString(),
      feedDuration: _toDouble(json['active_feeding_duration_sec']),
      peckFrequency: _toDouble(json['peck_frequency_per_min']),
      headMovementVariability: _toDouble(json['hmv_std_velocity']),
      pauseInterval: _toDouble(json['pause_std_sec']),
      trajectoryPattern: _toDouble(json['trajectory_consistency']),
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
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

  factory ChickenRecord.fromMap(Map<String, dynamic> map) {
    return ChickenRecord(
      id: map['id'] as int?,
      chickenId: _toInt(map['chicken_id']),
      status: map['status'] as String,
      feedDuration: _toDouble(map['feed_duration']),
      peckFrequency: _toDouble(map['peck_frequency']),
      headMovementVariability: _toDouble(map['head_movement_variability']),
      pauseInterval: _toDouble(map['pause_interval']),
      trajectoryPattern: _toDouble(map['trajectory_pattern']),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'ChickenRecord(id: $id, chickenId: $chickenId, status: $status, '
        'feedDuration: ${feedDurationText}, peckFrequency: ${peckFrequencyText}, '
        'headMovVariability: ${headMovementVariabilityText}, '
        'pauseInterval: ${pauseIntervalText}, trajectory: ${trajectoryPatternText}, '
        'timestamp: $timestamp)';
  }
}
