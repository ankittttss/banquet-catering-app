import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';

/// Add / edit form for a single menu item, shown as a modal bottom sheet.
/// Returns `true` when a change was saved so the caller can refresh.
class MenuItemFormSheet extends ConsumerStatefulWidget {
  const MenuItemFormSheet({super.key, this.existing});

  /// The item being edited, or null when adding a new one.
  final MenuItem? existing;

  static Future<bool?> show(BuildContext context, {MenuItem? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (_) => MenuItemFormSheet(existing: existing),
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

  bool _saving = false;
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
    _restaurantId = e?.restaurantId;
    _categoryId = e?.categoryId;
    _isVeg = e?.isVeg ?? true;
    _isAvailable = e?.isAvailable ?? true;
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
        _error =
            'Enter a name, pick a restaurant & category, and a valid price.';
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
            imageUrl: widget.existing!.imageUrl,
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
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                _isEdit ? 'Edit item' : 'Add menu item',
                style: AppTextStyles.heading1,
              ),
              const SizedBox(height: AppSizes.lg),

              _label('Item name'),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('e.g. Paneer Tikka'),
              ),
              const SizedBox(height: AppSizes.md),

              _label('Restaurant'),
              DropdownButtonFormField<String>(
                initialValue: restId,
                isExpanded: true,
                decoration: _dec('Select a restaurant'),
                items: [
                  for (final r in restaurants)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _restaurantId = v),
              ),
              const SizedBox(height: AppSizes.md),

              _label('Category'),
              DropdownButtonFormField<String>(
                initialValue: catId,
                isExpanded: true,
                decoration: _dec('Select a category'),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: AppSizes.md),

              _label('Price (₹)'),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: _dec('e.g. 220'),
              ),
              const SizedBox(height: AppSizes.md),

              _label('Description (optional)'),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Short description'),
              ),
              const SizedBox(height: AppSizes.sm),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.veg,
                title: Text('Vegetarian', style: AppTextStyles.bodyBold),
                value: _isVeg,
                onChanged: (v) => setState(() => _isVeg = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: Text('Available', style: AppTextStyles.bodyBold),
                subtitle: Text(
                  'Unavailable items are hidden from customers',
                  style: AppTextStyles.caption,
                ),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.lg),

              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save changes' : 'Add item',
                        style: AppTextStyles.buttonLabel
                            .copyWith(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.xs),
        child: Text(
          text,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.body.copyWith(color: AppColors.textMuted),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      );
}
