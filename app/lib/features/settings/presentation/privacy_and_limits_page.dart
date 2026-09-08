import 'package:flutter/material.dart';

class PrivacyAndLimitsPage extends StatelessWidget {
  const PrivacyAndLimitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与已知限制')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _BoundaryCard(
            icon: Icons.lock_outline,
            title: '数据保存在本机',
            body: '无需账号，海缸记录保存在本机。你可主动导出备份；备份不含检测照片，请妥善保管。',
          ),
          _BoundaryCard(
            icon: Icons.camera_alt_outlined,
            title: '拍照仅作辅助',
            body: '照片仅在本机临时处理，确认或取消后删除。比色结果仅供参考，可修改后保存。',
          ),
          _BoundaryCard(
            icon: Icons.health_and_safety_outlined,
            title: '异常时先复测',
            body: '维护建议依据检测记录和目标范围。加药前请复测，出现持续浑浊或生物异常时停止。',
          ),
          _BoundaryCard(
            icon: Icons.notifications_none,
            title: '系统提醒可能延迟',
            body: '通知受系统权限、省电设置和设备状态影响；未收到提醒时，可在任务页查看。',
          ),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, semanticLabel: title),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
