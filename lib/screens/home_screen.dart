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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'View All';
  late Future<List<ChickenRecord>> _recordsFuture;
  String _currentIp = ConnectionService.piAddress;

  late AnimationController _recordingController;
  late Animation<double> _scaleAnimation;

  bool _isRecording = false;
  Timer? _recordingTimer;
  final ValueNotifier<int> _recordingSecondsLeft = ValueNotifier<int>(10);
  BuildContext? _recordingDialogContext;

  @override
  void initState() {
    super.initState();
    _recordsFuture = DatabaseHelper.instance.getALL();

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
    final fresh = DatabaseHelper.instance.getALL();
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

    void _showRecordingInProgressMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording in progress. Please wait until it finishes.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              onPressed: () {
                final newIp = ipController.text.trim();

                if (!_isValidIp(newIp)) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid IP address.'),
                    ),
                  );
                  return;
                }

                setState(() {
                    newIp.isNotEmpty == true 
                      ? ConnectionService.piAddress = newIp 
                      : ConnectionService.piAddress = _currentIp;
                    
                    _currentIp = newIp;
                  });;

                Navigator.pop(dialogContext);
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

  void _startRecordingUi() {
    _recordingTimer?.cancel();
    _recordingSecondsLeft.value = 10; // change to 600 for 10 minutes

    setState(() {
      _isRecording = true;
    });

    _recordingController.repeat(reverse: true);

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingSecondsLeft.value > 0) {
        _recordingSecondsLeft.value--;
      } else {
        _stopRecordingUi();

        if (_recordingDialogContext != null) {
          Navigator.of(_recordingDialogContext!).pop();
          _recordingDialogContext = null;
        }

        _showResultDialog();
      }
    });
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

    void _showRecordingDialog() {
    if (_isRecording) {
      _showRecordingInProgressMessage();
      return;
    }

    _startRecordingUi();

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
            onStop: () {}, // kept because RecordingDialog still requires it
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
        child: FutureBuilder<List<ChickenRecord>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading records'));
            }

            final data = snapshot.data ?? [];
            final total = data.length;
            final normal = data.where((e) => e.status == 'Normal').length;
            final anomaly = data.where((e) => e.status == 'Anomaly').length;
            final filtered = _applyFilter(data);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                                    scale: _isRecording
                                        ? _scaleAnimation.value
                                        : 1.0,
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
                        if (conn.errorMessage.isNotEmpty &&
                            !conn.isConnected) ...[
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
                    children: ['View All', 'Normal', 'Anomaly']
                        .map(
                          (label) {
                            final isSelected = _selectedFilter == label;

                            // ✅ NEW: dynamic color
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

                                // ✅ UPDATED COLORS
                                selectedColor: color.withOpacity(0.2),
                                checkmarkColor: color,

                                labelStyle: TextStyle(
                                  color: isSelected ? color : Colors.black54,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                ),

                                // ✅ Optional: border for better look
                                side: BorderSide(
                                  color: isSelected ? color : Colors.black26,
                                ),
                              ),
                            );
                          },
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshRecords,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 150),
                              Center(
                                child: Text(
                                  _selectedFilter == 'View All'
                                      ? 'No recordings yet.'
                                      : 'No $_selectedFilter results yet.' ,
                                  style: const TextStyle(color: Colors.black45),
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
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
                          ),
                  ),
                ),
              ],
            );
          },
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