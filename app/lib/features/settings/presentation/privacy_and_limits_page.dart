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
            body:
                '首版不需要账号，也不上传海缸记录或检测照片。完整业务数据备份由你主动创建且不含照片；分享或复制后，其保管责任由接收位置决定。',
          ),
          _BoundaryCard(
            icon: Icons.camera_alt_outlined,
            title: '拍照仅作辅助',
            body:
                '拍照功能只在本机缓存中临时服务于实验性辅助比色，确认或取消后删除。当前真实样本不足，不能承诺准确率、确定误差或实验室级精度；最终结果必须由你确认。',
          ),
          _BoundaryCard(
            icon: Icons.health_and_safety_outlined,
            title: '不替代专业诊断',
            body:
                '维护建议只依据已确认记录、你设置的目标和已保存历史，不会自动控制设备，也不会提供具体药剂剂量。异常时请复测，并结合生物状态和可靠专业资料判断。',
          ),
          _BoundaryCard(
            icon: Icons.notifications_none,
            title: '系统提醒可能延迟',
            body: '通知权限被拒绝、系统省电、设备关机或平台调度限制可能造成提醒延迟或不显示；App 内任务到期状态仍以本地数据库为准。',
          ),
          _BoundaryCard(
            icon: Icons.science_outlined,
            title: '当前材料边界',
            body: 'NO3、PO4 使用对应的两行四色卡模板。请按试剂要求显色，并将照片旋转到正方向。结果为辅助估算，仅供参考。',
          ),
          _BoundaryCard(
            icon: Icons.devices_outlined,
            title: '平台验证状态',
            body:
                'Android 模拟器只能验证基础流程，不能代表真实相机成像或各品牌手机的后台通知。iOS 构建和真机流程仍需在 macOS、Xcode 与 iPhone 上验证。',
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
