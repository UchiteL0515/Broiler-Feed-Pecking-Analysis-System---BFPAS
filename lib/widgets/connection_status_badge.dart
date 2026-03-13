import 'package:flutter/material.dart';
import '../services/connection_service.dart';

class ConnectionStatusBadge extends StatelessWidget{
  final String label;
  final bool connected;
  final ConnectionStatus? piStatus;

  const ConnectionStatusBadge({
    super.key,
    required this.label,
    required this.connected,
    this.piStatus,
  });

  @override
  Widget build(BuildContext context){
    final isConnecting = piStatus == ConnectionStatus.connecting;
    final color = connected
      ? const Color(0xFF2E7D32)
      : isConnecting
        ? Colors.orange
        : Colors.red;

    final icon = connected
      ? Icons.check_circle_rounded
      : isConnecting 
        ? Icons.sync_rounded
        : Icons.cancel_rounded;

    final statusText = connected
      ? 'Connected'
      : isConnecting
        ? 'Connecting...'
        : 'Disconnected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isConnecting
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
            )
            : Icon(icon, size: 16, color: color),
          const SizedBox(width: 16),
          Text(
            '$label: $statusText',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}