import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../widgets/connection_status_badge.dart';
import '../database/database_helper.dart';
import '../models/chicken_record.dart';
import 'chicken_detail_screen.dart';

class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'View All';

  List<ChickenRecord> _applyFilter(List<ChickenRecord> data){
    if(_selectedFilter == 'Normal') return data.where((r) => r.status == 'Normal').toList();
    if(_selectedFilter == 'Anomaly') return data.where((r) => r.status == 'Anomaly').toList();
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conn = context.watch<ConnectionService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      // This is the title and icon for the app...
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon placeholder - to be changed to actual asset later...
            Text('🐔', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Broiler Feed-Pecking Analysis System',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'BFPAS',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
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
              future: DatabaseHelper.instance.getALL(),
              builder: (context, snapshot){
                if(snapshot.connectionState == ConnectionState.waiting){
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if(snapshot.hasError){
                  return const Expanded(
                    child: Center(child: Text('Error loading records')),
                  );
                }

                final data = snapshot.data ?? [];

                final total = data.length;
                final normal = data.where((e) => e.status == 'Normal').length;
                final anomaly = data.where((e) => e.status == 'Anomaly').length;
                final filtered = _applyFilter(data);

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Chicken Stats Row (MOVED ABOVE)
                      Row( // This is the StatCard call with calculated data from records
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

                      // Connection Status Card...
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Status',
                                style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              
                              // ✅ CENTERED PI STATUS
                              Center(
                                child: ConnectionStatusBadge(
                                  label: 'Raspberry Pi 4',
                                  connected: conn.isConnected,
                                  piStatus: conn.piStatus,
                                ),
                              ),

                              if (conn.isConnected && conn.errorMessage.isEmpty) ...[
                                const SizedBox(height: 8),

                                // ✅ ONLY CHANGE: CENTERED IP
                                Center(
                                  child: Text(
                                    'IP: ${ConnectionService.piAddress}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black45),
                                  ),
                                ),
                              ],
                              
                              // Status message shown while waiting/retrying
                              if(conn.errorMessage.isNotEmpty && !conn.isConnected)...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                      size: 13, color: Colors.black38),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        conn.errorMessage,
                                        style: const TextStyle(
                                          fontSize: 12, color: Colors.black38),
                                      ),
                                    ),
                                  ],
                                ),
                              ],    
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ CENTERED FILTER CHIPS
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['View All', 'Normal', 'Anomaly']
                              .map((label) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: FilterChip(
                                      label: Text(label),
                                      selected: _selectedFilter == label,
                                      onSelected: (_) =>
                                          setState(() => _selectedFilter = label),
                                      selectedColor: const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.2),
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
                                  ))
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 20),
                      
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                              child: Text(
                                _selectedFilter == 'View All'
                                    ? 'No records yet.'
                                    : 'No $_selectedFilter chickens.',
                                style: const TextStyle(color: Colors.black45),
                              ),
                              )
                            : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index){
                                final record = filtered[index];
                                return _ChickenCard(record: record);
                              },
                            ),
                      ),
                    ],
                  ),
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets...
class _ChickenCard extends StatelessWidget{
  final ChickenRecord record;
  const _ChickenCard({required this.record});

  @override
  Widget build(BuildContext context){
    final isAnomaly = record.status == 'Anomaly';
    final statusColor = isAnomaly ? Colors.red : const Color(0xFF2E7D32);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChickenDetailScreen(record: record),
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐔', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(
                'ID: ${record.chickenId}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}