import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../app_state.dart';

class MainApp extends StatelessWidget {
  final Widget child;
  final tabs = [
    _TabItem(path: '/groups', icon: Icons.group, label: 'Groups'),
          _TabItem(path: '/calendar', icon: Icons.calendar_today, label: 'Calendar'),
          _TabItem(path: '/', icon: Icons.home, label: 'Home'),
          _TabItem(path: '/prayer', icon: Icons.book, label: 'Prayer'),
          _TabItem(path: '/more', icon: Icons.more_horiz, label: 'More'),
  ]; // → define as static const or a top-level list
  MainApp({super.key, required this.child});


  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {

        final currentLocation = GoRouterState.of(context).uri.toString();
        final currentIndex = tabs.indexWhere(
          (t) => currentLocation == t.path || currentLocation.startsWith('${t.path}/'),
        );
        final selectedIndex = currentIndex == -1 ? 2 : currentIndex;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 237, 239, 239),
            leadingWidth: 120,
            leading: const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Center(
                child: Text(
                  'CCF App',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            title: Image.asset(
              'assets/logo_image.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => context.pushReplacement('/notifications'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: Colors.grey, height: 1),
            ),
          ),

          body: child, // Render current shell route child

          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: BottomNavigationBar(
              backgroundColor: const Color.fromARGB(255, 237, 239, 239),
              currentIndex: selectedIndex,
              onTap: (index) {
                if (index != selectedIndex) {
                  context.pushReplacement(tabs[index].path);
                }
              },
              selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
              unselectedItemColor: const Color.fromARGB(179, 72, 71, 71),
              selectedLabelStyle: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              unselectedLabelStyle: const TextStyle(color: Color.fromARGB(179, 72, 71, 71)),
              items: tabs
                  .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final String label;

  const _TabItem({
    required this.path,
    required this.icon,
    required this.label,
  });
}
