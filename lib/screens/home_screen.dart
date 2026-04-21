import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../widgets/connection_status_badge.dart';
import '../database/database_helper.dart';
import '../models/chicken_record.dart';
import 'chicken_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'View All';
  late Future<List<ChickenRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = DatabaseHelper.instance.getALL();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
    appBar: AppBar(
         backgroundColor: const Color(0xFF1B5E20),
         foregroundColor: Colors.white,
         elevation: 1,
         centerTitle: false,
         titleSpacing: 10,
         
         title: Row(          
           children: [
            Image.asset(
              'assets/images/app1.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Broiler Feed-Pecking Analysis System',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'BFPAS',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
               ),
             ],
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
                const SizedBox(height: 20),

                Consumer<ConnectionService>(
                  builder: (context, conn, _) {
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System Status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ConnectionStatusBadge(
                                label: 'Raspberry Pi 4',
                                connected: conn.isConnected,
                                piStatus: conn.piStatus,
                              ),
                            ),
                            if (conn.isConnected && conn.errorMessage.isEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'IP: ${ConnectionService.piAddress}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                            ],
                            if (conn.errorMessage.isNotEmpty &&
                                !conn.isConnected) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 13,
                                    color: Colors.black38,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      conn.errorMessage,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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
              Text(
                '🐔',
                style: TextStyle(
                  fontSize: 32
                  ),
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