import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('About'),
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
          const SizedBox(height: AppSizes.lg),
          _Section(
            title: 'Our story',
            child: Text(
              'Dawat started as a small family kitchen helping neighbours host '
              'memorable gatherings. Today, we connect homes and event venues '
              'with curated caterers across India — from Rajasthani thalis to '
              'coastal seafood, Sattvik pure-veg to Mughlai tandoors.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const _Divider(),
          _Section(
            title: 'What we do',
            child: Column(
              children: const [
                _BulletRow(
                  icon: Icons.restaurant_menu_rounded,
                  iconBg: AppColors.primarySoft,
                  iconColor: AppColors.primary,
                  title: 'Curated caterers',
                  subtitle:
                      'Every partner restaurant is verified for hygiene, taste, and reliability.',
                ),
                _BulletRow(
                  icon: Icons.event_available_rounded,
                  iconBg: AppColors.catBlueLt,
                  iconColor: AppColors.catBlue,
                  title: 'Event-first ordering',
                  subtitle:
                      'Plan ahead — pick a date, guest count, and menu. Pay securely, schedule delivery.',
                ),
                _BulletRow(
                  icon: Icons.delivery_dining_rounded,
                  iconBg: AppColors.catGreenLt,
                  iconColor: AppColors.catGreen,
                  title: 'Trusted delivery',
                  subtitle:
                      'Our partner riders handle pickup, route, and handover with OTP confirmation.',
                ),
                _BulletRow(
                  icon: Icons.support_agent_rounded,
                  iconBg: AppColors.catGoldLt,
                  iconColor: AppColors.catGold,
                  title: 'Human support',
                  subtitle:
                      'Real people — available through the app whenever you need a hand.',
                ),
              ],
            ),
          ),
          const _Divider(),
          const _StatsRow(),
          const _Divider(),
          _Section(
            title: 'Our values',
            child: Column(
              children: const [
                _ValueRow(
                  label: 'Freshness first',
                  detail:
                      'We work only with kitchens that cook to order and deliver hot.',
                ),
                _ValueRow(
                  label: 'Honest pricing',
                  detail:
                      'Per-plate rates, delivery fees, and taxes — all shown up front.',
                ),
                _ValueRow(
                  label: 'Safe handling',
                  detail:
                      'Every order is packed, sealed, and tracked end-to-end.',
                ),
                _ValueRow(
                  label: 'Local flavour',
                  detail:
                      'From regional festivals to everyday meals — we celebrate India\'s food heritage.',
                ),
              ],
            ),
          ),
          const _Divider(),
          const _CompanyCard(),
          const SizedBox(height: AppSizes.lg),
          const _FooterLinks(),
          const SizedBox(height: AppSizes.xl),
          Center(
            child: Text(
              'Made with ❤ in India',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Center(
            child: Text(
              'v1.0.0  ·  © 2026 Dawat',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/dawat.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('🍽', style: TextStyle(fontSize: 32)),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Dawat',
            style: AppTextStyles.display.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Crafted catering, delivered.',
            style: AppTextStyles.bodyBold.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'We help you host memorable events with authentic Indian catering '
            'from trusted local kitchens — ordered, tracked, and delivered '
            'right from your phone.',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Sections ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading1),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        child: Divider(color: AppColors.divider, height: 1),
      );
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(title, style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.detail});
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSizes.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(detail,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Stats ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: const [
          _StatTile(value: '1,000+', label: 'Caterers'),
          SizedBox(width: AppSizes.md),
          _StatTile(value: '34', label: 'Cities'),
          SizedBox(width: AppSizes.md),
          _StatTile(value: '23k+', label: 'Dishes'),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.displaySm
                    .copyWith(color: AppColors.primary, fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Company / Footer ─────────────────────────

class _CompanyCard extends StatelessWidget {
  const _CompanyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding, vertical: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dawat Technologies Pvt. Ltd.', style: AppTextStyles.heading2),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Registered office: Hyderabad, India',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.sm + 2),
          _InfoLine(icon: Icons.email_rounded, text: 'hello@dawat.app'),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.phone_rounded, text: '+91 80000 12345'),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.public_rounded, text: 'www.dawat.app'),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.sm),
        Text(text,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  Future<void> _open(BuildContext context, String url) async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSizes.md,
        runSpacing: AppSizes.sm,
        children: [
          _FooterLink(
            label: 'Terms',
            onTap: () => _open(context, 'https://dawat.app/terms'),
          ),
          _FooterLink(
            label: 'Privacy',
            onTap: () => _open(context, 'https://dawat.app/privacy'),
          ),
          _FooterLink(
            label: 'Refund policy',
            onTap: () => _open(context, 'https://dawat.app/refunds'),
          ),
          _FooterLink(
            label: 'Licenses',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Dawat',
              applicationVersion: 'v1.0.0',
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm, vertical: AppSizes.xs),
        child: Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
