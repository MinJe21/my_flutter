import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("지출 상세")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .where('uid', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // 날짜별로 지출 내역 그룹화 (달력에 점 찍기용)
          Map<DateTime, List<dynamic>> events = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final DateTime date = (data['date'] as Timestamp).toDate();
            // 시간 정보 날리고 날짜만 키로 사용
            final dateKey = DateTime(date.year, date.month, date.day);
            if (events[dateKey] == null) events[dateKey] = [];
            events[dateKey]!.add(data);
          }

          return Column(
            children: [
              // 1. 캘린더 위젯
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                
                // 날짜 클릭 시 이벤트
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  // 클릭하자마자 하단 모달 띄우기
                  _showExpenseModal(context, selectedDay, docs);
                },
                
                // 달력 스타일 꾸미기
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.7), shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                
                // 점 찍기 (지출 있는 날 표시)
                eventLoader: (day) {
                  final dateKey = DateTime(day.year, day.month, day.day);
                  return events[dateKey] ?? [];
                },
              ),
              const SizedBox(height: 20),
              const Text("날짜를 누르면 상세 내역을 볼 수 있습니다.", style: TextStyle(color: Colors.grey)),
            ],
          );
        },
      ),
    );
  }

  // === 2. 날짜 클릭 시 뜨는 모달 (지출 리스트) ===
  void _showExpenseModal(BuildContext context, DateTime date, List<QueryDocumentSnapshot> allDocs) {
    // 선택된 날짜의 데이터만 필터링
    final dayDocs = allDocs.where((doc) {
      final d = (doc['date'] as Timestamp).toDate();
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 화면 반 이상 올라오게
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.5, // 화면 절반 높이
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text(
                DateFormat('yyyy.MM.dd').format(date),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 지출 리스트
              Expanded(
                child: dayDocs.isEmpty
                    ? const Center(child: Text("지출 내역이 없습니다."))
                    : ListView.builder(
                        itemCount: dayDocs.length,
                        itemBuilder: (context, index) {
                          final doc = dayDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
                              ),
                              title: Text(data['category'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(data['note'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${NumberFormat('#,###').format(data['amount'])}원',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  // 수정 버튼 (연필 아이콘)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                    onPressed: () {
                                      Navigator.pop(context); // 리스트 닫고
                                      _showEditDialog(context, doc.id, data); // 수정창 열기
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === 3. 수정하기 모달 (입력창) ===
  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final amountCtrl = TextEditingController(text: data['amount'].toString());
    final categoryCtrl = TextEditingController(text: data['category']);
    final noteCtrl = TextEditingController(text: data['note']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("지출 수정"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "금액"),
            ),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: "카테고리"),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "메모"),
            ),
          ],
        ),
        actions: [
          // 삭제 버튼
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteExpense(docId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제되었습니다.")));
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
          // 수정 완료 버튼
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().updateExpense(
                docId,
                int.parse(amountCtrl.text),
                categoryCtrl.text,
                noteCtrl.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정되었습니다.")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text("수정 완료", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
