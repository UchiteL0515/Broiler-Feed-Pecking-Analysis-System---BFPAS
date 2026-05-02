import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/connection_service.dart';
import '../../widgets/onboarding_bottom.dart';
import '../../widgets/mjpeg_viewer.dart';
import '../home_screen.dart';

class CameraSetupScreen extends StatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  State<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends State<CameraSetupScreen> {
  bool _startingStream = false;
  bool _streamStarted = false;
  bool _cameraReady = false;

  String _message =
      'Start the raw camera preview and manually adjust the camera.';

  Future<void> _startRawStream() async {
    final conn = context.read<ConnectionService>();

    setState(() {
      _startingStream = true;
      _streamStarted = false;
      _cameraReady = false;
      _message = 'Connecting to raw camera stream...';
    });

    try {
      await conn.reconnect();

      if (!conn.isConnected) {
        setState(() {
          _startingStream = false;
          _cameraReady = false;
          _message = conn.errorMessage.isNotEmpty
              ? conn.errorMessage
              : 'Raspberry Pi server is not connected.';
        });
        return;
      }

      setState(() {
        _startingStream = false;
        _streamStarted = true;
        _cameraReady = true;
        _message =
            'Raw camera stream active. Adjust camera until the feeder is visible.';
      });
    } catch (_) {
      setState(() {
        _startingStream = false;
        _streamStarted = false;
        _cameraReady = false;
        _message = 'Failed to connect to raw camera stream.';
      });
    }
  }

  Future<void> _confirmSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_done', true);

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.35),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: const WelcomeOverlayScreen(),
          );
        },
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _cameraReady ? Colors.green : Colors.orange;

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
                    const SizedBox(height: 20),

                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        size: 60,
                        color: Color(0xFF2E7D32),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Camera Setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Use the raw camera preview to manually adjust the camera until the feeder area is clearly visible before proceeding.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 26),

                    Consumer<ConnectionService>(
                      builder: (context, conn, _) {
                        final streamUrl = '${conn.baseUrl}/raw_stream';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: _streamStarted
                                      ? MjpegViewer(streamUrl: streamUrl)
                                      : Container(
                                          color: Colors.black87,
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.videocam_off_rounded,
                                                  color: Colors.white54,
                                                  size: 48,
                                                ),
                                                SizedBox(height: 10),
                                                Text(
                                                  'Raw camera preview not started',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _cameraReady
                                          ? Icons.check_circle_rounded
                                          : Icons.info_rounded,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _message,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: statusColor.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _startingStream ? null : _startRawStream,
                                  icon: _startingStream
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.play_circle_rounded),
                                  label: Text(
                                    _startingStream
                                        ? 'Starting Preview...'
                                        : 'Start Raw Camera Preview',
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
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    _checkItem(
                      icon: Icons.restaurant_rounded,
                      text:
                          'Ensure the feeder area is clearly visible in the frame.',
                    ),
                    _checkItem(
                      icon: Icons.videocam_rounded,
                      text:
                          'Ensure the camera is stable and properly positioned.',
                    ),
                    _checkItem(
                      icon: Icons.light_mode_rounded,
                      text:
                          'Ensure lighting conditions are clear and consistent.',
                    ),
                    _checkItem(
                      icon: Icons.visibility_rounded,
                      text:
                          'Ensure chicken head movements are clearly observable.',
                    ),
                  ],
                ),
              ),
            ),

            OnboardingBottom(
              currentIndex: 2,
              buttonText: 'Confirm',
              onPressed: _confirmSetup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkItem({
    required IconData icon,
    required String text,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 450),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF2E7D32),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeOverlayScreen extends StatelessWidget {
  const WelcomeOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.95),
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 700),
          tween: Tween(begin: 0.8, end: 1),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/app1.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to BFPAS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smart monitoring of broiler feeding behavior through feed-pecking analysis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}