import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connection_service.dart';
import '../database/database_helper.dart';
import '../models/chicken_record.dart';
import '../widgets/history.dart';
import '../widgets/chicken_card.dart';
import '../widgets/recording_dialog.dart';
import '../widgets/result_dialog.dart';
import '../widgets/stat_card.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/process_progress_timeline.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _analysisDurationSeconds = 600;

  String _selectedFilter = 'View All';
  late Future<List<ChickenRecord>> _recordsFuture;
  String _currentIp = ConnectionService.piAddress;

  late AnimationController _recordingController;
  late Animation<double> _scaleAnimation;

  bool _isRecording = false;
  Timer? _recordingTimer;

  final ValueNotifier<int> _recordingSecondsLeft =
      ValueNotifier<int>(_analysisDurationSeconds);

  final ValueNotifier<int> _processStep = ValueNotifier<int>(0);
  final ValueNotifier<double> _processPercent = ValueNotifier<double>(0.0);

  BuildContext? _recordingDialogContext;

  @override
  void initState() {
    super.initState();

    _recordsFuture = DatabaseHelper.instance.getLatestPerChicken();

    _recordingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(
      CurvedAnimation(
        parent: _recordingController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingController.dispose();
    _recordingSecondsLeft.dispose();
    _processStep.dispose();
    _processPercent.dispose();
    super.dispose();
  }

  List<ChickenRecord> _applyFilter(List<ChickenRecord> data) {
    if (_selectedFilter == 'Normal') {
      return data.where((r) => r.status == 'Normal').toList();
    }

    if (_selectedFilter == 'Anomaly') {
      return data.where((r) => r.status == 'Anomaly').toList();
    }

    return data;
  }

  Future<void> _refreshRecords() async {
    final fresh = DatabaseHelper.instance.getLatestPerChicken();

    setState(() {
      _recordsFuture = fresh;
    });

    await fresh;
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );

    return regex.hasMatch(ip.trim());
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    return '$mm:$ss';
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRecordingInProgressMessage() {
    _showSnack('Recording in progress. Please wait until it finishes.');
  }

  void _showIpDialog() {
    final TextEditingController ipController =
        TextEditingController(text: _currentIp);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Input IP',
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: TextField(
            controller: ipController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Enter IP address',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newIp = ipController.text.trim();

                if (!_isValidIp(newIp)) {
                  _showSnack('Please enter a valid IP address.');
                  return;
                }

                setState(() {
                  ConnectionService.piAddress = newIp;
                  _currentIp = newIp;
                });

                Navigator.pop(dialogContext);
                await context.read<ConnectionService>().reconnect();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enter'),
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const ResultDialog();
      },
    );
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: Color(0xFF2E7D32),
                size: 38,
              ),
              SizedBox(height: 10),
              Text(
                'Processing Analysis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Please wait while BFPAS analyzes the recording.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          content: ValueListenableBuilder<int>(
            valueListenable: _processStep,
            builder: (context, step, _) {
              return ValueListenableBuilder<double>(
                valueListenable: _processPercent,
                builder: (context, percent, _) {
                  return ProcessProgressTimeline(
                    currentStep: step,
                    percent: percent,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _runProcessingProgressFromPi() async {
    final conn = context.read<ConnectionService>();

    while (mounted) {
      final status = await conn.fetchInferenceStatus();

      final phase = status['phase']?.toString() ?? 'idle';
      final elapsed = status['elapsed_sec'] ?? 0;
      final duration = status['duration_sec'] ?? 1;

      if (phase == 'recording') {
        _processStep.value = 0;
        _processPercent.value = duration > 0 ? elapsed / duration : 0.0;
      } else if (phase == 'processing_video') {
        _processStep.value = 1;
        _processPercent.value = 0.35;
      } else if (phase == 'extracting_features') {
        _processStep.value = 2;
        _processPercent.value = 0.65;
      } else if (phase == 'svm_prediction') {
        _processStep.value = 3;
        _processPercent.value = 0.85;
      } else if (phase == 'done') {
        _processStep.value = 4;
        _processPercent.value = 1.0;
        break;
      } else if (phase == 'error') {
        throw Exception(status['error'] ?? 'Inference error');
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _startRecordingUi(int durationSeconds) {
    _recordingTimer?.cancel();
    _recordingSecondsLeft.value = durationSeconds;

    setState(() {
      _isRecording = true;
    });

    _recordingController.repeat(reverse: true);

    _recordingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_recordingSecondsLeft.value > 0) {
          _recordingSecondsLeft.value--;
        } else {
          timer.cancel();
          await _finishRecordingSession();
        }
      },
    );
  }

  void _stopRecordingUi() {
    _recordingTimer?.cancel();
    _recordingController.stop();
    _recordingController.reset();

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _saveLatestPiDataToDatabase() async {
    final conn = context.read<ConnectionService>();

    await conn.waitForInferenceToFinish();

    final records = await conn.fetchChickenData();

    for (final record in records) {
      if (record.status == 'Normal' || record.status == 'Anomaly') {
        await DatabaseHelper.instance.insert(record);
      }
    }

    await _refreshRecords();
  }

  Future<void> _finishRecordingSession() async {
    _stopRecordingUi();

    if (_recordingDialogContext != null) {
      Navigator.of(_recordingDialogContext!).pop();
      _recordingDialogContext = null;
    }

    if (!mounted) return;

    _processStep.value = 0;
    _processPercent.value = 0.0;

    _showProcessingDialog();

    try {
      await _runProcessingProgressFromPi();
      await _saveLatestPiDataToDatabase();

      if (!mounted) return;

      Navigator.of(context).pop();
      _showResultDialog();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      _showSnack('Inference failed: $e');
    }
  }

  Future<void> _showRecordingDialog() async {
    if (_isRecording) {
      _showRecordingInProgressMessage();
      return;
    }

    final conn = context.read<ConnectionService>();

    if (!conn.isConnected) {
      _showSnack('Raspberry Pi is not connected. Check IP and try again.');
      return;
    }

    try {
      await conn.startInference(durationSec: _analysisDurationSeconds);
    } catch (e) {
      _showSnack('Failed to start inference: $e');
      return;
    }

    _startRecordingUi(_analysisDurationSeconds);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _recordingDialogContext = dialogContext;

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) {
              _showRecordingInProgressMessage();
            }
          },
          child: RecordingDialog(
            recordingSecondsLeft: _recordingSecondsLeft,
            formatTime: _formatTime,
            onStop: () {},
          ),
        );
      },
    ).then((_) {
      _recordingDialogContext = null;
    });
  }

  void _openHistory() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => const HistoryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        titleSpacing: 10,
        toolbarHeight: 72,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/app1.png',
                height: 44,
                width: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Broiler Feed-Pecking Analysis System',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'BFPAS',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<List<ChickenRecord>>(
              future: _recordsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data ?? [];
                final total = data.length;
                final normal = data.where((e) => e.status == 'Normal').length;
                final anomaly = data.where((e) => e.status == 'Anomaly').length;

                return Row(
                  children: [
                    StatCard(
                      label: 'Total',
                      value: total.toString(),
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 10),
                    StatCard(
                      label: 'Normal',
                      value: normal.toString(),
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 10),
                    StatCard(
                      label: 'Anomaly',
                      value: anomaly.toString(),
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Consumer<ConnectionService>(
              builder: (context, conn, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showIpDialog,
                          child: ConnectionStatusBadge(
                            label: 'Raspberry Pi 4',
                            connected: conn.isConnected,
                            piStatus: conn.piStatus,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showRecordingDialog,
                          child: AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale:
                                    _isRecording ? _scaleAnimation.value : 1.0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _isRecording
                                        ? const Color(0xFFB71C1C)
                                        : const Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                    boxShadow: _isRecording
                                        ? [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(
                                                0.35,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Icon(
                                    _isRecording
                                        ? Icons.fiber_manual_record
                                        : Icons.videocam,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'IP: $_currentIp',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    if (conn.errorMessage.isNotEmpty && !conn.isConnected) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          conn.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ['View All', 'Normal', 'Anomaly'].map(
                  (label) {
                    final isSelected = _selectedFilter == label;
                    final color = label == 'Anomaly'
                        ? Colors.red
                        : const Color(0xFF2E7D32);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = label;
                          });
                        },
                        selectedColor: color.withOpacity(0.2),
                        checkmarkColor: color,
                        labelStyle: TextStyle(
                          color: isSelected ? color : Colors.black54,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? color : Colors.black26,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshRecords,
                child: FutureBuilder<List<ChickenRecord>>(
                  future: _recordsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 150),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 150),
                          Center(child: Text('Error loading records')),
                        ],
                      );
                    }

                    final data = snapshot.data ?? [];
                    final filtered = _applyFilter(data);

                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 150),
                          Center(
                            child: Text(
                              _selectedFilter == 'View All'
                                  ? 'No chicken analysis records yet.'
                                  : 'No $_selectedFilter results yet.',
                              style: const TextStyle(color: Colors.black45),
                            ),
                          ),
                        ],
                      );
                    }

                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        return ChickenCard(record: record);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openHistory,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        mini: true,
        shape: const CircleBorder(),
        child: const Icon(Icons.menu),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
