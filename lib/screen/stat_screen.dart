import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatScreen extends StatefulWidget {
  const StatScreen({super.key});

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
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
            Map<String, int> categoryStats = {};
            final now = DateTime.now();

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['date'] == null) continue;
              final DateTime date = (data['date'] as Timestamp).toDate();
              
              if (date.month == now.month && date.year == now.year) {
                int amount = data['amount'];
                String category = data['category'];
                
                totalSpent += amount;
                
                if (categoryStats.containsKey(category)) {
                  categoryStats[category] = categoryStats[category]! + amount;
                } else {
                  categoryStats[category] = amount;
                }
              }
            }

            double percent = monthlyGoal == 0 ? 0 : (totalSpent / monthlyGoal * 100);
            if (percent > 100) percent = 100;

            // 그래프 Y축 최대값 계산
            double maxY = 1000;
            if (categoryStats.isNotEmpty) {
              maxY = categoryStats.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2;
            }

            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.background,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("이번달 예산 사용률", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // 1. 원형 차트 (Pie Chart)
                    SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 70,
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  color: Theme.of(context).colorScheme.primary,
                                  value: percent,
                                  title: '',
                                  radius: 20,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  color: Colors.grey[200],
                                  value: 100 - percent,
                                  title: '',
                                  radius: 20,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${percent.toInt()}%',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                ),
                                const Text("사용됨", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '${NumberFormat('#,###').format(totalSpent)}원 / ${NumberFormat('#,###').format(monthlyGoal)}원',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 30),

                    // 2. 막대 차트 (Bar Chart) - 디자인 개선됨
                    const Text("카테고리별 지출 비교", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    
                    if (categoryStats.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("아직 데이터가 없습니다."),
                      ))
                    else
                      SizedBox(
                        height: 250,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            
                            // [A] 터치 툴팁 디자인
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.9),
                                tooltipPadding: const EdgeInsets.all(8),
                                tooltipMargin: 8,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                   String catName = categoryStats.keys.elementAt(group.x.toInt());
                                   return BarTooltipItem(
                                     '$catName\n',
                                     const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                     children: [
                                       TextSpan(
                                         text: '${NumberFormat('#,###').format(rod.toY)}원',
                                         style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                                       ),
                                     ],
                                   );
                                },
                              ),
                            ),
                            
                            // [B] 축 타이틀 (하단 글씨)
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40, // 공간 확보로 겹침 방지
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    if (value.toInt() >= categoryStats.length) return const SizedBox.shrink();
                                    
                                    String text = categoryStats.keys.elementAt(value.toInt());
                                    if (text.length > 3) text = text.substring(0, 3);
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85), 
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            
                            // [C] 배경 격자선 (점선)
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxY / 5,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.2),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                );
                              },
                            ),
                            
                            // [D] 테두리 (바닥선만)
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                              ),
                            ),
                            
                            // [E] 막대 데이터 (그라데이션 & 둥근 모서리)
                            barGroups: categoryStats.entries.toList().asMap().entries.map((entry) {
                              int index = entry.key;
                              int amount = entry.value.value;
                              
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: amount.toDouble(),
                                    // 그라데이션 적용
                                    gradient: LinearGradient(
                                      colors: [
                                        _getCategoryColor(context, index).withOpacity(0.6),
                                        _getCategoryColor(context, index),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 24, // 두께 증가
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), // 둥근 모서리
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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

  // 색상 팔레트
  Color _getCategoryColor(BuildContext context, int index) {
    final Color primary = Theme.of(context).colorScheme.primary;
    List<Color> colors = [
      primary,
      const Color(0xFF8D99AE), // muted blue gray
      const Color(0xFFB3B7BD), // light gray
      const Color(0xFF74828F), // slate
      const Color(0xFF566573), // deep gray
    ];
    return colors[index % colors.length];
  }
}
