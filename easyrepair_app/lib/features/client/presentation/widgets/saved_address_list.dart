import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../saved_addresses/domain/entities/saved_address_entity.dart';

// Presentation only. Every colour comes from `context.semanticColors`, and
// nothing here reads or writes a saved address — the owning page keeps all of
// that (create/update/delete, draft validation, conflict recovery) and hands
// this file callbacks. Nothing is rendered that the backend does not send:
// the entity's own `label`, `addressLine` and `city`, and nothing else.

/// Shared shape values, matching Choose Ustaad and the bidding cards.
const double _rCard = 16;
const double _rButton = 14;
const double _rPill = 999;

/// Minimum height of a tappable row, and of the sheet's primary action.
const double _hRow = 56;
const double _hAction = 52;

/// The icon a saved address gets from its own normalized label.
///
/// Purely decorative — it never invents a category the backend did not send.
/// Anything that isn't the two labels the page itself offers as shortcuts
/// falls back to a generic pin, which is what a client-named address gets.
IconData savedAddressIcon(String normalizedLabel) {
  switch (normalizedLabel) {
    case 'home':
      return Icons.home_outlined;
    case 'office':
    case 'work':
      return Icons.work_outline_rounded;
    default:
      return Icons.location_on_outlined;
  }
}

/// The client's saved addresses, as cards.
///
/// Replaces the horizontal `InputChip` strip, which showed only a label — a
/// client with "Home" and "Office" saved could not tell which pin either one
/// actually held without selecting it first. Each card now carries the
/// address line it will fill in, so the choice is made from the address
/// rather than from a name.
class SavedAddressList extends StatelessWidget {
  final List<SavedAddressEntity> addresses;
  final String? selectedId;

  /// Fills the form with this address. The card body and its Select action
  /// both route here, so the whole card is the primary target.
  final ValueChanged<SavedAddressEntity> onSelect;

  /// Opens the options sheet (update-with-current / rename / delete).
  final ValueChanged<SavedAddressEntity> onEdit;

  const SavedAddressList({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) return const SizedBox.shrink();
    final c = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.savedAddresses,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < addresses.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _SavedAddressCard(
            address: addresses[i],
            selected: addresses[i].id == selectedId,
            onSelect: () => onSelect(addresses[i]),
            onEdit: () => onEdit(addresses[i]),
          ),
        ],
      ],
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final SavedAddressEntity address;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  const _SavedAddressCard({
    required this.address,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final city = address.city.trim();

    return Material(
      // Selected state is `softTeal` + a `primary` hairline + a check — the
      // same selected treatment Choose Ustaad uses. No orange anywhere.
      color: selected ? c.softTeal : c.surface,
      borderRadius: BorderRadius.circular(_rCard),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(_rCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_rCard),
            border: Border.all(color: selected ? c.primary : c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected ? c.primary : c.surfaceSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      savedAddressIcon(address.normalizedLabel),
                      size: 18,
                      color: selected ? c.onPrimary : c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                // The client's own name for this address —
                                // never translated, never re-cased.
                                address.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 17,
                                color: c.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // A Karachi address routinely needs three lines;
                          // it wraps rather than truncating to one.
                          address.addressLine,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: c.textPrimary,
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Actions wrap rather than sitting in a fixed Row, so a long
              // localized label at a 2.0 text scale drops to its own line
              // instead of overflowing a 320px card.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _CardAction(
                      icon: Icons.tune_rounded,
                      label: l10n.cardEdit,
                      onTap: onEdit,
                      emphasized: false,
                    ),
                    _CardAction(
                      icon: Icons.check_rounded,
                      label: l10n.savedAddressUse,
                      onTap: onSelect,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final tint = emphasized ? c.primary : c.textSecondary;

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: tint),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          color: tint,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: tint,
        // 44 tall so it clears the prototype's minimum tap target even though
        // it reads as a text action.
        minimumSize: const Size(0, 44),
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rButton),
        ),
      ),
    );
  }
}

