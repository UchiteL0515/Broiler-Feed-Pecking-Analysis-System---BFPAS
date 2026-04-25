import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ProcessProgressTimeline extends StatefulWidget {
  final int currentStep;
  final double percent;

  const ProcessProgressTimeline({
    super.key,
    required this.currentStep,
    required this.percent,
  });

  @override
  State<ProcessProgressTimeline> createState() =>
      _ProcessProgressTimelineState();
}

class _ProcessProgressTimelineState extends State<ProcessProgressTimeline> {
  bool get _isProcessing => widget.currentStep < 4 && widget.percent < 1.0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep screen awake
  }

  @override
  void didUpdateWidget(covariant ProcessProgressTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isProcessing) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Recording Video',
      'Video Capture Frames',
      'Feature Extraction',
      'SVM Inference',
      'Complete',
    ];

    return PopScope(
      // 🚫 SAME LOGIC AS RECORDING DIALOG
      canPop: !_isProcessing,
      onPopInvoked: (didPop) {
        if (!didPop && _isProcessing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please wait until recording and processing are complete.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: widget.percent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final isActive = index == widget.currentStep;
            final isDone = index < widget.currentStep;
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
                                  color:
                                      const Color(0xFF2E7D32).withOpacity(0.35),
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
                              color: isActive ? Colors.black87 : Colors.black54,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${(widget.percent * 100).toStringAsFixed(0)}% processing...',
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
      ),
    );
  }
}
