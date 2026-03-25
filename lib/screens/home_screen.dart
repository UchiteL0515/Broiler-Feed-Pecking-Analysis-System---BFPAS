import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../widgets/connection_status_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            // Chicken Stats Row (MOVED ABOVE)
            Row(
              children: [
                _StatCard(label: 'Total', value: '--', color: Colors.blueGrey),
                const SizedBox(width: 12),
                _StatCard(
                    label: 'Normal',
                    value: '--',
                    color: const Color(0xFF2E7D32)),
                const SizedBox(width: 12),
                _StatCard(label: 'Anomaly', value: '--', color: Colors.red),
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

                    if (conn.isConnected && conn.piAddress.isNotEmpty) ...[
                      const SizedBox(height: 8),

                      // ✅ ONLY CHANGE: CENTERED IP
                      Center(
                        child: Text(
                          'IP: ${conn.piAddress}',
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
                children: [
                  _FilterChip(label: 'View All', selected: true),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Normal', selected: false),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Anomaly', selected: false),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Empty Grid (placeholder - to be changed with actual logic)...
            Expanded(
              child: conn.isConnected
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sensors,
                            size: 48,
                            color:
                                const Color(0xFF2E7D32).withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Waiting for Chicken Data...',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off,
                              size: 48,
                              color: Colors.red.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'Connect to the Raspberry Pi 4\nto start monitoring.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets...
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {}, // Plug in actual logic here...
      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF2E7D32),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF2E7D32) : Colors.black54,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
