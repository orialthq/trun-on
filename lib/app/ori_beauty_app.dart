import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../features/home/home_shell.dart';
import '../state/app_controller.dart';

final class OriBeautyApp extends StatelessWidget {
  const OriBeautyApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '챙김',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomeShell(controller: controller),
    );
  }
}
