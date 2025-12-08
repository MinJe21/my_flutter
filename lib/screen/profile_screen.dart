import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _jobController = TextEditingController();
  final _picker = ImagePicker();
  File? _imageFile; // 갤러리에서 선택한 임시 파일
  bool _isLoading = false;

  @override
  void dispose() {
    _jobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          "내 프로필",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Firestore에서 내 정보(직업, 사진URL) 실시간 감시
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String job = "";
          String? photoUrl;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            job = data['job'] ?? "";
            photoUrl = data['photoUrl'];
            
            // 컨트롤러 초기값 설정 (입력 중이 아닐 때만 업데이트)
            if (_jobController.text.isEmpty && job.isNotEmpty) {
              _jobController.text = job;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 1. 프로필 사진 (클릭 시 변경)
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      // 사진 표시 원
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!) // 방금 갤러리에서 고른 사진
                            : (photoUrl != null 
                                ? NetworkImage(photoUrl) // DB에 저장된 사진
                                : null), // 없으면 기본색
                        child: (_imageFile == null && photoUrl == null)
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      // 카메라 아이콘 (우측 하단)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 2. 이메일 (수정 불가)
                _buildInfoField("이메일", user?.email ?? "", isReadOnly: true),
                const SizedBox(height: 20),

                // 3. 직업 입력 (수정 가능)
                _buildInfoField("직업 / 하는 일", "예: 대학생, 디자이너", controller: _jobController),
                
                const SizedBox(height: 10),
                
                // 정보 저장 버튼
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _saveProfile(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("정보 저장", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),

                // 4. 비밀번호 변경 버튼
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.lock_reset, color: Colors.redAccent),
                  ),
                  title: const Text("비밀번호 변경", style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => _showPasswordChangeDialog(context),
                ),
                
                const SizedBox(height: 10),

                // 5. 로그아웃 버튼
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.logout, color: Colors.black54),
                  ),
                  title: const Text("로그아웃", style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    context.read<AppState>().signOut();
                    Navigator.pop(context); // 홈 화면으로 나가면서 로그인 화면으로 전환됨
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 기능 함수들 ---

  // 이미지 선택 함수
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("이미지 선택 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("갤러리 접근 권한을 확인해주세요.")));
    }
  }

  // 프로필 저장 함수
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    await context.read<AppState>().updateProfile(
      job: _jobController.text,
      imageFile: _imageFile,
      onError: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );

    setState(() {
      _isLoading = false;
      // 이미지는 업로드 후 URL로 보여줄 것이므로 임시 파일은 초기화해도 됨 (선택사항)
      // _imageFile = null; 
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("프로필이 저장되었습니다! ✅")));
    }
  }

  // 비밀번호 변경 모달창
  void _showPasswordChangeDialog(BuildContext context) {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("비밀번호 변경"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "새 비밀번호 (6자 이상)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 6) ? "6자 이상 입력하세요." : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "비밀번호 확인",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v != passwordCtrl.text ? "비밀번호가 일치하지 않습니다." : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("취소", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                context.read<AppState>().changePassword(
                  passwordCtrl.text,
                  (msg) { // 성공 시
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  (msg) { // 실패 시
                    Navigator.pop(context); // 에러나도 창 닫고 스낵바 표시
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                  },
                );
              }
            },
            child: const Text("변경", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 입력칸 위젯 빌더
  Widget _buildInfoField(String label, String hint, {TextEditingController? controller, bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: isReadOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
