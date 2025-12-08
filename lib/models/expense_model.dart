import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final int amount; // 금액
  final String category; // 카테고리 (음식, 교통, 여가 등)
  final DateTime date; // 날짜
  final String note; // 메모

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  // 나중에 Firestore 데이터를 앱에서 쓸 수 있게 변환하는 기능
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: data['amount'] ?? 0,
      category: data['category'] ?? '기타',
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] ?? '',
    );
  }
}