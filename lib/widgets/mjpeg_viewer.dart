import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegViewer extends StatefulWidget{
  final String streamUrl;

  const MjpegViewer({super.key, required this.streamUrl});

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer>{
  // StreamController that emits one Uint8List per complete JPEG frame
  final _frameController = StreamController<Uint8List>.broadcast();

  http.Client? _client;
  StreamSubscription? _sub;
  bool _hasError = false;

  @override
  void initState(){
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async{
    try{
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await _client!.send(request);

      // Buffer accumulates raw bytes until we find a full JPEG
      final buffer = <int>[];

      _sub = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);

          // Scan buffer for complete JPEG frames
          // JPEG starts with 0xFF 0xD8 and ends with 0xFF 0xD9
          while(true){
            final start = _indexOf(buffer, [0xFF, 0xD8]);
            if(start == -1){
              buffer.clear(); // no start marker yet, discard
              break;
            }

            final end = _indexOf(buffer, [0xFF, 0xD9], from: start + 2);
            if(end == -1) break; // frame not complete yet, wait for more bytes

            // Extract the complete JPEG (inclusive of end marker + 2 bytes)
            final jpeg = Uint8List.fromList(
              buffer.sublist(start, end + 2),
            );

            // Emit the frame to the StreamBuilder
            if(!_frameController.isClosed){
              _frameController.add(jpeg);
            }

            // remove processed bytes from the buffer
            buffer.removeRange(0, end + 2);
          }
        },
        onError: (_) => _setError(),
        onDone: () => _setError(),
      );
    }
    catch(_){
      _setError();
    }
  }

  // Find the first occurence of [pattern] in [data] starting from [from].
  int _indexOf(List<int> data, List<int> pattern, {int from = 0}){
    outer:
    for(var i = from; i <= data.length - pattern.length; i++){
      for(var j = 0; j < pattern.length; j++){
        if(data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  void _setError(){
    if(mounted) setState(() => _hasError = true);
  }

  @override
  void dispose(){
    _sub?.cancel();
    _client?.close();
    _frameController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(_hasError){
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white38, size: 40),
            SizedBox(height: 8),
            Text(
              'Live Feed Unavailable',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Uint8List>(
      stream: _frameController.stream,
      builder: (context, snapshot){
        // no frame yet -- show loading indicator
        if(!snapshot.hasData){
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white54),
                SizedBox(height: 12),
                Text(
                  'Connecting to live feed...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Render the latest JPEG frame as an image
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.contain,
          // gaplessPlayback prevents flickering between frames
          gaplessPlayback: true,
        );
      },
    );
  }
}