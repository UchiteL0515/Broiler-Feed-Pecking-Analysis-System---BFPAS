import 'package:flutter/material.dart';
import '../models/chicken_record.dart';
import '../services/connection_service.dart';
import '../widgets/mjpeg_viewer.dart';

class ChickenDetailScreen extends StatelessWidget{
  final ChickenRecord record;

  const ChickenDetailScreen({super.key, required this.record});

  // Builds the stream URL using the same hardcoded Pi address from
  // ConnectionService so there is one single source of truth for the IP.
  String get _streamUrl =>
      'http://${ConnectionService.piAddress}:5000/stream';

  @override
  Widget build(BuildContext context){
    final isAnomaly = record.status == 'Anomaly';
    final statusColor = isAnomaly ? Colors.red : const Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text('Chicken #${record.chickenId}'),
      ),

      // SingleChildScrollView lets the bottom data section scroll freely
      // while the live feed stays fixed at the top
      body: Column(
        children: [
          // TOP HALF: Live Feed
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.38,
            color: Colors.black,
            child: MjpegViewer(streamUrl: _streamUrl),
          ),

          // BOTTOM HALF: Behavioral Data
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:  CrossAxisAlignment.stretch,
                children: [
                  // STATUS BANNER
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4)
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAnomaly
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          record.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BEHAVIORAL DATA ROWS
                  _DataCard(
                    title: 'Behavioral Data',
                    rows: [
                      _DataRow(
                        icon: Icons.timer_outlined,
                        label: 'Feed Duration',
                        value: '${record.feedDuration}s',
                      ),
                      _DataRow(
                        icon: Icons.speed_rounded,
                        label: 'Peck Frequency',
                        value: '${record.peckFrequency} ppm',
                      ),
                      _DataRow(
                        icon: Icons.swap_vert_rounded,
                        label: 'Head Movement Variability',
                        value: '${record.headMovementVariability}',
                      ),
                      _DataRow(
                        icon: Icons.pause_circle_outline_rounded,
                        label: 'Pause Interval',
                        value: '${record.pauseInterval}s',
                      ),
                      _DataRow(
                        icon: Icons.route_rounded,
                        label: 'Trajectory Pattern',
                        value: '${record.trajectoryPattern}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // TIMESTAMP
                  _DataCard(
                    title: 'Session Info',
                    rows:[
                      _DataRow(
                        icon: Icons.tag_rounded,
                        label: 'Chicken ID',
                        value: '${record.chickenId}',
                      ),
                      _DataRow(
                        icon: Icons.access_time_rounded,
                        label: 'Timestamp',
                        value: _formatTimestamp(record.timestamp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt){
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// HELPER WIDGETS
class _DataCard extends StatelessWidget{
  final String title;
  final List<_DataRow> rows;

  const _DataCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context){
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize:14)),
            const Divider(height: 20),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget{
  final IconData icon;
  final String label;
  final String value;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, 
                style: const TextStyle(
                    fontSize: 13, color: Colors.black54)),
          ),
          Text(value, 
              style: const TextStyle( 
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}