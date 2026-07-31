import 'package:flutter/material.dart';

final class NovelVoiceReaderApp extends StatelessWidget {
  const NovelVoiceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '声阅',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6B4F),
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('书架')),
        body: const Center(child: Text('还没有导入小说')),
      ),
    );
  }
}
