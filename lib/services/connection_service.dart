import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chicken_record.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

class ConnectionService extends ChangeNotifier {
  static String piAddress = '192.168.1.23'; // Pi IP for connection
  static const int _port = 5000;
  static const int _timeout = 5;
  static const int _heartbeat = 10;
  static const int _retry = 5;

  ConnectionStatus _piStatus = ConnectionStatus.disconnected;
  String _errorMessage = '';
  Timer? _heartbeatTimer;
  Timer? _retryTimer;

  ConnectionStatus get piStatus => _piStatus;
  String get errorMessage => _errorMessage;
  bool get isConnected => _piStatus == ConnectionStatus.connected;
  String get baseUrl => 'http://$piAddress:$_port';

  static set setPiAddress(String value) {
    piAddress = value;
  }

  void init() => _attemptConnection();

  Future<void> reconnect() async {
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    await _attemptConnection();
  }

  Future<void> _attemptConnection() async {
    _retryTimer?.cancel();
    _errorMessage = '';
    _setStatus(ConnectionStatus.connecting);

    final success = await _ping();

    if (success) {
      _setStatus(ConnectionStatus.connected);
      _startHeartbeat();
    } else {
      _setStatus(ConnectionStatus.failed);
      _scheduleRetry();
    }
  }

  Future<bool> _ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'ok') return true;
      }

      _errorMessage = 'Unexpected response (${response.statusCode})';
      return false;
    } on TimeoutException {
      _errorMessage = 'Pi not reachable -- retrying...';
      return false;
    } catch (_) {
      _errorMessage = 'Waiting for Pi on $piAddress...';
      return false;
    }
  }

  Future<void> startInference({required int durationSec}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/inference/start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'duration_sec': durationSec}),
        )
        .timeout(const Duration(seconds: _timeout));

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode != 200) {
      final message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Failed to start inference (${response.statusCode})';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getInferenceStatus() async {
    final response = await http
        .get(Uri.parse('$baseUrl/inference/status'))
        .timeout(const Duration(seconds: _timeout));

    if (response.statusCode != 200) {
      throw Exception('Failed to get inference status (${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> waitForInferenceToFinish({int maxExtraWaitSec = 30}) async {
    final deadline = DateTime.now().add(Duration(seconds: maxExtraWaitSec));

    while (DateTime.now().isBefore(deadline)) {
      final status = await getInferenceStatus();
      final running = status['running'] == true;
      if (!running) return;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<List<ChickenRecord>> fetchChickenData() async {
    final response = await http
        .get(Uri.parse('$baseUrl/data'))
        .timeout(const Duration(seconds: _timeout));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chicken data (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final chickens = decoded['chickens'] as List<dynamic>? ?? [];

    return chickens
        .map((item) => ChickenRecord.fromServerJson(item as Map<String, dynamic>))
        .toList();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeat),
      (_) async {
        if (!isConnected) return;
        final alive = await _ping();

        if (!alive) {
          _heartbeatTimer?.cancel();
          _errorMessage = 'Lost connection to Pi -- retrying...';
          _setStatus(ConnectionStatus.failed);
          _scheduleRetry();
        }
      },
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: _retry),
      (_) async {
        if (isConnected) {
          _retryTimer?.cancel();
          return;
        }

        final success = await _ping();
        if (success) {
          _retryTimer?.cancel();
          _setStatus(ConnectionStatus.connected);
          _startHeartbeat();
        }
      },
    );
  }

  void _setStatus(ConnectionStatus s) {
    _piStatus = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
