import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../user/widgets/photo_picker_sheet.dart';
import 'admin_ui.dart';

/// Add / edit form for a single dish, shown as a modal bottom sheet in the
/// admin indigo identity. Returns `true` when a change was saved so the
/// caller can refresh.
class MenuItemFormSheet extends ConsumerStatefulWidget {
  const MenuItemFormSheet({super.key, this.existing, this.lockedRestaurant});

  /// The item being edited, or null when adding a new one.
  final MenuItem? existing;

  /// When set, the item belongs to this restaurant and the restaurant
  /// dropdown is replaced by a read-only row. Used by the admin onboarding
  /// wizard / management page — draft restaurants aren't in the customer
  /// [restaurantsProvider] list the dropdown is fed from.
  final Restaurant? lockedRestaurant;

  static Future<bool?> show(
    BuildContext context, {
    MenuItem? existing,
    Restaurant? lockedRestaurant,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MenuItemFormSheet(
        existing: existing,
        lockedRestaurant: lockedRestaurant,
      ),
    );
  }

  @override
  ConsumerState<MenuItemFormSheet> createState() => _MenuItemFormSheetState();
}

class _MenuItemFormSheetState extends ConsumerState<MenuItemFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;

  String? _restaurantId;
  String? _categoryId;
  late bool _isVeg;
  late bool _isAvailable;
  String? _imageUrl;

  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl = TextEditingController(
      text: e == null ? '' : e.price.toStringAsFixed(0),
    );
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _restaurantId = e?.restaurantId ?? widget.lockedRestaurant?.id;
    _categoryId = e?.categoryId;
    _isVeg = e?.isVeg ?? true;
    _isAvailable = e?.isAvailable ?? true;
    _imageUrl = e?.imageUrl;
  }

  Future<void> _pickImage() async {
    if (_restaurantId == null) {
      setState(() => _error = 'Pick a kitchen first, then add a photo.');
      return;
    }
    final result = await showPhotoPickerSheet(
      context,
      title: 'Dish photo',
      hasExisting: _imageUrl != null,
    );
    if (!mounted) return;
    if (result is PhotoRemoved) {
      setState(() => _imageUrl = null);
      return;
    }
    if (result is! PhotoPickedBytes) {
      if (result is PhotoPickerError) {
        setState(() => _error = result.message);
      }
      return;
    }
    setState(() {
      _uploadingImage = true;
      _error = null;
    });
    try {
      final url = await ref.read(menuRepositoryProvider).uploadMenuItemImage(
            restaurantId: _restaurantId!,
            bytes: result.bytes,
          );
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty ||
        _restaurantId == null ||
        _categoryId == null ||
        price == null ||
        price <= 0) {
      setState(() {
        _error = 'Enter a name, pick a kitchen & category, and a valid price.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(menuRepositoryProvider);
      final desc = _descCtrl.text.trim();
      if (_isEdit) {
        await repo.updateMenuItem(
          MenuItem(
            id: widget.existing!.id,
            restaurantId: _restaurantId!,
            categoryId: _categoryId!,
            name: name,
            price: price,
            description: desc.isEmpty ? null : desc,
            imageUrl: _imageUrl,
            isVeg: _isVeg,
            isAvailable: _isAvailable,
          ),
        );
      } else {
        await repo.createMenuItem(
          restaurantId: _restaurantId!,
          categoryId: _categoryId!,
          name: name,
          price: price,
          description: desc.isEmpty ? null : desc,
          imageUrl: _imageUrl,
          isVeg: _isVeg,
          isAvailable: _isAvailable,
        );
      }
      // Refresh both the admin list and the customer storefront.
      ref.invalidate(adminMenuItemsProvider);
      ref.invalidate(menuItemsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _friendly(e);
        });
      }
    }
  }

  String _friendly(Object e) {
    final first = e.toString().split('\n').first;
    return first.length > 160 ? '${first.substring(0, 160)}…' : first;
  }

  @override
  Widget build(BuildContext context) {
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final cats =
        ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];

    // DropdownButton asserts the value is present in its items (or null), so
    // fall back to null when an item points at a restaurant/category that
    // isn't in the current list (e.g. an inactive restaurant).
    final restId =
        restaurants.any((r) => r.id == _restaurantId) ? _restaurantId : null;
    final catId = cats.any((c) => c.id == _categoryId) ? _categoryId : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdminColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Edit dish' : 'Add dish', style: AdminText.h1),
              const SizedBox(height: 18),
              AdminField(
                label: 'Dish name',
                required: true,
                child: TextField(
                  controller: _nameCtrl,
                  style: adminTextStyle,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminInput('e.g. Paneer Tikka'),
                ),
              ),
              const SizedBox(height: 16),
              AdminField(
                label: 'Kitchen',
                required: true,
                child: widget.lockedRestaurant != null
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 14),
                        decoration: BoxDecoration(
                          color: AdminColors.bg,
                          borderRadius: BorderRadius.circular(11),
                          border:
                              Border.all(color: AdminColors.line, width: 1.5),
                        ),
                        child: Text(
                          widget.lockedRestaurant!.name,
                          style:
                              adminTextStyle.copyWith(color: AdminColors.tx2),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: restId,
                        isExpanded: true,
                        style: adminTextStyle,
                        decoration: adminInput('Select a kitchen'),
                        items: [
                          for (final r in restaurants)
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                        ],
                        onChanged: (v) => setState(() => _restaurantId = v),
                      ),
              ),
              const SizedBox(height: 16),
              AdminField(
                label: 'Category',
                required: true,
                child: DropdownButtonFormField<String>(
                  initialValue: catId,
                  isExpanded: true,
                  style: adminTextStyle,
                  decoration: adminInput('Select a category'),
                  items: [
                    for (final c in cats)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: 16),
              AdminField(
                label: 'Price (₹)',
                required: true,
                child: TextField(
                  controller: _priceCtrl,
                  style: adminTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: adminInput('220'),
                ),
              ),
              const SizedBox(height: 16),
              AdminField(
                label: 'Description',
                hint: 'Optional',
                child: TextField(
                  controller: _descCtrl,
                  style: adminTextStyle,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: adminInput('Short description'),
                ),
              ),
              const SizedBox(height: 16),
              AdminField(
                label: 'Dish photo',
                hint: 'Optional',
                child: AdminImageTile(
                  url: _imageUrl,
                  uploading: _uploadingImage,
                  emptyLabel: 'Add dish photo',
                  height: 110,
                  onTap: _uploadingImage ? null : _pickImage,
                ),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Vegetarian',
                subtitle: 'Shows the green veg mark to customers',
                value: _isVeg,
                activeColor: AdminColors.live,
                onChanged: (v) => setState(() => _isVeg = v),
              ),
              const SizedBox(height: 10),
              _ToggleRow(
                title: 'Available',
                subtitle: 'Unavailable dishes are hidden from customers',
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(PhosphorIconsFill.warningCircle,
                        size: 15, color: AdminColors.danger),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _error!,
                        style:
                            AdminText.cap.copyWith(color: AdminColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              AdminButton(
                label: _saving
                    ? 'Saving…'
                    : (_isEdit ? 'Save changes' : 'Add dish'),
                size: 'lg',
                expand: true,
                leading: _saving ? null : PhosphorIconsBold.check,
                disabled: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled toggle row inside the dish sheet (matches the admin card style
/// used across the console instead of a platform SwitchListTile).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = AdminColors.indigo,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminText.h3),
                const SizedBox(height: 2),
                Text(subtitle, style: AdminText.cap),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AdminToggle(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
