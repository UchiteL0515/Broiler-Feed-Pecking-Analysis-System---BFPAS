import 'package:flutter/material.dart';
import '../models/chicken_record.dart';

class ChickenDetailScreen extends StatelessWidget{
  final ChickenRecord record;

  const ChickenDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text('Chicken #${record.chickenId}'),
      ),

      body: const Center(
        child: Text(
          'Detail screen coming soon...',
          style: TextStyle(color: Colors.black45),
        ),
      ),
    );
  }
}