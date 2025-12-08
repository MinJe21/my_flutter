import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/ai_service.dart';

class SavingAlertScreen extends StatefulWidget {
  const SavingAlertScreen({super.key});

  @override
  State<SavingAlertScreen> createState() => _SavingAlertScreenState();
}

class _SavingAlertScreenState extends State<SavingAlertScreen> {
  final user = FirebaseAuth.instance.currentUser;
  
  Future<Map<String, String>>? _aiFeedbackFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text("월말 정산 리포트", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground)),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, userSnapshot) {
          int monthlyGoal = 500000;
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            monthlyGoal = userData['monthly_goal'] ?? 500000;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .where('uid', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, expenseSnapshot) {
              if (!expenseSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = expenseSnapshot.data!.docs;
              int totalSpent = 0;
              Map<String, int> categoryMap = {};
              final now = DateTime.now();

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['date'] == null) continue;
                final DateTime date = (data['date'] as Timestamp).toDate();
                
                if (date.month == now.month && date.year == now.year) {
                  int amount = data['amount'];
                  String category = data['category'];
                  totalSpent += amount;
                  
                  if (categoryMap.containsKey(category)) {
                    categoryMap[category] = categoryMap[category]! + amount;
                  } else {
                    categoryMap[category] = amount;
                  }
                }
              }

              if (_aiFeedbackFuture == null) {
                _aiFeedbackFuture = AiService().getFeedback(
                  goal: monthlyGoal,
                  spent: totalSpent,
                  categories: categoryMap,
                );
              }

              int savedAmount = monthlyGoal - totalSpent;
              double percent = monthlyGoal == 0 ? 0 : (totalSpent / monthlyGoal);
              if (percent > 1.0) percent = 1.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      savedAmount >= 0 ? "축하합니다! 목표 달성! 🎉" : "예산 초과... 😭",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      savedAmount >= 0 
                        ? "${NumberFormat('#,###').format(savedAmount)}원을 아끼셨네요."
                        : "${NumberFormat('#,###').format(savedAmount.abs())}원을 더 쓰셨네요.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    // === AI 분석 결과 ===
                    FutureBuilder<Map<String, String>>(
                      future: _aiFeedbackFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          // [1] 텍스트 로딩 중일 때
                          return _buildLoadingBox("AI가 가계부를 분석하고 있어요...");
                        } else if (snapshot.hasError) {
                          return const Text("분석 실패");
                        }

                        final comment = snapshot.data!['comment'] ?? "";
                        final keyword = snapshot.data!['keyword'] ?? "gift";
                        
                        // [2] 이미지 URL 최적화 (사이즈 줄여서 속도 향상)
                        // width=512, height=512, nologo=true 옵션 추가
                        final imageUrl = "https://image.pollinations.ai/prompt/$keyword?width=512&height=512&nologo=true";

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 2),
                          ),
                          child: Column(
                            children: [
                              // [3] 이미지 로딩 UI 개선
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  imageUrl,
                                  height: 250, // 이미지 키움
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  // 로딩 중일 때 보여줄 화면
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 250,
                                      width: double.infinity,
                                      color: Colors.grey[200],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text("AI 화가가 그림을 그리는 중... 🎨", 
                                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 250,
                                      color: Colors.grey[200],
                                      child: const Center(child: Text("이미지 로딩 실패")),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text("AI 금융 비서의 한마디", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                comment,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                    // 진행률 바
                    const Align(alignment: Alignment.centerLeft, child: Text("예산 사용률", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      color: savedAmount >= 0 ? Theme.of(context).colorScheme.primary : Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 5),
                    Align(alignment: Alignment.centerRight, child: Text("${(percent * 100).toInt()}%")),
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("확인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 로딩 박스 위젯
  Widget _buildLoadingBox(String text) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
