import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chicken_record.dart';

class HistoryDialog extends StatelessWidget {
  const HistoryDialog({super.key});

  String _formatDateTime(DateTime timestamp) {
    final month = _monthName(timestamp.month);
    final day = timestamp.day;
    final year = timestamp.year;

    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : timestamp.hour == 0
            ? 12
            : timestamp.hour;

    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • $hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.82,
          color: const Color(0xFFF5F7F5).withOpacity(0.92),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF1B5E20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ChickenRecord>>(
                  future: DatabaseHelper.instance.getALL(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading history.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }

                    final records = snapshot.data ?? [];

                    if (records.isEmpty) {
                      return const Center(
                        child: Text(
                          'No history yet.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];

                        return _HistoryCard(
                          chickenId: record.chickenId,
                          status: record.status,
                          feedDuration: record.feedDuration,
                          peckFrequency: record.peckFrequency,
                          headMovementVariability:
                              record.headMovementVariability,
                          pauseInterval: record.pauseInterval,
                          trajectoryPattern: record.trajectoryPattern,
                          dateText:
                              '${_formatDateTime(record.timestamp)} • Session ${index + 1}',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final int chickenId;
  final String status;
  final double feedDuration;
  final double peckFrequency;
  final double headMovementVariability;
  final double pauseInterval;
  final double trajectoryPattern;
  final String dateText;

  const _HistoryCard({
    required this.chickenId,
    required this.status,
    required this.feedDuration,
    required this.peckFrequency,
    required this.headMovementVariability,
    required this.pauseInterval,
    required this.trajectoryPattern,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final isAnomaly = status == 'Anomaly';

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAnomaly
                        ? Colors.red.withOpacity(0.08)
                        : const Color(0xFF2E7D32).withOpacity(0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/app3.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chicken $chickenId',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAnomaly
                        ? Colors.red.withOpacity(0.12)
                        : const Color(0xFF2E7D32).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isAnomaly ? Colors.red : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Feed', value: '$feedDuration'),
                _MetricChip(label: 'Peck', value: '$peckFrequency'),
                _MetricChip(label: 'HMV', value: '$headMovementVariability'),
                _MetricChip(label: 'Pause', value: '$pauseInterval'),
                _MetricChip(label: 'Path', value: '$trajectoryPattern'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}