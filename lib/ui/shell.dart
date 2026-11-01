import 'package:flutter/material.dart';

import '../logic/android_kanal.dart';
import '../logic/postfach_dienst.dart';
import 'app.dart';
import 'archiv.dart';
import 'fristen.dart';
import 'home.dart';
import 'mehr.dart';
import 'scan.dart';

/// Hauptgerüst mit der unteren Navigation.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // „Teilen → Papiertiger“ aus anderen Apps: beim Start und während die App läuft.
    AndroidKanal.beiNeuem(_geteiltAbholen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geteiltAbholen();
      _postfach();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _postfach();
  }

  /// Verknüpftes Postfach: beim Öffnen nachsehen (höchstens alle 10 Minuten).
  void _postfach() {
    if (!mounted) return;
    PostfachDienst.wennFaellig(StoreScope.of(context)).catchError((Object _) {});
  }

  Future<void> _geteiltAbholen() async {
    final teile = await AndroidKanal.abholen();
    if (teile.isEmpty || !mounted) return;
    setState(() => _tab = 0);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DateiImportScreen(geteilt: teile)));
  }

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
