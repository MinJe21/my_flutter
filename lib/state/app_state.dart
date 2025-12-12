import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  User? _user;
  User? get user => _user;
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  AppState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  void changeMonth(int offset) {
    int newYear = _selectedDate.year;
    int newMonth = _selectedDate.month + offset;
    
    int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    
    int newDay = _selectedDate.day;
    if (newDay > lastDayOfNewMonth) {
      newDay = lastDayOfNewMonth;
    }

    _selectedDate = DateTime(newYear, newMonth, newDay);
    notifyListeners();
  }

  void resetToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> signIn(String email, String password, Function(String) onError, [Function()? onSuccess]) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      onSuccess?.call();
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? '로그인 실패');
    }
  }

  Future<void> signUp(String email, String password, Function(String) onError, Function() onSuccess) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      onSuccess();
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? '회원가입 실패');
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> updateProfile({String? job, File? imageFile, Function(String)? onError}) async {
    final user = _user;
    if (user == null) return;

    try {
      String? photoUrl;

      if (imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');
        
        await ref.putFile(imageFile); 
        photoUrl = await ref.getDownloadURL(); 
      }

      Map<String, dynamic> data = {};
      if (job != null) data['job'] = job;
      if (photoUrl != null) data['photoUrl'] = photoUrl;

      if (data.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          data, 
          SetOptions(merge: true), 
        );
      }
      
      notifyListeners();
    } catch (e) {
      if (onError != null) onError("프로필 저장 실패: $e");
    }
  }

  Future<void> changePassword(String newPassword, Function(String) onSuccess, Function(String) onError) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.updatePassword(newPassword);
      onSuccess("비밀번호가 변경되었습니다.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        onError("보안을 위해 로그아웃 후 다시 로그인해서 시도해주세요.");
      } else {
        onError("비밀번호 변경 실패: ${e.message}");
      }
    } catch (e) {
      onError("오류가 발생했습니다: $e");
    }
  }

  Future<bool> addExpense(int amount, String category, String note, DateTime date, Function() onSuccess) async {
    final user = _user;
    if (user == null) return false;
    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'uid': user.uid,
        'amount': amount,
        'category': category,
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      });
      onSuccess();
      notifyListeners();
      return true;
    } catch (e) {
      print("저장 실패: $e");
      return false;
    }
  }

  Future<void> updateMonthlyGoal(int goal) async {
    final user = _user;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'monthly_goal': goal,
    }, SetOptions(merge: true));
    notifyListeners();
  }

  Future<void> updateExpense(String docId, int amount, String category, String note) async {
    await FirebaseFirestore.instance.collection('expenses').doc(docId).update({
      'amount': amount,
      'category': category,
      'note': note,
    });
    notifyListeners();
  }

  Future<void> deleteExpense(String docId) async {
    await FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
    notifyListeners();
  }
}
