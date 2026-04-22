import 'package:flutter/material.dart';

class HistoryDialog extends StatelessWidget {
  const HistoryDialog({super.key});

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
          color: const Color(0xFFF5F7F5).withOpacity(0.6),
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
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: const [
                    // ✅ MOST RECENT FIRST (Session 2)
                    _HistoryCard(
                      chickenId: 2,
                      status: 'Anomaly',
                      feedDuration: 6,
                      peckFrequency: 3,
                      headMovementVariability: 2,
                      pauseInterval: 20,
                      trajectoryPattern: 2,
                      dateText: 'April 22, 2026 • 04:30 PM • Session 2',
                    ),
                    _HistoryCard(
                      chickenId: 1,
                      status: 'Normal',
                      feedDuration: 30,
                      peckFrequency: 22,
                      headMovementVariability: 5,
                      pauseInterval: 6,
                      trajectoryPattern: 5,
                      dateText: 'April 22, 2026 • 04:30 PM • Session 2',
                    ),

                    // ✅ OLDER (Session 1)
                    _HistoryCard(
                      chickenId: 3,
                      status: 'Anomaly',
                      feedDuration: 5,
                      peckFrequency: 4,
                      headMovementVariability: 2,
                      pauseInterval: 22,
                      trajectoryPattern: 1,
                      dateText: 'April 22, 2026 • 08:00 AM • Session 1',
                    ),
                    _HistoryCard(
                      chickenId: 2,
                      status: 'Normal',
                      feedDuration: 28,
                      peckFrequency: 21,
                      headMovementVariability: 6,
                      pauseInterval: 5,
                      trajectoryPattern: 4,
                      dateText: 'April 22, 2026 • 08:00 AM • Session 1',
                    ),
                    _HistoryCard(
                      chickenId: 1,
                      status: 'Normal',
                      feedDuration: 32,
                      peckFrequency: 24,
                      headMovementVariability: 5,
                      pauseInterval: 4,
                      trajectoryPattern: 5,
                      dateText: 'April 22, 2026 • 08:00 AM • Session 1',
                    ),
                  ],
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
  final int feedDuration;
  final int peckFrequency;
  final int headMovementVariability;
  final int pauseInterval;
  final int trajectoryPattern;
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
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Chicken $chickenId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAnomaly ? Colors.red : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Text('Feed Duration: $feedDuration'),
            Text('Peck Frequency: $peckFrequency'),
            Text('Head Movement Variability: $headMovementVariability'),
            Text('Pause Interval: $pauseInterval'),
            Text('Trajectory Pattern: $trajectoryPattern'),
          ],
        ),
      ),
    );
  }
}
