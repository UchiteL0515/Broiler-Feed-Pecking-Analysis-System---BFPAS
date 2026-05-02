import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/connection_service.dart';
import '../../widgets/onboarding_bottom.dart';
import 'camera_setup_screen.dart';

class IpConfigurationScreen extends StatefulWidget {
  const IpConfigurationScreen({super.key});

  @override
  State<IpConfigurationScreen> createState() => _IpConfigurationScreenState();
}

class _IpConfigurationScreenState extends State<IpConfigurationScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: ConnectionService.piAddress);

  bool _checking = false;
  bool _success = false;
  String _message = 'Enter the Raspberry Pi IP address.';

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _success = false;
        _message = 'Please enter the Raspberry Pi IP address.';
      });
      return;
    }

    setState(() {
      _checking = true;
      _success = false;
      _message = 'Checking connection...';
    });

    ConnectionService.setPiAddress = ip;

    final conn = context.read<ConnectionService>();
    await conn.reconnect();

    if (conn.isConnected) {
    await ConnectionService.savePiAddress(ip);
    }
    
    if (!mounted) return;

    setState(() {
      _checking = false;
      _success = conn.isConnected;
      _message = conn.isConnected
          ? 'Connected to Raspberry Pi server.'
          : conn.errorMessage.isNotEmpty
              ? conn.errorMessage
              : 'Cannot connect to Raspberry Pi.';
    });
  }

  void _showNotConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please connect to the Raspberry Pi first.'),
      ),
    );
  }

  void _next() {
    if (!_success) {
      _showNotConnected();
      return;
    }

    final ip = _ipController.text.trim();
    ConnectionService.setPiAddress = ip;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _success ? Colors.green : Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const SizedBox(height: 35),
                    Container(
                      height: 105,
                      width: 105,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.router_rounded,
                        size: 64,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'IP Configuration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Connect the mobile application to the Raspberry Pi server by entering its IP address.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),

                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (_success) {
                          setState(() {
                            _success = false;
                            _message =
                                'IP changed. Please test the connection again.';
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Raspberry Pi IP Address',
                        hintText: 'Example: 192.168.1.23',
                        prefixIcon: const Icon(Icons.wifi_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _checking ? null : _testConnection,
                        icon: _checking
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          _checking ? 'Checking...' : 'Test Connection',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(
                            color: Color(0xFF2E7D32),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _success
                                ? Icons.check_circle_rounded
                                : Icons.info_rounded,
                            color: color,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _message,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: color.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            OnboardingBottom(
              currentIndex: 1,
              buttonText: _success ? 'Next' : 'Connect First',
              onPressed: _success ? _next : _showNotConnected,
            ),
          ],
        ),
      ),
    );
  }
}