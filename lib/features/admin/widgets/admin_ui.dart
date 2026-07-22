import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Dawat Admin Console design system — a refined indigo identity, deliberately
/// distinct from the consumer app (which is red/gold). Ported natively from
/// the imported Claude Design "Dawat Admin Console" prototype.
///
/// Everything admin-facing composes from these primitives so the six admin
/// screens share one coherent look and a single responsive shell.
class AdminColors {
  AdminColors._();
  static const ink = Color(0xFF141230);
  static const ink2 = Color(0xFF2A265E);
  static const indigo = Color(0xFF4F46E5);
  static const indigo600 = Color(0xFF4338CA);
  static const indigo700 = Color(0xFF3730A3);
  static const indigo050 = Color(0xFFEEF0FF);
  static const indigo100 = Color(0xFFE0E3FF);

  static const bg = Color(0xFFF6F7FB);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E9F2);
  static const line2 = Color(0xFFEEF0F6);

  static const tx = Color(0xFF1B1A2E);
  static const tx2 = Color(0xFF5B5A72);
  static const tx3 = Color(0xFF8E8DA3);

  static const live = Color(0xFF059669);
  static const liveBg = Color(0xFFE6F6EF);
  static const draft = Color(0xFF64748B);
  static const draftBg = Color(0xFFEEF1F5);
  static const susp = Color(0xFFD97706);
  static const suspBg = Color(0xFFFDF1E3);
  static const arch = Color(0xFF94A3B8);
  static const archBg = Color(0xFFF1F3F7);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFDECEC);

  static const indigoA = Color(0xFFA5B4FC); // on-dark accent
}

/// Type scale (Plus Jakarta Sans — the app's default family).
class AdminText {
  AdminText._();
  static const display = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.15,
      color: AdminColors.tx);
  static const h1 = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.2,
      color: AdminColors.tx);
  static const h2 = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.3,
      color: AdminColors.tx);
  static const h3 = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: AdminColors.tx);
  static const body = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AdminColors.tx2);
  static const label = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.tx2);
  static const cap = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AdminColors.tx3);
  static const over = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      color: AdminColors.indigo);
}

/// Overline label ("MANAGE", "CUSTOMER PREVIEW", …).
class AdminOverline extends StatelessWidget {
  const AdminOverline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AdminText.over.copyWith(color: color),
      );
}

// ─────────────────────────── Status ───────────────────────────

class AdminStatusStyle {
  const AdminStatusStyle(this.label, this.fg, this.bg, {this.dot = false});
  final String label;
  final Color fg;
  final Color bg;
  final bool dot;
}

AdminStatusStyle adminStatusStyle(RestaurantStatus s) => switch (s) {
      RestaurantStatus.published => const AdminStatusStyle(
          'Live', AdminColors.live, AdminColors.liveBg,
          dot: true),
      RestaurantStatus.draft =>
        const AdminStatusStyle('Draft', AdminColors.draft, AdminColors.draftBg),
      RestaurantStatus.suspended => const AdminStatusStyle(
          'Suspended', AdminColors.susp, AdminColors.suspBg),
      RestaurantStatus.archived => const AdminStatusStyle(
          'Archived', AdminColors.arch, AdminColors.archBg),
    };

/// Status pill with an optional leading dot (used for "Live").
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key, required this.status, this.small = false});
  final RestaurantStatus status;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final s = adminStatusStyle(status);
    return AdminPill(
      label: s.label,
      fg: s.fg,
      bg: s.bg,
      small: small,
      dot: s.dot,
    );
  }
}

