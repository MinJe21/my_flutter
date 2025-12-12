import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final int amount; 
  final String category; 
  final DateTime date; 
  final String note; 

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

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