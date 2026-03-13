import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionService extends ChangeNotifier {
  final bool _appReady = true; // App always "connected" when launched...
  ConnectionStatus _piStatus = ConnectionStatus.disconnected;
  String _piAddress = '';

  bool get appReady => _appReady;
  ConnectionStatus get piStatus => _piStatus;
  String get piAddress => _piAddress;

  bool get isConnected => _piStatus == ConnectionStatus.connected;

  // Simulation of rasp pi system connection - to be replaced with actual logic...
  Future<void> connectToPi({String address = '192.168.1.0'}) async {
    _piStatus = ConnectionStatus.connecting;
    _piAddress = address;
    notifyListeners();

    // Replace this logic with the actual wifi handshake...
    await Future.delayed(const Duration(seconds: 2));

    _piStatus = ConnectionStatus.connected;
    notifyListeners();
  }

  void disconnect(){
    _piStatus = ConnectionStatus.disconnected;
    _piAddress = '';
    notifyListeners();
  }
}