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
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: const [
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
                _MetricChip(label: 'PPM', value: '$peckFrequency'),
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