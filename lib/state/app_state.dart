import 'dart:io'; // 파일 처리를 위해 추가
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 사진 업로드용
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  User? _user;
  User? get user => _user;
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // 현재 선택된 날짜 (기본값: 오늘)
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  AppState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
    _loadTheme();
  }

  // --- 테마 모드 ---
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

  // --- 날짜 관련 기능 ---

  // 달 이동 시 날짜 유지 로직 (예: 11/29 -> 12/29)
  void changeMonth(int offset) {
    int newYear = _selectedDate.year;
    int newMonth = _selectedDate.month + offset;
    
    // 이동하려는 달의 마지막 날짜 구하기 (예: 2월은 28일)
    int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    
    // 현재 일(day)이 그 달의 마지막 날보다 크면 마지막 날로 조정
    int newDay = _selectedDate.day;
    if (newDay > lastDayOfNewMonth) {
      newDay = lastDayOfNewMonth;
    }

    _selectedDate = DateTime(newYear, newMonth, newDay);
    notifyListeners();
  }

  // 오늘 날짜로 복귀
  void resetToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  // --- 인증 및 계정 관리 기능 ---

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

  // [추가됨] 프로필 정보 업데이트 (직업, 사진 등)
  Future<void> updateProfile({String? job, File? imageFile, Function(String)? onError}) async {
    final user = _user;
    if (user == null) return;

    try {
      String? photoUrl;

      // 1. 이미지가 있으면 Firebase Storage에 업로드
      if (imageFile != null) {
        // 파일 경로: profile_images/{uid}.jpg
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');
        
        await ref.putFile(imageFile); // 파일 업로드
        photoUrl = await ref.getDownloadURL(); // 다운로드 가능한 URL 받기
      }

      // 2. Firestore 'users' 컬렉션에 정보 저장
      Map<String, dynamic> data = {};
      if (job != null) data['job'] = job;
      if (photoUrl != null) data['photoUrl'] = photoUrl;

      if (data.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          data, 
          SetOptions(merge: true), // 기존 데이터(목표 금액 등) 유지하면서 업데이트
        );
      }
      
      notifyListeners();
    } catch (e) {
      if (onError != null) onError("프로필 저장 실패: $e");
    }
  }

  // [추가됨] 비밀번호 변경
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

  // --- 지출 및 예산 관리 기능 ---

  Future<void> addExpense(int amount, String category, String note, DateTime date, Function() onSuccess) async {
    final user = _user;
    if (user == null) return;
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
    } catch (e) {
      print("저장 실패: $e");
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
