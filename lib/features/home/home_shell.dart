import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../inbox/inbox_screen.dart';
import '../products/products_screen.dart';

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
      InboxScreen(controller: widget.controller),
      ProductsScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            elevation: 0,
            height: 68,
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF8B95A1),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined, color: Color(0xFF8B95A1)),
                selectedIcon: Icon(Icons.inbox),
                label: '콘텐츠',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF8B95A1),
                ),
                selectedIcon: Icon(Icons.inventory_2),
                label: '제품별',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