/// A HandyGo pill, used for the "save this address as…" shortcuts.
///
/// Replaces `ActionChip`, whose Material default drew a grey fill and a
/// shadow that belong to no HandyGo surface.
class SavedAddressPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const SavedAddressPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(_rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_rPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_rPill),
            border: Border.all(color: c.controlBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The options sheet for one saved address.
///
/// Same four actions the `ListTile` version offered, in the same order and
/// returning the same string keys — only the presentation changed. Returns
/// `'use'`, `'update'`, `'rename'`, `'delete'`, or null if dismissed.
Future<String?> showSavedAddressOptionsSheet(
  BuildContext context,
  SavedAddressEntity address,
) {
  final c = context.semanticColors;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  address.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  address.addressLine,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: c.textSecondary,
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: c.border),
              _SheetAction(
                icon: Icons.location_on_outlined,
                label: l10n.savedAddressUse,
                onTap: () => Navigator.pop(sheetContext, 'use'),
              ),
              _SheetAction(
                icon: Icons.sync_rounded,
                label: l10n.savedAddressUpdateWithCurrent,
                onTap: () => Navigator.pop(sheetContext, 'update'),
              ),
              _SheetAction(
                icon: Icons.edit_outlined,
                label: l10n.savedAddressRename,
                onTap: () => Navigator.pop(sheetContext, 'rename'),
              ),
              _SheetAction(
                icon: Icons.delete_outline,
                label: l10n.commonDelete,
                onTap: () => Navigator.pop(sheetContext, 'delete'),
                destructive: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final tint = destructive ? c.error : c.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _hRow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: destructive ? c.error : c.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name-this-address sheet, used for both "save as Other…" and rename.
///
/// [onValidate] returns a localized error to show inline, or null to accept —
/// the duplicate-label rule stays with the owning page, which is the only
/// thing that can see the current saved list.
Future<String?> showSavedAddressNameSheet(
  BuildContext context, {
  String initialValue = '',
  required String title,
  String? initialError,
  required String? Function(String value) onValidate,
}) {
  final c = context.semanticColors;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => _SavedAddressNameSheet(
      initialValue: initialValue,
      title: title,
      initialError: initialError,
      onValidate: onValidate,
    ),
  );
}

/// The sheet body owns its own controller so it is disposed with the route,
/// not while the route is still animating out — disposing it at the caller's
/// `await` point tore the field down mid-transition.
class _SavedAddressNameSheet extends StatefulWidget {
  final String initialValue;
  final String title;
  final String? initialError;
  final String? Function(String value) onValidate;

  const _SavedAddressNameSheet({
    required this.initialValue,
    required this.title,
    required this.initialError,
    required this.onValidate,
  });

  @override
  State<_SavedAddressNameSheet> createState() => _SavedAddressNameSheetState();
}

class _SavedAddressNameSheetState extends State<_SavedAddressNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late String? _inlineError = widget.initialError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.onValidate(value);
    if (error != null) {
      setState(() => _inlineError = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        // Scrolls rather than overflowing once the keyboard, a two-line
        // error and a 2.0 text scale are all in play at once.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 50,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.savedAddressName,
                  labelStyle: TextStyle(fontSize: 14, color: c.textSecondary),
                  errorText: _inlineError,
                  errorMaxLines: 2,
                  filled: true,
                  fillColor: c.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                    borderSide: BorderSide(color: c.controlBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                    borderSide: BorderSide(color: c.controlBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                    borderSide: BorderSide(color: c.primary, width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) {
                  if (_inlineError != null) {
                    setState(() => _inlineError = null);
                  }
                },
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  minimumSize: const Size.fromHeight(_hAction),
                  // See the map picker's confirm: standard density is pinned
                  // so the 52 floor holds on every platform.
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                  ),
                ),
                child: Text(
                  context.l10n.commonSave,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
