import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 임시 알림 데이터
    final List<Map<String, String>> notifications = [
      {'title': '목표 달성 축하!', 'time': '방금 전', 'content': '이번 달 목표 금액을 훌륭하게 지키고 계시네요! 🎉'},
      {'title': '지출 경고', 'time': '2시간 전', 'content': '식비 카테고리 예산이 80% 소진되었습니다.'},
      {'title': '새로운 기능 추가', 'time': '1일 전', 'content': '이제 AI가 절약 팁을 알려줘요!'},
    ];

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        title: const Text("알림"),
        backgroundColor: scheme.background,
        foregroundColor: scheme.onBackground,
        surfaceTintColor: scheme.background,
        elevation: 0,
      ),
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (context, index) => Divider(color: scheme.onSurfaceVariant.withOpacity(0.2)),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: scheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.notifications, color: scheme.primary),
            ),
            title: Text(
              item['title']!,
              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
            subtitle: Text(
              item['content']!,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            trailing: Text(
              item['time']!,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            onTap: () {
              // 알림 클릭 시 동작 (나중에 구현)
            },
          );
        },
      ),
    );
  }
}
