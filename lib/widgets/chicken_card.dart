import 'package:flutter/material.dart';
import '../models/chicken_record.dart';
import '../screens/chicken_detail_screen.dart';

class ChickenCard extends StatelessWidget {
  final ChickenRecord record;

  const ChickenCard({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isAnomaly = record.status == 'Anomaly';

    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChickenDetailScreen(record: record),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app3.png',
                height: 50,
                width: 40,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 10),
              Text(
                'Chicken ${record.chickenId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                record.status,
                style: TextStyle(
                  color: isAnomaly ? Colors.red : const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}