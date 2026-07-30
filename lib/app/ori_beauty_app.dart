import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../features/home/home_shell.dart';
import '../features/share/share_review_screen.dart';
import '../state/app_controller.dart';

final class OriBeautyApp extends StatelessWidget {
  const OriBeautyApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ori Beauty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.pendingShare != null) {
            return ShareReviewScreen(controller: controller);
          }
          return HomeShell(controller: controller);
        },
      ),
    );
  }
}
