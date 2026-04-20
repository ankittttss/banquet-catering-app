import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/auth_providers.dart';

// ───────────────────────── Palette (matches HTML mock) ─────────────────────────

class _P {
  static const Color red   = Color(0xFFE23744);
  static const Color redLt = Color(0xFFFFF1F2);
  static const Color grn   = Color(0xFF1BA672);
  static const Color grnLt = Color(0xFFEAFAF1);
  static const Color blu   = Color(0xFF2B6CB0);
  static const Color bluLt = Color(0xFFEBF4FF);
  static const Color gld   = Color(0xFFC4922A);
  static const Color gldLt = Color(0xFFFFF8E7);
  static const Color pur   = Color(0xFF7C3AED);
  static const Color purLt = Color(0xFFF3E8FF);
  static const Color org   = Color(0xFFE97A2B);
  static const Color orgLt = Color(0xFFFFF4EB);
  static const Color blk   = Color(0xFF1A1A1A);
  static const Color g70   = Color(0xFF4F4F4F);
  static const Color g50   = Color(0xFF828282);
  static const Color g30   = Color(0xFFBDBDBD);
  static const Color g15   = Color(0xFFE0E0E0);
  static const Color g8    = Color(0xFFF2F2F2);
  static const Color g4    = Color(0xFFF9F9F9);
  static const Color w     = Color(0xFFFFFFFF);
  static const Color cr    = Color(0xFFFDFBF9);
  static const Color bg    = Color(0xFFFAF7F4);
}

const _dietaryOptions = <(String, String, Color)>[
  ('veg',       'Vegetarian',      _P.grn),
  ('non_veg',   'Non-vegetarian',  _P.red),
  ('eggetarian','Eggetarian',      _P.gld),
  ('vegan',     'Vegan',           _P.grn),
  ('jain',      'Jain',            _P.org),
];

