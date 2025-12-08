import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷용
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // 입력값 관리용 컨트롤러
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  
  // 날짜 선택 (기본값: 오늘)
  DateTime _selectedDate = DateTime.now();

  // 날짜 선택기 띄우기
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 저장 버튼 클릭 시 실행
  void _saveExpense() {
    if (_amountController.text.isEmpty || _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액과 카테고리를 입력해주세요.')),
      );
      return;
    }

    // AppState를 통해 Firestore에 저장
    context.read<AppState>().addExpense(
      int.parse(_amountController.text), // 문자를 숫자로 변환
      _categoryController.text,
      _noteController.text,
      _selectedDate,
      () {
        // 성공 시 할 일
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지출이 기록되었습니다! ✅')),
        );
        // 입력창 초기화
        _amountController.clear();
        _categoryController.clear();
        _noteController.clear();
        setState(() {
          _selectedDate = DateTime.now();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // 1. 날짜 입력 (Date)
            _buildLabel('Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MM/dd/yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_month, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 지출액 입력 (Amount)
            _buildLabel('지출액'),
            _buildTextField(
              controller: _amountController,
              hint: '금액을 입력하세요 (예: 13000)',
              isNumber: true,
            ),
            const SizedBox(height: 24),

            // 3. 카테고리 입력 (Category)
            _buildLabel('카테고리'),
            _buildTextField(
              controller: _categoryController,
              hint: '예: 음식, 교통, 쇼핑',
            ),
            const SizedBox(height: 24),

            // 4. 메모 입력 (Note)
            _buildLabel('Note'),
            Container(
              height: 120, // 메모장은 좀 높게
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: null, // 여러 줄 입력 가능
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '메모를 입력하세요...',
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 5. 저장 버튼
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.send),
                label: const Text('저장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 라벨 위젯 (보라색 작은 글씨)
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // 입력창 위젯 (공통 스타일)
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () => controller.clear(),
          ),
        ),
      ),
    );
  }
}
