import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../widgets/connection_status_badge.dart';
import '../database/database_helper.dart';
import '../models/chicken_record.dart';
import 'chicken_detail_screen.dart';
import '../widgets/history.dart';

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
  final ValueNotifier<int> _recordingSecondsLeft = ValueNotifier<int>(600);
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid IP address.'),
                    ),
                  );
                  return;
                }

                setState(() {
                  _currentIp = newIp;
                });

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

  void _startRecordingUi() {
    _recordingTimer?.cancel();
    _recordingSecondsLeft.value = 600;

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
    if (!_isRecording) {
      _startRecordingUi();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _recordingDialogContext = dialogContext;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Opacity(
                    opacity: 0.25,
                    child: Image.asset(
                      'assets/images/loading screen.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    color: Colors.white.withOpacity(0.90),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7D32),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Recording',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Now recording for 10 minutes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: _recordingSecondsLeft,
                          builder: (context, value, _) {
                            return Text(
                              _formatTime(value),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () {
                            _stopRecordingUi();
                            Navigator.pop(dialogContext);
                            _recordingDialogContext = null;
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _recordingDialogContext = null;
    });
     
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
                    _StatCard(
                      label: 'Total',
                      value: total.toString(),
                      color: Colors.blueGrey,
                    ),
                    _StatCard(
                      label: 'Normal',
                      value: normal.toString(),
                      color: const Color(0xFF2E7D32),
                    ),
                    _StatCard(
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
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2E7D32),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.videocam,
                                  size: 16,
                                  color: Colors.white,
                                ),
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
                          (label) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(label),
                              selected: _selectedFilter == label,
                              onSelected: (_) {
                                setState(() {
                                  _selectedFilter = label;
                                });
                              },
                              selectedColor:
                                  const Color(0xFF2E7D32).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF2E7D32),
                              labelStyle: TextStyle(
                                color: _selectedFilter == label
                                    ? const Color(0xFF2E7D32)
                                    : Colors.black54,
                                fontWeight: _selectedFilter == label
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
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
                                      ? 'No records yet.'
                                      : 'No $_selectedFilter chickens.',
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
                              childAspectRatio: 1.1,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final record = filtered[index];
                              return _ChickenCard(record: record);
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChickenCard extends StatelessWidget {
  final ChickenRecord record;

  const _ChickenCard({required this.record});

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
              const Text(
                '🐔',
                style: TextStyle(fontSize: 32),
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