const _allergyOptions = <(String, String)>[
  ('peanuts',   '🥜 Peanuts'),
  ('dairy',     '🥛 Dairy'),
  ('gluten',    '🌾 Gluten'),
  ('shellfish', '🦐 Shellfish'),
  ('eggs',      '🥚 Eggs'),
  ('soy',       '🫘 Soy'),
];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _gender;
  DateTime? _dob;
  String? _dietary;
  final Set<String> _allergies = {};
  final Map<String, bool> _notifPrefs = {
    'order_updates': true,
    'promos': true,
    'event_reminders': true,
    'whatsapp': false,
  };

  bool _saving = false;
  bool _justSaved = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _hydrateFrom(UserProfile p) {
    if (_hydrated) return;
    _hydrated = true;
    _nameCtrl.text = p.name ?? '';
    _emailCtrl.text = p.email ?? '';
    _phoneCtrl.text = p.phone ?? '';
    _gender = p.gender;
    _dob = p.dateOfBirth;
    _dietary = p.dietaryPreference;
    _allergies.addAll(p.allergies);
    for (final k in _notifPrefs.keys.toList()) {
      final v = p.notificationPrefs[k];
      if (v is bool) _notifPrefs[k] = v;
    }
  }

  Future<void> _save(UserProfile current) async {
    HapticFeedback.selectionClick();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final phoneText = _phoneCtrl.text.trim();
      final patch = <String, dynamic>{
        'name': name,
        'phone': phoneText.isEmpty ? null : phoneText,
        'gender': _gender,
        'date_of_birth': _dob == null
            ? null
            : '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        'dietary_preference': _dietary,
        'allergies': _allergies.toList(growable: false),
        'notification_prefs': _notifPrefs,
      };
      if (AppConfig.hasSupabase) {
        // Direct UPDATE (not upsert) so we only hit the owner-update RLS
        // policy. Upsert re-checks the INSERT policy, which can fail even
        // though the row already exists.
        await sb.supabase.from('profiles').update(patch).eq('id', current.id);
      }
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _justSaved = true;
      });
      _showToast('Profile updated successfully');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _justSaved = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: _P.grn, size: 18),
            const SizedBox(width: 8),
            Text(msg, style: const TextStyle(color: _P.w)),
          ],
        ),
        backgroundColor: _P.blk,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Scaffold(
      backgroundColor: _P.bg,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Please sign in first'));
          }
          _hydrateFrom(profile);
          return SafeArea(
            child: Column(
              children: [
                _topBar(context, profile),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _avatarSection(profile),
                      const SizedBox(height: 8),
                      _basicInfoSection(),
                      const SizedBox(height: 8),
                      _personalSection(),
                      const SizedBox(height: 8),
                      _foodSection(),
                      const SizedBox(height: 8),
                      _commsSection(),
                      const SizedBox(height: 8),
                      _dangerSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Top bar ───
  Widget _topBar(BuildContext context, UserProfile profile) {
    return Container(
      height: 50,
      color: _P.w,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _backButton(context),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Edit profile',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _P.blk,
              ),
            ),
          ),
          Material(
            color: _justSaved ? _P.grn : _P.red,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _saving ? null : () => _save(profile),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: _P.w,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(Icons.check_rounded,
                          size: 14, color: _P.w),
                    const SizedBox(width: 5),
                    Text(
                      _justSaved ? 'Saved' : 'Save',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _P.w,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.profile),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _P.g4,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.g8),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            size: 18, color: _P.g70),
      ),
    );
  }

  // ─── Avatar ───
  Widget _avatarSection(UserProfile profile) {
    final initial = _initial(profile);
    return Container(
      color: _P.w,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_P.red, _P.gld],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _P.red.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: _P.w,
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Material(
                  color: _P.blk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: _P.w, width: 3),
                  ),
                  child: InkWell(
                    onTap: _showPhotoPickerStub,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.camera_alt_rounded,
                          size: 14, color: _P.w),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tap to change photo',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _P.g50,
            ),
          ),
        ],
      ),
    );
  }

  String _initial(UserProfile p) {
    final name = p.name?.trim();
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    final email = p.email?.trim();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  void _showPhotoPickerStub() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo upload — coming soon')),
    );
  }

  // ─── Basic info ───
  Widget _basicInfoSection() {
    return _section(
      icon: Icons.person_outline_rounded,
      title: 'Basic information',
      children: [
        _labeledField(
          label: 'Full name',
          required: true,
          child: _input(
            controller: _nameCtrl,
            hint: 'Your full name',
            icon: Icons.person_outline_rounded,
            maxLength: 50,
          ),
        ),
        _labeledField(
          label: 'Email address',
          verified: true,
          child: _input(
            controller: _emailCtrl,
            hint: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            enabled: false,
          ),
        ),
        _labeledField(
          label: 'Phone number',
          child: Row(
            children: [
              Container(
                width: 76,
                height: 50,
                decoration: BoxDecoration(
                  color: _P.cr,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _P.g15, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '+91',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _P.g70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _input(
                  controller: _phoneCtrl,
                  hint: '98765 43210',
                  keyboard: TextInputType.phone,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Personal details ───
  Widget _personalSection() {
    return _section(
      icon: Icons.calendar_today_rounded,
      title: 'Personal details',
      children: [
        _labeledField(
          label: 'Gender',
          child: _dropdown(
            value: _gender,
            hint: 'Select gender',
            items: const [
              ('male',   'Male'),
              ('female', 'Female'),
              ('non_binary', 'Non-binary'),
              ('other',  'Prefer not to say'),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
        ),
        _labeledField(
          label: 'Date of birth',
          child: InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _P.cr,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _P.g15, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: _P.g30),
                  const SizedBox(width: 12),
                  Text(
                    _dob == null ? 'Select date' : _formatDob(_dob!),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _dob == null ? _P.g30 : _P.blk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          hint: _dob == null
              ? null
              : 'We\'ll send you a birthday surprise!',
          hintIcon: _dob == null ? null : Icons.star_rounded,
        ),
      ],
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 10),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _P.red,
                onPrimary: _P.w,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  // ─── Food preferences ───
  Widget _foodSection() {
    return _section(
      icon: Icons.restaurant_menu_rounded,
      title: 'Food preferences',
      children: [
        _labeledField(
          label: 'Dietary preference',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label, color) in _dietaryOptions)
                _chip(
                  label: label,
                  on: _dietary == value,
                  dotColor: color,
                  onTap: () => setState(() {
                    _dietary = _dietary == value ? null : value;
                  }),
                ),
            ],
          ),
        ),
        _labeledField(
          label: 'Allergies',
          hint: 'We\'ll flag these allergens when you browse menus',
          hintIcon: Icons.shield_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _allergyOptions)
                _chip(
                  label: label,
                  on: _allergies.contains(value),
                  onTap: () => setState(() {
                    if (_allergies.contains(value)) {
                      _allergies.remove(value);
                    } else {
                      _allergies.add(value);
                    }
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Communication toggles ───
  Widget _commsSection() {
    return _section(
      icon: Icons.notifications_outlined,
      title: 'Communication',
      children: [
        _toggleRow(
          'Order updates',
          'Status changes, driver info, delivery alerts',
          'order_updates',
        ),
        const SizedBox(height: 12),
        _toggleRow(
          'Promotional offers',
          'Deals, discounts & new restaurant alerts',
          'promos',
        ),
        const SizedBox(height: 12),
        _toggleRow(
          'Event reminders',
          'Upcoming event alerts & planning tips',
          'event_reminders',
        ),
        const SizedBox(height: 12),
        _toggleRow(
          'WhatsApp updates',
          'Receive order updates on WhatsApp',
          'whatsapp',
        ),
      ],
    );
  }

  Widget _toggleRow(String title, String sub, String key) {
    final on = _notifPrefs[key] ?? false;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _P.blk,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: _P.g50,
                ),
              ),
            ],
          ),
        ),
        _switch(on, () => setState(() => _notifPrefs[key] = !on)),
      ],
    );
  }

  Widget _switch(bool on, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: on ? _P.grn : _P.g15,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              top: 2,
              left: on ? 22 : 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _P.w,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Danger zone ───
  Widget _dangerSection() {
    return Container(
      color: _P.w,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: _P.red),
              const SizedBox(width: 8),
              Text(
                'DANGER ZONE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _P.red,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: _P.w,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _P.redLt, width: 1.5),
            ),
            child: InkWell(
              onTap: _confirmDelete,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 16, color: _P.red),
                    const SizedBox(width: 8),
                    Text(
                      'Delete my account',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _P.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'This will permanently delete your account, order history, and all saved data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: _P.g50,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.heavyImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This action cannot be undone. Your account, orders, addresses, and reviews will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _P.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Account deletion request submitted. Our team will confirm by email.'),
        ),
      );
    }
  }

  // ─── Reusable primitives ───
  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      color: _P.w,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _P.g30),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _P.g50,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required Widget child,
    bool required = false,
    bool verified = false,
    String? hint,
    IconData? hintIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _P.g70,
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: _P.red,
                      fontWeight: FontWeight.w700),
                ),
              if (verified) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _P.grnLt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 10, color: _P.grn),
                      const SizedBox(width: 3),
                      Text(
                        'Verified',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _P.grn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
          if (hint != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(hintIcon ?? Icons.info_outline_rounded,
                    size: 12, color: _P.g30),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hint,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: _P.g50,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboard,
    int? maxLength,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        enabled: enabled,
        maxLength: maxLength,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: enabled ? _P.blk : _P.g50,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: _P.g30),
          prefixIcon: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(icon, size: 18, color: _P.g30),
                ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: enabled ? _P.cr : _P.g4,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.g15, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.g15, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.red, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.g15, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _P.cr,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.g15, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.outfit(fontSize: 14, color: _P.g30),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _P.g30),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _P.blk,
          ),
          items: [
            for (final (val, label) in items)
              DropdownMenuItem(value: val, child: Text(label)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool on,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return Material(
      color: on ? _P.redLt : _P.w,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: on ? _P.red : _P.g15,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? _P.red : _P.g70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
