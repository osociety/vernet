import 'package:flutter/material.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/pages/settings_page.dart';
import '../ui/wifi_detail.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    checkForUpdates(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _children = [WifiDetail(), SettingsPage()];
    return Scaffold(
      body: Container(
        padding: MediaQuery.of(context).padding,
        child: _children[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped, // new
        currentIndex: _currentIndex, // new
        items: [
          new BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          new BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
