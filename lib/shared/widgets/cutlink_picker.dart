import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const cutLinkPickerRed = Color(0xFF741C1C);

class CutLinkPickerOption<T> {
  const CutLinkPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

Future<T?> showCutLinkPickerDialog<T>({
  required BuildContext context,
  required String title,
  required List<CutLinkPickerOption<T>> options,
  T? currentValue,
  String searchHint = 'Search',
  bool enableSearch = true,
}) async {
  final searchController = TextEditingController();
  final focusNode = FocusNode();
  String query = '';

  final result = await showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final cleanQuery = query.trim().toLowerCase();
          final filtered = cleanQuery.isEmpty
              ? options
              : options.where((option) {
                  return option.label.toLowerCase().contains(cleanQuery) ||
                      (option.subtitle ?? '').toLowerCase().contains(
                        cleanQuery,
                      );
                }).toList();

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: const Color(0xFFF8F8F6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 17, 12, 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF252525),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (enableSearch && options.length > 7)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
                        child: TextField(
                          controller: searchController,
                          focusNode: focusNode,
                          autofocus: true,
                          onChanged: (value) =>
                              setDialogState(() => query = value),
                          decoration: InputDecoration(
                            hintText: searchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      searchController.clear();
                                      setDialogState(() => query = '');
                                    },
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFDCDCD8),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFDCDCD8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: cutLinkPickerRed,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 1, color: Color(0xFFE0E0DC)),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'No matching options',
                                  style: TextStyle(
                                    color: Color(0xFF777777),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                14,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final selected = option.value == currentValue;

                                return Material(
                                  color: selected
                                      ? const Color(0xFFF3E5E5)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(11),
                                    onTap: () => Navigator.of(
                                      dialogContext,
                                    ).pop(option.value),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFFCBA6A6)
                                              : const Color(0xFFE2E2DE),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? cutLinkPickerRed
                                                  : const Color(0xFFF1F1EE),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              selected
                                                  ? Icons.check
                                                  : option.icon ??
                                                        Icons.chevron_right,
                                              size: 18,
                                              color: selected
                                                  ? Colors.white
                                                  : const Color(0xFF666666),
                                            ),
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  option.label,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: selected
                                                        ? cutLinkPickerRed
                                                        : const Color(
                                                            0xFF2B2B2B,
                                                          ),
                                                  ),
                                                ),
                                                if ((option.subtitle ?? '')
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    option.subtitle!.trim(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF777777),
                                                      fontSize: 11,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  searchController.dispose();
  focusNode.dispose();
  return result;
}

class CutLinkPickerField<T> extends StatelessWidget {
  const CutLinkPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
    this.enabled = true,
    this.loading = false,
    this.helperText,
    this.validator,
    this.searchHint = 'Search',
    this.enableSearch = true,
    this.dense = false,
  });

  final String label;
  final T? value;
  final List<CutLinkPickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String hint;
  final bool enabled;
  final bool loading;
  final String? helperText;
  final FormFieldValidator<T>? validator;
  final String searchHint;
  final bool enableSearch;
  final bool dense;

  CutLinkPickerOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return FormField<T>(
      key: ValueKey('$label-$value-${options.length}-$loading'),
      initialValue: value,
      validator: validator,
      builder: (field) {
        Future<void> open() async {
          if (!enabled || loading) return;

          final picked = await showCutLinkPickerDialog<T>(
            context: context,
            title: label,
            options: options,
            currentValue: value,
            searchHint: searchHint,
            enableSearch: enableSearch,
          );

          if (picked == null) return;
          field.didChange(picked);
          onChanged(picked);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: enabled && !loading ? open : null,
              child: Container(
                constraints: BoxConstraints(minHeight: dense ? 44 : 54),
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 11 : 13,
                  vertical: dense ? 7 : 9,
                ),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : const Color(0xFFF2F2EF),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade700
                        : selected != null
                        ? const Color(0xFFCBB3B3)
                        : const Color(0xFFDADAD6),
                  ),
                ),
                child: Row(
                  children: [
                    if (!dense) ...[
                      Container(
                        width: 31,
                        height: 31,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected != null
                              ? const Color(0xFFF3E5E5)
                              : const Color(0xFFF1F1EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                selected != null
                                    ? Icons.check_circle_outline
                                    : Icons.tune,
                                size: 17,
                                color: selected != null
                                    ? cutLinkPickerRed
                                    : const Color(0xFF777777),
                              ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!dense)
                            Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (!dense) const SizedBox(height: 2),
                          Text(
                            selected?.label ?? (loading ? 'Loading...' : hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected != null
                                  ? const Color(0xFF292929)
                                  : const Color(0xFF999999),
                              fontSize: dense ? 12.5 : 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                  ],
                ),
              ),
            ),
            if ((helperText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  helperText!.trim(),
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 10.5),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
