import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'expense_detail_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _goalController = TextEditingController();
  final _dailyGoalController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    // 1. 내 목표 금액 가져오기 (users 컬렉션)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        // 2. 내 지출 내역 가져오기 (expenses 컬렉션)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('expenses')
              .where('uid', isEqualTo: user?.uid)
              .snapshots(),
          builder: (context, expenseSnapshot) {
            if (!userSnapshot.hasData || !expenseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // === 데이터 계산 로직 ===
            // A. 목표 금액
            int myGoal = 0;
            if (userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              myGoal = data['monthly_goal'] ?? 0;
            }
            final now = DateTime.now();
            final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            final int goalValue = int.tryParse(_goalController.text) ?? myGoal;
            final int dailyGoal = goalValue > 0 ? (goalValue / daysInMonth).round() : 0;
            // 컨트롤러에 값이 없을 때만 DB 값 채워주기 (입력 중 방해 안 되게)
            if (_goalController.text.isEmpty && myGoal > 0) {
              _goalController.text = myGoal.toString();
            }

            // B. 카테고리별 지출 합산
            final docs = expenseSnapshot.data!.docs;
            Map<String, int> categoryStats = {};

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final DateTime date = (data['date'] as Timestamp).toDate();
              
              // 이번 달 데이터만 합산
              if (date.month == now.month && date.year == now.year) {
                String cat = data['category'];
                int amount = data['amount'];
                if (categoryStats.containsKey(cat)) {
                  categoryStats[cat] = categoryStats[cat]! + amount;
                } else {
                  categoryStats[cat] = amount;
                }
              }
            }

            // === UI 그리기 ===
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.background,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text('이번달 목표 지출', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // 1. 목표 금액 입력 카드
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Text(
                            '목표 금액: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black.withOpacity(0.85),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _goalController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                              onSubmitted: (value) {
                                // 엔터 치면 저장
                                if (value.isNotEmpty) {
                                  context.read<AppState>().updateMonthlyGoal(int.parse(value));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("목표 금액이 수정되었습니다!")));
                                }
                              },
                            ),
                          ),
                          Text(
                            '원',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.85)),
                          ),
                          IconButton(
                            icon: Icon(Icons.save_alt, color: Theme.of(context).colorScheme.primary),
                            onPressed: () {
                              if (_goalController.text.isNotEmpty) {
                                context.read<AppState>().updateMonthlyGoal(int.parse(_goalController.text));
                                FocusScope.of(context).unfocus(); // 키보드 내리기
                              }
                            },
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '하루 목표 지출',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _dailyGoalController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: dailyGoal > 0
                                  ? '${NumberFormat('#,###').format(dailyGoal)}원 (이번 달 $daysInMonth일 기준)'
                                  : '목표 금액을 입력하면 일일 목표가 표시됩니다',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    const Text('이번달 지출 목록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // 2. 카테고리별 리스트
                    if (categoryStats.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("아직 지출 내역이 없습니다.")))
                    else
                      ...categoryStats.entries.map((entry) {
                        return _buildCategoryItem(entry.key, entry.value);
                      }),
                    
                    const SizedBox(height: 40),
                    
                    // 3. 상세보기 버튼 (나중에 6번 페이지 연결)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ExpenseDetailScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6E6FA), // 연한 보라
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('상세보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryItem(String category, int amount) {
    // 아이콘 자동 매칭
    IconData icon = Icons.category;
    if (category.contains('음식')) icon = Icons.lunch_dining;
    else if (category.contains('교통')) icon = Icons.directions_bus;
    else if (category.contains('여가')) icon = Icons.surfing;
    else if (category.contains('쇼핑')) icon = Icons.shopping_bag;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            // 랜덤 이미지 대신 아이콘 사용
            child: Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text("Category", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const Spacer(),
          Text('${NumberFormat('#,###').format(amount)}원', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
