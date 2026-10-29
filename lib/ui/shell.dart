import 'package:flutter/material.dart';

import 'archiv.dart';
import 'fristen.dart';
import 'home.dart';
import 'mehr.dart';

/// Hauptgerüst mit der unteren Navigation.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(zuTab: (i) => setState(() => _tab = i)),
          const FristenScreen(),
          const ArchivScreen(),
          const MehrScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Start'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Fristen'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Archiv'),
          NavigationDestination(
              icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Mehr'),
        ],
      ),
    );
  }
}
