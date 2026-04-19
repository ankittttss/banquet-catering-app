import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _query = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _faqs
        .where((f) =>
            _search.isEmpty ||
            f.question.toLowerCase().contains(_search.toLowerCase()) ||
            f.answer.toLowerCase().contains(_search.toLowerCase()))
        .toList(growable: false);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.profile),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.xxxl),
        children: [
          const _Hero()
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding, vertical: AppSizes.sm),
            child: _SearchField(
              controller: _query,
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const _QuickActionsGrid(),
          const SizedBox(height: AppSizes.md),
          _SectionTitle(
            title: _search.isEmpty
                ? 'Frequently asked'
                : 'Results (${filtered.length})',
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding, vertical: AppSizes.lg),
              child: Text(
                'No FAQs matched "$_search". Try different keywords, or contact us directly below.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            for (final f in filtered) _FaqTile(item: f),
          const SizedBox(height: AppSizes.lg),
          const _ContactCard(),
          const SizedBox(height: AppSizes.md),
          const _EmergencyCard(),
          const SizedBox(height: AppSizes.xl),
          Center(
            child: Text(
              'Average response time: under 10 min',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Hero ─────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding, AppSizes.md, AppSizes.pagePadding, 0),
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: AppTextStyles.displaySm.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Answers to common questions, and a direct line to our team.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Search ─────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Search for a topic — e.g. refund, delivery',
        hintStyle:
            AppTextStyles.body.copyWith(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ───────────────────────── Quick actions ─────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSizes.md,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 1.6,
        children: [
          _QuickActionCard(
            icon: Icons.receipt_long_rounded,
            label: 'Order issues',
            iconBg: AppColors.primarySoft,
            iconColor: AppColors.primary,
            onTap: () => context.push(AppRoutes.myEvents),
          ),
          _QuickActionCard(
            icon: Icons.delivery_dining_rounded,
            label: 'Track delivery',
            iconBg: AppColors.catGreenLt,
            iconColor: AppColors.catGreen,
            onTap: () => context.push(AppRoutes.myEvents),
          ),
          _QuickActionCard(
            icon: Icons.payments_rounded,
            label: 'Refunds & billing',
            iconBg: AppColors.catGoldLt,
            iconColor: AppColors.catGold,
            onTap: () => _scrollToFaq(context, 'refund'),
          ),
          _QuickActionCard(
            icon: Icons.account_circle_rounded,
            label: 'Account & login',
            iconBg: AppColors.catBlueLt,
            iconColor: AppColors.catBlue,
            onTap: () => _scrollToFaq(context, 'account'),
          ),
        ],
      ),
    );
  }

  void _scrollToFaq(BuildContext context, String topic) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Scroll down to see $topic topics'),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md + 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Text(label, style: AppTextStyles.bodyBold),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── FAQ ─────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, AppSizes.md,
          AppSizes.pagePadding, AppSizes.sm),
      child: Text(title, style: AppTextStyles.heading1),
    );
  }
}

class _FaqItem {
  const _FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

const _faqs = <_FaqItem>[
  _FaqItem(
    'How do I place an order?',
    'Pick a caterer or a dish, choose your event date and guest count on the '
        'item screen, add to cart, then check out. You\'ll see delivery fees '
        'and taxes up front — no surprises at the end.',
  ),
  _FaqItem(
    'When will my delivery arrive?',
    'For scheduled events, delivery begins 30–45 minutes before your booked '
        'slot. For on-demand orders, expect arrival within the delivery window '
        'shown on the restaurant card.',
  ),
  _FaqItem(
    'How do I cancel an order?',
    'Go to My orders → pick the order → Cancel. Cancellations are free up to '
        '60 minutes before the delivery slot. Later cancellations may incur '
        'a partial charge to cover kitchen prep.',
  ),
  _FaqItem(
    'How do refunds work?',
    'Approved refunds return to your original payment method in 5–7 working '
        'days. For UPI, it\'s usually same-day. You\'ll get a push notification '
        'the moment the refund is initiated.',
  ),
  _FaqItem(
    'Why can\'t I log in / I lost my OTP?',
    'Check your SMS inbox and spam folder. If the OTP didn\'t arrive within '
        '60 seconds, tap "Resend". Still stuck? Contact support and we can '
        'verify you via email and reset access.',
  ),
  _FaqItem(
    'Is there a minimum order?',
    'Each caterer sets its own minimum guest count (usually 5–20). You\'ll '
        'see this clearly on the restaurant page before you start adding items.',
  ),
  _FaqItem(
    'How do I update my delivery address?',
    'From Profile → Saved addresses, tap + to add a new one, or edit an '
        'existing address. You can also change the delivery address at '
        'checkout.',
  ),
  _FaqItem(
    'Are the caterers verified?',
    'Yes. Every partner on Dawat goes through hygiene checks, FSSAI license '
        'verification, and a trial order before going live. We continuously '
        'monitor ratings and remove partners that don\'t meet our bar.',
  ),
  _FaqItem(
    'Do you deliver in my city?',
    'We\'re live across 34 cities in India — if you can set a delivery '
        'address on the home screen, we\'re there. More cities are added '
        'every month.',
  ),
  _FaqItem(
    'How do I become a delivery partner?',
    'Delivery partners join through an admin invite. If you\'re interested, '
        'email hello@dawat.app with your city and vehicle details — the team '
        'will reach out.',
  ),
];

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _open = !_open);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.item.question,
                      style: AppTextStyles.bodyBold),
                ),
                const SizedBox(width: AppSizes.sm),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _open ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppSizes.sm + 2),
                child: Text(
                  widget.item.answer,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Contact card ─────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Still need help?', style: AppTextStyles.heading2),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Our support team is available every day, 8 AM–11 PM.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.md),
          _ContactRow(
            icon: Icons.chat_bubble_rounded,
            iconBg: AppColors.primarySoft,
            iconColor: AppColors.primary,
            title: 'Chat with us',
            subtitle: 'Fastest — typical reply in 10 min',
            onTap: () => _showComingSoon(context, 'Live chat'),
          ),
          _ContactRow(
            icon: Icons.email_rounded,
            iconBg: AppColors.catBlueLt,
            iconColor: AppColors.catBlue,
            title: 'hello@dawat.app',
            subtitle: 'Email — tap to copy',
            onTap: () => _copy(context, 'hello@dawat.app'),
          ),
          _ContactRow(
            icon: Icons.phone_rounded,
            iconBg: AppColors.catGreenLt,
            iconColor: AppColors.catGreen,
            title: '+91 80000 12345',
            subtitle: 'Phone — tap to copy',
            onTap: () => _copy(context, '+918000012345'),
            showBorder: false,
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $text')),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature opens soon — use email meanwhile')),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showBorder = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm + 2),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Emergency / Report ─────────────────────────

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        color: AppColors.catGoldLt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred_rounded,
              color: AppColors.accentDark, size: 22),
          const SizedBox(width: AppSizes.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report a serious issue',
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.accentDark)),
                const SizedBox(height: 2),
                Text(
                  'Food safety concern, missing items, or rider behaviour — '
                  'email urgent@dawat.app for priority handling.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.sm),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentDark,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await Clipboard.setData(
                        const ClipboardData(text: 'urgent@dawat.app'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied: urgent@dawat.app')),
                    );
                  },
                  child: const Text('Copy urgent email'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