/// Generic coloured pill (status text, ACTIVE/INACTIVE, NO MAP PIN, …).
class AdminPill extends StatelessWidget {
  const AdminPill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.small = false,
    this.dot = false,
    this.icon,
  });
  final String label;
  final Color fg;
  final Color bg;
  final bool small;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10, vertical: small ? 2 : 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          if (icon != null) ...[
            Icon(icon, size: small ? 12 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Buttons ───────────────────────────

enum AdminBtn { primary, dark, ghost, soft, danger }

class AdminButton extends StatelessWidget {
  const AdminButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AdminBtn.primary,
    this.size = 'md',
    this.expand = false,
    this.leading,
    this.trailing,
    this.disabled = false,
    this.elevated = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AdminBtn variant;
  final String size; // sm | md | lg
  final bool expand;
  final IconData? leading;
  final IconData? trailing;
  final bool disabled;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final h = size == 'sm'
        ? 38.0
        : size == 'lg'
            ? 52.0
            : 46.0;
    final (bg, fg, border) = switch (variant) {
      AdminBtn.primary => (
          disabled ? const Color(0xFFC4C7D8) : AdminColors.indigo,
          Colors.white,
          null,
        ),
      AdminBtn.dark => (AdminColors.ink, Colors.white, null),
      AdminBtn.ghost => (AdminColors.card, AdminColors.tx, AdminColors.line),
      AdminBtn.soft => (AdminColors.indigo050, AdminColors.indigo600, null),
      AdminBtn.danger => (AdminColors.dangerBg, AdminColors.danger, null),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Icon(leading, size: 18, color: fg),
          const SizedBox(width: 8)
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Icon(trailing, size: 18, color: fg)
        ],
      ],
    );
    return Opacity(
      opacity: disabled ? 0.9 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: h,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: border == null ? null : Border.all(color: border),
              boxShadow: elevated && !disabled
                  ? [
                      BoxShadow(
                        color: AdminColors.indigo.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Card ───────────────────────────

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.background,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AdminColors.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A141230), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

// ─────────────────────────── Form field ───────────────────────────

class AdminField extends StatelessWidget {
  const AdminField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
    this.error,
  });
  final String label;
  final Widget child;
  final bool required;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: label,
                  style: AdminText.label,
                  children: required
                      ? const [
                          TextSpan(
                              text: ' *',
                              style: TextStyle(color: AdminColors.danger))
                        ]
                      : null,
                ),
              ),
            ),
            // Flexible so a longer hint wraps instead of overflowing the row
            // (an unbounded Text here would blow the label out on narrow
            // phones).
            if (hint != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    hint!,
                    style: AdminText.cap,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error!,
              style: AdminText.cap.copyWith(color: AdminColors.danger)),
        ],
      ],
    );
  }
}

/// Input decoration matching the design's 46px / 11-radius / 1.5 border input.
InputDecoration adminInput(String hint, {Widget? prefix, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintStyle: AdminText.body.copyWith(color: AdminColors.tx3),
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AdminColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AdminColors.indigo, width: 1.5),
      ),
    );

const adminTextStyle =
    TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AdminColors.tx);

// ─────────────────────────── Toggle ───────────────────────────

