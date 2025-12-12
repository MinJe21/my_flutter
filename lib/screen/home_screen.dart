import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'saving_alert_screen.dart'; 
import 'profile_screen.dart';      
import 'notification_screen.dart'; 
import 'setting_screen.dart';     

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    final appState = context.watch<AppState>();
    final DateTime selectedDate = appState.selectedDate;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        int monthlyGoal = 500000;
        String? photoUrl; 

        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           if (userData.containsKey('monthly_goal')) {
             monthlyGoal = userData['monthly_goal']; 
           }
           if (userData.containsKey('photoUrl')) {
             photoUrl = userData['photoUrl'];
           }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('expenses')
              .where('uid', isEqualTo: user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text("데이터 로딩 에러: ${snapshot.error}")),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            int todaySpent = 0;
            int monthlySpent = 0;
            Map<String, int> categoryMap = {}; 
            
            final DateTime nowReal = DateTime.now();

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['date'] == null) continue;
              
              final Timestamp t = data['date'];
              final DateTime date = t.toDate();
              final int amount = data['amount'];
              final String category = data['category'];

              if (date.month == selectedDate.month && date.year == selectedDate.year) {
                monthlySpent += amount;
                
                if (categoryMap.containsKey(category)) {
                  categoryMap[category] = categoryMap[category]! + amount;
                } else {
                  categoryMap[category] = amount;
                }

                if (date.day == selectedDate.day) {
                  todaySpent += amount;
                }
              }
            }

            final topExpenses = categoryMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top3 = topExpenses.take(3).toList();

            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.background,
              
              appBar: AppBar(
                backgroundColor: Theme.of(context).colorScheme.background,
                elevation: 0,
                centerTitle: true,
                foregroundColor: Theme.of(context).colorScheme.onBackground,
                
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null 
                          ? Text(
                              user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                ),

                title: Text(
                  "홈",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                actions: [
                  IconButton(
                    icon: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavingAlertScreen())),
                  ),
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
              ),

              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      _buildDateHeader(context, selectedDate), 
                      
                      const SizedBox(height: 20),

                      _buildWeekRow(selectedDate, nowReal),
                      const SizedBox(height: 30),

                      _buildTodayCard(todaySpent, (monthlyGoal / 30).round()),
                      const SizedBox(height: 20),

                      _buildMonthlyStatus(monthlySpent, monthlyGoal),
                      const SizedBox(height: 30),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '지출 Top 3',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Serif',
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (top3.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "지출 내역이 없습니다.",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      else
                        ...top3.asMap().entries.map((entry) {
                          int index = entry.key + 1;
                          var item = entry.value; 
                          return _buildTopExpenseItem(index, item.key, item.value);
                        }),
                        
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black54),
          onPressed: () => context.read<AppState>().changeMonth(-1),
        ),
        GestureDetector(
          onTap: () {
            context.read<AppState>().resetToToday();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("오늘 날짜로 돌아왔습니다."), duration: Duration(seconds: 1)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              DateFormat('MMM yyyy').format(date), 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
          onPressed: () => context.read<AppState>().changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekRow(DateTime selectedDate, DateTime nowReal) {
    List<DateTime> weekDates = List.generate(7, (index) => selectedDate.add(Duration(days: index - 3)));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDates.map((d) {
        bool isSelected = d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day;
        bool isRealToday = d.year == nowReal.year && d.month == nowReal.month && d.day == nowReal.day;
        final Color primary = Theme.of(context).colorScheme.primary;
        return Column(
          children: [
            Text(DateFormat('E').format(d)[0], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? primary : (isRealToday ? primary.withOpacity(0.15) : Colors.transparent), 
                shape: BoxShape.circle
              ),
              child: Center(child: Text('${d.day}', style: TextStyle(color: isSelected ? Colors.white : (isRealToday ? primary : Colors.grey), fontWeight: (isSelected || isRealToday) ? FontWeight.bold : FontWeight.normal))),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTodayCard(int todaySpent, int todayGoal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25), width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text('💰 SELECTED DAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Text('${NumberFormat('#,###').format(todaySpent)}원', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          Text(
            todaySpent > todayGoal 
            ? '오늘 목표 초과! 💸' 
            : '목표 달성까지 ${NumberFormat('#,###').format(todayGoal - todaySpent)}원 남았어요',
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatus(int monthlySpent, int monthlyGoal) {
    int percent = monthlyGoal == 0 ? 0 : ((monthlyGoal - monthlySpent) / monthlyGoal * 100).toInt();
    return Row(
      children: [
        Expanded(child: _buildInfoCard('남은 예산', '$percent%', '${NumberFormat('#,###').format(monthlyGoal - monthlySpent)}원')),
        const SizedBox(width: 16),
        Expanded(child: _buildInfoCard('지출 목표', '${NumberFormat('#,###').format(monthlyGoal)}원', '이번달 총 목표')),
      ],
    );
  }

  Widget _buildInfoCard(String title, String mainText, String subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Text(mainText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 5),
          Text(subText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTopExpenseItem(int index, String category, int amount) {
    IconData icon = Icons.attach_money;
    Color color = Colors.grey;
    if (category.contains('음식') || category.contains('식사')) { icon = Icons.lunch_dining; color = Colors.orange; }
    else if (category.contains('교통') || category.contains('버스')) { icon = Icons.directions_bus; color = Colors.blue; }
    else if (category.contains('쇼핑')) { icon = Icons.shopping_bag; color = Colors.pink; }
    else if (category.contains('여가')) { icon = Icons.surfing; color = Colors.teal; }

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurfaceVariant.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Text('0$index', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Text(category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.onSurface)),
          const Spacer(),
          Text('${NumberFormat('#,###').format(amount)}원', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
