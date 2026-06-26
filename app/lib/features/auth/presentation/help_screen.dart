import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_controller.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        ref.watch(authControllerProvider).valueOrNull?.isAdmin ?? false;
    final cards = isAdmin ? _adminCards : _guestCards;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(isAdmin ? '调酒师说明' : '使用说明'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
        children: cards
            .map(
              (card) => _HelpCard(
                icon: card.icon,
                title: card.title,
                body: card.body,
              ),
            )
            .toList(),
      ),
    );
  }
}

const _guestCards = [
  _HelpContent(
    icon: Icons.map_outlined,
    title: '先看吧台状态',
    body: '酒单首页会显示当前吧台状态：空闲代表可以正常点单，忙碌代表可能需要多等一会儿，未营业时建议先别下单。',
  ),
  _HelpContent(
    icon: Icons.local_bar,
    title: '看酒单',
    body: '酒单支持按名称、英文名和分类搜索，也可以点分类标签快速筛选。点开酒品详情可以看描述、酒精度、分类、出杯材料、缺料提醒和其他人的评价。',
  ),
  _HelpContent(
    icon: Icons.shopping_bag_outlined,
    title: '加入已选',
    body:
        '在酒单卡片或详情页点“+”即可加入底部“已选”。同一款酒可以连续点多次，适合帮朋友一起点；点开“已选”可以查看明细、增减杯数、删除单品，确认无误后点“确认”统一下单。',
  ),
  _HelpContent(
    icon: Icons.warning_amber_rounded,
    title: '缺料怎么处理',
    body:
        '如果某款酒缺少原料，酒单和详情页会明确标出“需自备”。继续加入已选并下单时，系统会把“用户自备原料：xxx”写入订单备注。你不想自备的话，直接换一款有料的酒就行。',
  ),
  _HelpContent(
    icon: Icons.receipt_long,
    title: '看订单进度',
    body:
        '订单只有三个关键阶段：待接单、制作中、已完成。待接单时可以取消；接单后进入制作中；完成后订单进入历史订单，并会在订单页顶部短暂提示“酒好了”。',
  ),
  _HelpContent(
    icon: Icons.rate_review_outlined,
    title: '评价和回看',
    body:
        '已完成订单会保留在历史订单里。你可以点“去评价”发布文字、表情和图片；之后也能在“我的”里的酒馆轨迹中回看历史订单、我的评价和喜欢的酒。',
  ),
  _HelpContent(
    icon: Icons.favorite_border,
    title: '喜欢的酒',
    body: '在酒品详情右上角点爱心可以加入“我的喜欢”。喜欢是按账号隔离的，以后想复点时，从“我的喜欢”进去会更快。',
  ),
  _HelpContent(
    icon: Icons.forum_outlined,
    title: '社区怎么用',
    body: '社区分为本店、官方和生活。你可以发酒后感、吐槽、照片和日常内容，也可以给别人的帖子点赞；自己的帖子支持编辑和删除。',
  ),
  _HelpContent(
    icon: Icons.person_outline,
    title: '维护个人资料',
    body: '在“我的”页可以维护头像、背景图、昵称和个性签名；设置入口里可以修改密码、查看隐私政策和酒品声明。',
  ),
];

const _adminCards = [
  _HelpContent(
    icon: Icons.dashboard_customize_outlined,
    title: '维护吧台状态',
    body: '在“我的”页的吧台维护入口可以切换空闲、忙碌、未营业。这个状态会展示在顾客酒单首页，用来控制顾客预期。',
  ),
  _HelpContent(
    icon: Icons.local_bar,
    title: '维护酒单',
    body:
        '酒单页可以新增酒品；每张酒品卡右上角可以进入编辑。建议补齐名称、描述、分类、ABV、图片、原料和配方步骤。配方步骤只对调酒师可见，不会暴露给顾客。',
  ),
  _HelpContent(
    icon: Icons.image_outlined,
    title: '上传酒品图片',
    body: '编辑酒品时可以上传图片并按规定比例裁切。上传后酒单卡片和详情页会自动适配显示区域；如果图片主体偏移，可以在裁切页缩放和移动后再确认。',
  ),
  _HelpContent(
    icon: Icons.inventory_2_outlined,
    title: '维护库存',
    body:
        '备货清单里可以切换原料是否有货，也可以新增基酒、糖浆和辅料。某个必需原料缺货后，相关酒品会在顾客侧显示“需自备”，下单备注也会自动写入缺料内容。',
  ),
  _HelpContent(
    icon: Icons.receipt_long,
    title: '处理订单',
    body:
        '订单页按待接单、制作中、历史订单展示。待接单可以选择“接单”或“不接单”；接单后进入制作中；制作完成后点“标记完成”，顾客侧会短暂看到“酒好了”的提示。',
  ),
  _HelpContent(
    icon: Icons.rate_review_outlined,
    title: '查看订单和评价',
    body: '“我的”里的酒馆轨迹会展示全部顾客的历史订单和评价。调酒师可以按用户查看，也可以删除不合适的订单或评论。',
  ),
  _HelpContent(
    icon: Icons.forum_outlined,
    title: '管理社区',
    body: '社区分为本店、官方和生活。调酒师可以发布官方通知，也可以删除不合适的社区内容；顾客只能编辑或删除自己发布的内容。',
  ),
  _HelpContent(
    icon: Icons.storage_outlined,
    title: '数据库 GUI',
    body:
        '“我的”页中提供数据库可视化入口，用于管理用户、酒品、原料、订单、评价和社区等数据。这里会直接写入数据库，删除和修改前请确认对象没选错。',
  ),
  _HelpContent(
    icon: Icons.security_outlined,
    title: '账号与安全',
    body: '设置入口可以修改密码、查看隐私政策和酒品声明。管理员账号不要外借；如果要给其他人调试，请使用普通顾客账号。',
  ),
];

class _HelpContent {
  const _HelpContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        borderRadius: 18,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BarColors.neonGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(
                      color: BarColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
