import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../compare/compare_screen.dart';
import '../criteria/criteria_screen.dart';
import '../inbox/inbox_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      InboxScreen(
        controller: widget.controller,
        onOpenCompare: () => setState(() => _selectedIndex = 1),
      ),
      CompareScreen(controller: widget.controller),
      CriteriaScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: '수집함',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows),
            label: '비교',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '내 기준',
          ),
        ],
      ),
    );
  }
}
