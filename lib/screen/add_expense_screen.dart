import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isScanning = false;
  String? _scanResultMessage;
  
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

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

  Future<void> _saveExpense() async {
    final sanitizedAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitizedAmount.isEmpty || _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액과 카테고리를 입력해주세요.')),
      );
      return;
    }
    final parsedAmount = int.tryParse(sanitizedAmount);
    if (parsedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 숫자로 입력해주세요.')),
      );
      return;
    }

    final appState = context.read<AppState>();
    final success = await appState.addExpense(
      parsedAmount,
      _categoryController.text,
      _noteController.text,
      _selectedDate,
      () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지출이 기록되었습니다! ✅')),
        );
        appState.setSelectedDate(_selectedDate);
        _amountController.clear();
        _categoryController.clear();
        _noteController.clear();
        setState(() {
          _selectedDate = DateTime.now();
        });
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지출 저장에 실패했습니다. 로그인 상태와 네트워크를 확인해주세요.')),
      );
    }
  }

  Future<void> _showScanOptions() async {
    if (_isScanning) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('카메라로 스캔'),
                onTap: () => _startScan(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('갤러리에서 불러오기'),
                onTap: () => _startScan(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startScan(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _isScanning = true;
        _scanResultMessage = "영수증을 읽는 중입니다...";
      });

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      _applyRecognizedText(recognized.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("영수증을 읽는 중 오류가 발생했어요: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _applyRecognizedText(String rawText) {
    if (!mounted) return;
    final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final amount = _extractAmount(rawText);
    final date = _extractDate(rawText);
    final merchant = _extractMerchant(lines);
    final parts = <String>[
      if (date != null) "날짜: ${DateFormat('MM/dd/yyyy').format(date)}",
      if (amount != null) "금액: $amount",
      if (merchant != null) "상호: $merchant",
    ];

    setState(() {
      if (amount != null) _amountController.text = amount;
      if (date != null) _selectedDate = date;
      if (merchant != null && _noteController.text.isEmpty) {
        _noteController.text = merchant;
      }
      _scanResultMessage = parts.isEmpty ? "필요한 정보를 찾지 못했어요." : parts.join(' · ');
    });

    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("영수증에서 날짜/금액/상호를 찾지 못했어요.")),
      );
    }
  }

  String? _extractAmount(String text) {
    final lines = text.split('\n');
    final numberReg = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d{1,2})?');
    final keyword = RegExp(r'(합계|총액|총|금액|결제|카드|현금|amount|total)', caseSensitive: false);

    for (final line in lines) {
      if (!keyword.hasMatch(line)) continue;
      final matches = numberReg.allMatches(line);
      if (matches.isNotEmpty) {
        final raw = matches.last.group(0)!;
        final value = _normalizeNumber(raw);
        if (value != null) return value;
      }
    }

    double? candidate;
    for (final match in numberReg.allMatches(text)) {
      final normalized = _normalizeNumber(match.group(0)!);
      final parsed = normalized != null ? double.tryParse(normalized) : null;
      if (parsed == null) continue;
      if (parsed >= 100 && parsed <= 100000000) {
        if (candidate == null || parsed > candidate) candidate = parsed;
      }
    }

    return candidate?.round().toString();
  }

  DateTime? _extractDate(String text) {
    DateTime? buildDate(int year, int month, int day) {
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }

    final ymd = RegExp(r'(20\d{2})[./-](\d{1,2})[./-](\d{1,2})').firstMatch(text);
    if (ymd != null) {
      final year = int.tryParse(ymd.group(1) ?? '');
      final month = int.tryParse(ymd.group(2) ?? '');
      final day = int.tryParse(ymd.group(3) ?? '');
      if (year != null && month != null && day != null) return buildDate(year, month, day);
    }

    final korean = RegExp(r'(\d{4})년\s?(\d{1,2})월\s?(\d{1,2})일').firstMatch(text);
    if (korean != null) {
      final year = int.tryParse(korean.group(1) ?? '');
      final month = int.tryParse(korean.group(2) ?? '');
      final day = int.tryParse(korean.group(3) ?? '');
      if (year != null && month != null && day != null) return buildDate(year, month, day);
    }

    final mdy = RegExp(r'(\d{1,2})/(\d{1,2})/(20\d{2})').firstMatch(text);
    if (mdy != null) {
      final month = int.tryParse(mdy.group(1) ?? '');
      final day = int.tryParse(mdy.group(2) ?? '');
      final year = int.tryParse(mdy.group(3) ?? '');
      if (year != null && month != null && day != null) return buildDate(year, month, day);
    }

    final monthDayKorean = RegExp(r'(\d{1,2})월\s?(\d{1,2})일').firstMatch(text);
    if (monthDayKorean != null) {
      final now = DateTime.now();
      final month = int.tryParse(monthDayKorean.group(1) ?? '');
      final day = int.tryParse(monthDayKorean.group(2) ?? '');
      if (month != null && day != null) return buildDate(now.year, month, day);
    }

    final monthDay = RegExp(r'(\d{1,2})[./-](\d{1,2})').firstMatch(text);
    if (monthDay != null) {
      final now = DateTime.now();
      final month = int.tryParse(monthDay.group(1) ?? '');
      final day = int.tryParse(monthDay.group(2) ?? '');
      if (month != null && day != null) return buildDate(now.year, month, day);
    }
    return null;
  }

  String? _extractMerchant(List<String> lines) {
    final skipKeywords = ['영수증', '매출', '합계', '금액', 'total', 'amount', '결제', '카드', '승인', 'date', '시간'];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (skipKeywords.any((word) => lower.contains(word))) continue;
      if (RegExp(r'^\d').hasMatch(line)) continue;
      if (line.length < 2) continue;
      return line;
    }
    return null;
  }

  String? _normalizeNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp('[^0-9.]'), '').replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    return parsed?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            _buildLabel('Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 1.5),
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

            _buildLabel('영수증 스캔 (OCR)'),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary, width: 1.2),
                color: colorScheme.primary.withOpacity(0.06),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.primary.withOpacity(0.15),
                      child: Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
                    ),
                    title: const Text('사진 찍어서 자동 입력'),
                    subtitle: const Text('날짜·금액·상호를 자동으로 채워드려요.'),
                    trailing: _isScanning
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          )
                        : const Icon(Icons.qr_code_scanner_rounded),
                    onTap: _isScanning ? null : _showScanOptions,
                  ),
                  if (_scanResultMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        _scanResultMessage!,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildLabel('지출액'),
            _buildTextField(
              controller: _amountController,
              hint: '금액을 입력하세요 (예: 13000)',
              isNumber: true,
            ),
            const SizedBox(height: 24),

            _buildLabel('카테고리'),
            _buildTextField(
              controller: _categoryController,
              hint: '예: 음식, 교통, 쇼핑',
            ),
            const SizedBox(height: 24),

            _buildLabel('Note'),
            Container(
              height: 120, 
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '메모를 입력하세요...',
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary.withOpacity(0.15),
                  foregroundColor: colorScheme.primary,
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
