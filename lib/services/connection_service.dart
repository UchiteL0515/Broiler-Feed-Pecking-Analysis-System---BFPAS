import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { disconnected, connecting, connected, failed }

class ConnectionService extends ChangeNotifier {
  static const String piAddress = '192.168.1.23'; // Pi IP for connection
  static const int _port = 5000;
  static const int _timeout = 5;
  static const int _heartbeat = 10;
  static const int _retry = 5;

  // STATE 
  //final bool _appReady = true; // App always "connected" when launched...
  ConnectionStatus _piStatus = ConnectionStatus.disconnected;
  String _errorMessage = '';
  Timer? _heartbeatTimer;
  Timer? _retryTimer;

  // GETTERS
  ConnectionStatus get piStatus => _piStatus;
  String get errorMessage => _errorMessage;
  bool get isConnected => _piStatus == ConnectionStatus.connected;
  String get baseUrl => 'http://$piAddress:$_port';

  // AUTO-CONNECT (called once on app launch from main.dart)
  void init() => _attemptConnection();

  // SINGLE CONNECTION ATTEMPT - PRIVATE
  Future<void> _attemptConnection() async{
    _retryTimer?.cancel();
    _errorMessage = '';
    _setStatus(ConnectionStatus.connecting);

    final success = await _ping();

    if(success){
      _setStatus(ConnectionStatus.connected);
      _startHeartbeat();
    } else{
      _setStatus(ConnectionStatus.failed);
      _scheduleRetry(); // keeps on retrying until stable connection
    }
  }

  // PING HANDSHAKE
  Future<bool> _ping() async{
    try{
      final response = await http
        .get(Uri.parse('$baseUrl/ping'))
        .timeout(const Duration(seconds: _timeout));
      
      if(response.statusCode == 200){
        final body = jsonDecode(response.body);
        if(body['status'] == 'ok') return true;
      }

      _errorMessage = 'Unexpected response (${response.statusCode})';
      return false;
    } on TimeoutException{
      _errorMessage = 'Pi not reachable -- retrying...';
      return false;
    } catch(_){
      _errorMessage = 'Waiting for Pi on $piAddress...';
      return false;
    }
  }

  // HEARTBEAT: detect if Pi goes offline mid-session
  void _startHeartbeat(){
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeat),
      (_) async{
        if(!isConnected) return;
        final alive = await _ping();
        
        if(!alive){
          _heartbeatTimer?.cancel();
          _errorMessage = 'Lost connection to Pi -- retrying...';
          _setStatus(ConnectionStatus.failed);
          _scheduleRetry();
        }
      },
    );
  }

  // AUTO-RETRY UNTIL PI COMES BACK ONLINE
  void _scheduleRetry(){
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: _retry),
      (_) async{
        if(isConnected){
          _retryTimer?.cancel();
          return;
        }

        final success = await _ping();
        if(success){
          _retryTimer?.cancel();
          _setStatus(ConnectionStatus.connected);
          _startHeartbeat();
        }
        // stays on failed + keeps retrying silently
      },
    );
  }

  void _setStatus(ConnectionStatus s){
    _piStatus = s;
    notifyListeners();
  }

  @override
  void dispose(){
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}