class AdminToggle extends StatelessWidget {
  const AdminToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AdminColors.live,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? activeColor : const Color(0xFFCBD0DE),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Veg / non-veg marker square used on dish rows.
class AdminVegMark extends StatelessWidget {
  const AdminVegMark({super.key, required this.isVeg});
  final bool isVeg;
  @override
  Widget build(BuildContext context) {
    final c = isVeg ? AdminColors.live : AdminColors.danger;
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: c,
          shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

// ─────────────────────────── Top bar ───────────────────────────

/// Sticky admin header (design's AcBar): indigo-tinted back button, title,
/// optional subtitle and a trailing action.
class AdminBar extends StatelessWidget {
  const AdminBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (onBack != null) ...[
              _SquareIconButton(
                icon: PhosphorIconsBold.arrowLeft,
                bg: AdminColors.indigo050,
                fg: AdminColors.indigo600,
                onTap: onBack!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.h1.copyWith(fontSize: 18)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.cap),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.size = 38,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

/// Square outlined icon button (e.g. the list "refresh" affordance).
class AdminIconButton extends StatelessWidget {
  const AdminIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _SquareIconButton(
        icon: icon,
        onTap: onTap,
        bg: AdminColors.card,
        fg: AdminColors.tx3,
        size: 36,
      );
}

// ─────────────────────────── FAB ───────────────────────────

class AdminFab extends StatelessWidget {
  const AdminFab(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon = PhosphorIconsBold.plus});
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.indigo,
      borderRadius: BorderRadius.circular(99),
      elevation: 6,
      shadowColor: AdminColors.indigo.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── States ───────────────────────────

/// Centered empty / error state (design's 72px rounded icon chip + copy).
class AdminMessageState extends StatelessWidget {
  const AdminMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconFg = AdminColors.indigo,
    this.iconBg = AdminColors.indigo050,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Color iconFg;
  final Color iconBg;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 32, color: iconFg),
            ),
            const SizedBox(height: 16),
            Text(title, style: AdminText.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AdminText.body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder block used in list skeletons.
class AdminSkeleton extends StatefulWidget {
  const AdminSkeleton(
      {super.key, this.width, this.height = 12, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  State<AdminSkeleton> createState() => _AdminSkeletonState();
}

class _AdminSkeletonState extends State<AdminSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: const Alignment(-1, 0),
              end: const Alignment(1, 0),
              colors: const [
                Color(0xFFECECEF),
                Color(0xFFF6F6F8),
                Color(0xFFECECEF)
              ],
              stops: [
                (_c.value - 0.3).clamp(0.0, 1.0),
                _c.value.clamp(0.0, 1.0),
                (_c.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Confirm dialog ───────────────────────────

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AdminColors.ink.withValues(alpha: 0.5),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (danger)
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AdminColors.dangerBg,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(PhosphorIconsFill.warning,
                      size: 24, color: AdminColors.danger),
                ),
              Text(title, style: AdminText.h1),
              const SizedBox(height: 8),
              Text(body, style: AdminText.body),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminButton(
                      label: 'Cancel',
                      variant: AdminBtn.ghost,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminButton(
                      label: confirmLabel,
                      variant: danger ? AdminBtn.danger : AdminBtn.primary,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// A branded toast the admin screens use for success/info feedback.
void adminToast(BuildContext context, String message, {bool success = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? AdminColors.live : AdminColors.ink,
      content: Row(
        children: [
          Icon(success ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.info,
              size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────── Bottom sheet ───────────────────────────

/// Rounded, keyboard-aware admin bottom sheet with a drag handle + title.
Future<T?> showAdminSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: AdminColors.ink.withValues(alpha: 0.5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AdminColors.line,
                    borderRadius: BorderRadius.circular(99)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AdminText.h1)),
                    _SquareIconButton(
                      icon: PhosphorIconsBold.x,
                      bg: AdminColors.bg,
                      fg: AdminColors.tx3,
                      size: 34,
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: builder(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────── Responsive shell ───────────────────────────

/// The admin sections, used by the desktop sidebar.
enum AdminNav { overview, kitchens, venues, charges }

/// Wraps every admin screen. On a wide viewport (≥ 900 px) it shows a fixed
/// indigo sidebar and centres the screen in a max-width column; on mobile it
/// renders the screen body directly. Routing/business logic is untouched —
/// the sidebar simply navigates the existing admin routes.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.child,
    this.active,
    this.floatingActionButton,
  });
  final Widget child;
  final AdminNav? active;
  final Widget? floatingActionButton;

  static const double _breakpoint = 900;
  static const double _maxContentWidth = 720;

  /// Gap between the floating action button and the content edges on mobile.
  static const double fabMargin = 16;

  /// Height of [AdminFab] — kept in sync with its fixed height so
  /// [fabScrollPadding] stays correct if the button is ever resized.
  static const double _fabHeight = 52;

  /// Bottom padding a scrollable MUST reserve when its screen supplies a
  /// [floatingActionButton], so the button never covers the last row.
  ///
  /// The button occupies [fabMargin] + [_fabHeight] measured up from the
  /// content's bottom edge (which is already safe-area insetted by
  /// [AppScaffold]); the remainder is a clear visual gap. Screens should use
  /// this constant rather than a hand-tuned number so the two stay in sync.
  static const double fabScrollPadding = fabMargin + _fabHeight + 28; // 96

  /// Pins [content]'s floating action button at the bottom-right.
  ///
  /// Placement is done here rather than via `Scaffold.floatingActionButton` so
  /// the margins are explicit and identical on both layouts. The surrounding
  /// body is already wrapped in a bottom [SafeArea], so a plain [Positioned]
  /// lands the button above the system nav / gesture bar instead of under it.
  Widget _withFab(Widget content,
      {required double right, required double bottom}) {
    if (floatingActionButton == null) return content;
    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(right: right, bottom: bottom, child: floatingActionButton!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _breakpoint;
        if (!wide) {
          return AppScaffold(
            padded: false,
            backgroundColor: AdminColors.bg,
            body: _withFab(child, right: fabMargin, bottom: fabMargin),
          );
        }
        return AppScaffold(
          padded: false,
          backgroundColor: AdminColors.bg,
          body: Row(
            children: [
              _AdminSidebar(active: active),
              Expanded(
                child: Container(
                  color: AdminColors.bg,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: _maxContentWidth,
                    decoration: const BoxDecoration(
                      color: AdminColors.bg,
                      border: Border(
                        left: BorderSide(color: AdminColors.line),
                        right: BorderSide(color: AdminColors.line),
                      ),
                    ),
                    child: _withFab(child, right: 20, bottom: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({this.active});
  final AdminNav? active;

  @override
  Widget build(BuildContext context) {
    final items = <(AdminNav, String, IconData, String)>[
      (
        AdminNav.overview,
        'Overview',
        PhosphorIconsDuotone.house,
        AppRoutes.adminHome
      ),
      (
        AdminNav.kitchens,
        'Kitchens',
        PhosphorIconsDuotone.storefront,
        AppRoutes.adminRestaurants
      ),
      (
        AdminNav.venues,
        'Venues',
        PhosphorIconsDuotone.mapPin,
        AppRoutes.adminVenues
      ),
      (
        AdminNav.charges,
        'Charges',
        PhosphorIconsDuotone.receipt,
        AppRoutes.adminCharges
      ),
    ];
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0, -1),
          end: Alignment(0.2, 1),
          colors: [AdminColors.ink, AdminColors.indigo700],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AdminColors.indigo,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('D',
                      style: TextStyle(
                          fontFamily: 'Instrument Serif',
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Dawat',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white)),
                    Text('ADMIN',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                            letterSpacing: 1.2,
                            color: AdminColors.indigoA)),
                  ],
                ),
              ],
            ),
          ),
          for (final (nav, label, icon, route) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _SidebarItem(
                label: label,
                icon: icon,
                selected: active == nav,
                onTap: () => context.go(route),
              ),
            ),
          const Spacer(),
          AdminButton(
            label: 'Onboard',
            leading: PhosphorIconsBold.plus,
            expand: true,
            onPressed: () => context.push(AppRoutes.adminRestaurantNew),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon,
                  size: 19,
                  color: selected ? AdminColors.indigoA : Colors.white70),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience: keeps `HapticFeedback` calls terse in screens.
void adminTap() => HapticFeedback.selectionClick();

/// Address search that captures coordinates from geocoder suggestions and
/// confirms with a "Location pinned" state (no fake interactive map — we
/// geocode via Photon but don't render map tiles).
class AdminAddressPin extends StatefulWidget {
  const AdminAddressPin({
    super.key,
    this.initialText,
    required this.pinned,
    required this.onPick,
    this.onTyping,
  });
  final String? initialText;
  final bool pinned;
  final void Function(String address, double lat, double lng) onPick;
  final VoidCallback? onTyping;

  @override
  State<AdminAddressPin> createState() => _AdminAddressPinState();
}

class _AdminAddressPinState extends State<AdminAddressPin> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText ?? '');
  final _geocoder = PhotonGeocoder();
  Timer? _debounce;
  List<GeocodeResult> _suggestions = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _geocoder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onTyping?.call();
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      final results = await _geocoder.search(value, limit: 5);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = results;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          style: adminTextStyle,
          decoration: adminInput(
            'Search address…',
            prefix: const Icon(PhosphorIconsRegular.magnifyingGlass,
                size: 18, color: AdminColors.tx3),
            suffix: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : widget.pinned
                    ? const Icon(PhosphorIconsFill.mapPin,
                        color: AdminColors.live, size: 20)
                    : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++)
                  InkWell(
                    onTap: () {
                      final s = _suggestions[i];
                      _ctrl.text = s.displayAddress;
                      widget.onPick(s.displayAddress, s.latitude, s.longitude);
                      setState(() => _suggestions = const []);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: AdminColors.line2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsRegular.mapPin,
                              size: 16, color: AdminColors.indigo),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_suggestions[i].displayAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminText.body
                                    .copyWith(color: AdminColors.tx)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.pinned ? AdminColors.liveBg : AdminColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  widget.pinned
                      ? PhosphorIconsFill.mapPin
                      : PhosphorIconsRegular.mapPin,
                  size: 18,
                  color: widget.pinned ? AdminColors.live : AdminColors.tx3),
              const SizedBox(width: 8),
              Text(
                widget.pinned ? 'Location pinned' : 'Search to drop a pin',
                style: AdminText.cap.copyWith(
                    color: widget.pinned ? AdminColors.live : AdminColors.tx3,
                    fontWeight:
                        widget.pinned ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Hint banner ───────────────────────────

/// Soft indigo info strip used for inline guidance inside admin forms.
class AdminHint extends StatelessWidget {
  const AdminHint(this.text,
      {super.key, this.icon = PhosphorIconsRegular.info});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AdminColors.indigo050,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminColors.indigo),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AdminText.cap.copyWith(color: AdminColors.indigo700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Chip multi-select ───────────────────────────

/// Multi-select chip picker over a fixed vocabulary, with an optional
/// free-text "add your own" entry.
///
/// Selection is an ordered [List] so callers can join it for storage (the
/// restaurant record keeps cuisines as a single "A · B" display string, so no
/// schema change is required). Values already on the record that are not in
/// [options] are surfaced as extra chips instead of being silently dropped.
class AdminChipSelect extends StatefulWidget {
  const AdminChipSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allowCustom = false,
    this.customHint = 'Add another…',
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool allowCustom;
  final String customHint;

  @override
  State<AdminChipSelect> createState() => _AdminChipSelectState();
}

class _AdminChipSelectState extends State<AdminChipSelect> {
  final _customCtrl = TextEditingController();

  /// Values that came from the record (or were typed here) but are not part of
  /// the fixed vocabulary. Kept in state so de-selecting one does not make the
  /// chip vanish mid-edit.
  late final List<String> _extra = [
    for (final s in widget.selected)
      if (!widget.options.contains(s)) s,
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    final next = [...widget.selected];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    widget.onChanged(next);
  }

  void _addCustom() {
    final raw = _customCtrl.text.trim();
    if (raw.isEmpty) return;
    // Case-insensitive de-dupe against everything already on screen.
    final known = [...widget.options, ..._extra];
    final match = known.where((k) => k.toLowerCase() == raw.toLowerCase());
    final value = match.isNotEmpty ? match.first : raw;
    setState(() {
      if (!widget.options.contains(value) && !_extra.contains(value)) {
        _extra.add(value);
      }
      _customCtrl.clear();
    });
    if (!widget.selected.contains(value)) {
      widget.onChanged([...widget.selected, value]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.options, ..._extra];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in all)
              _Chip(
                label: option,
                selected: widget.selected.contains(option),
                onTap: () => _toggle(option),
              ),
          ],
        ),
        if (widget.allowCustom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCtrl,
                  style: adminTextStyle,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addCustom(),
                  decoration: adminInput(widget.customHint),
                ),
              ),
              const SizedBox(width: 8),
              AdminButton(
                label: 'Add',
                variant: AdminBtn.ghost,
                leading: PhosphorIconsBold.plus,
                onPressed: _addCustom,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminColors.indigo050 : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AdminColors.indigo : AdminColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(PhosphorIconsBold.check,
                    size: 13, color: AdminColors.indigo),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AdminColors.indigo : AdminColors.tx2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Image tile ───────────────────────────

/// Tappable upload target: empty prompt, uploading spinner, or the current
/// image with a "Change" affordance.
class AdminImageTile extends StatelessWidget {
  const AdminImageTile({
    super.key,
    required this.url,
    required this.uploading,
    required this.emptyLabel,
    required this.onTap,
    this.height = 120,
  });

  final String? url;
  final bool uploading;
  final String emptyLabel;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AdminColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: uploading
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AdminColors.indigo),
              )
            : url == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsRegular.uploadSimple,
                          size: 22, color: AdminColors.tx3),
                      const SizedBox(height: 6),
                      Text(emptyLabel,
                          style: AdminText.cap
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(url!, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
