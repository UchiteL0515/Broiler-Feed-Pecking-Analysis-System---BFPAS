import 'package:flutter/material.dart';

class ProcessProgressTimeline extends StatelessWidget {
  final int currentStep;
  final double percent;

  const ProcessProgressTimeline({
    super.key,
    required this.currentStep,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Recording Video',
      'Video Capture Frames',
      'Feature Extraction',
      'SVM Inference',
      'Complete',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: percent,
          minHeight: 8,
          borderRadius: BorderRadius.circular(20),
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 18),

        ...List.generate(steps.length, (index) {
          final isActive = index == currentStep;
          final isDone = index < currentStep;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 34 : 28,
                    height: isActive ? 34 : 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone || isActive
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade300,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2E7D32)
                                    .withOpacity(0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check
                          : isActive
                              ? Icons.autorenew
                              : Icons.circle,
                      color: Colors.white,
                      size: isActive ? 20 : 14,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 3,
                      height: 42,
                      color: isDone
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isDone ? 0.45 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index],
                          style: TextStyle(
                            fontSize: isActive ? 15 : 14,
                            fontWeight:
                                isActive ? FontWeight.w900 : FontWeight.w500,
                            color: isActive
                                ? Colors.black87
                                : Colors.black54,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(percent * 100).toStringAsFixed(0)}% processing...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}