import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("설정"),
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("일반", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text("다크 모드"),
            trailing: Switch(
              value: appState.isDarkMode,
              onChanged: (v) => appState.setDarkMode(v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text("알림 설정"),
            onTap: () {},
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("정보", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("앱 버전"),
            trailing: const Text("1.0.0"),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text("이용약관"),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("회원 탈퇴", style: TextStyle(color: Colors.red)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("중요한 기능이라 실수로 누를까봐 막아뒀어요!")));
            },
          ),
        ],
      ),
    );
  }
}
