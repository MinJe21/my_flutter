import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// 화면들 임포트
import 'home_screen.dart';
import 'add_expense_screen.dart';
import 'budget_screen.dart';
import 'stat_screen.dart';

// 헤더 버튼 연결용 임포트
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'setting_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 탭별 화면 리스트
  final List<Widget> _pages = [
    const HomeScreen(),       // 0: 홈 (자체 헤더 있음 -> 앱바 숨김)
    const AddExpenseScreen(), // 1: 지출기록 (앱바 필요)
    const BudgetScreen(),     // 2: 예산관리 (앱바 필요)
    const StatScreen(),       // 3: 지출현황 (앱바 필요)
  ];

  // 탭별 제목 리스트
  final List<String> _titles = [
    '홈', 
    '지출 기록하기', 
    '예산 관리', 
    '지출 현황'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      
      // ▼▼▼ [핵심 수정] 0번(홈) 탭일 때는 앱바를 없애고(null), 나머지는 공통 앱바를 보여줌 ▼▼▼
      appBar: _selectedIndex == 0 
          ? null 
          : PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                    : null,
                builder: (context, snapshot) {
                  String? photoUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    photoUrl = data?['photoUrl'] as String?;
                  }

                  return AppBar(
                    backgroundColor: Theme.of(context).colorScheme.background,
                    elevation: 0,
                    centerTitle: true,
                    foregroundColor: Theme.of(context).colorScheme.onBackground,
                    // 1. 왼쪽 프로필 사진 (공통, 사진 우선)
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // 2. 가운데 제목 (탭마다 다르게)
                    title: Text(
                      _titles[_selectedIndex], 
                      style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.bold)
                    ),
                    // 3. 오른쪽 아이콘들 (알림, 설정)
                    actions: [
                      IconButton(
                        icon: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.onBackground),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onBackground),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingScreen())),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                },
              ),
            ),
      // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document),
            label: '지출기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '예산관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: '현황',
          ),
        ],
      ),
    );
  }
}
