import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/app_ui_constants.dart';

/// A reusable widget that shows an optional toggle for customising seat
/// prefix and start number in slot add/edit forms.
///
/// When the toggle is off (default) nothing extra is shown. When toggled on
/// two compact fields appear - Prefix and Start Number - along with a live
/// preview chip like "A20 -> A39".
class SeatNumberingSection extends StatelessWidget {
  const SeatNumberingSection({
    super.key,
    required this.enabled,
    required this.prefixController,
    required this.startNumberController,
    required this.capacityText,
    required this.onToggle,
  });

  /// Whether the custom numbering section is expanded.
  final bool enabled;
  final TextEditingController prefixController;
  final TextEditingController startNumberController;

  /// Raw text from the capacity field – used to build the live preview.
  final String capacityText;

  /// Called with [true]/[false] when the toggle is flipped.
  final ValueChanged<bool> onToggle;

  // ── helpers ────────────────────────────────────────────────────────────

  /// Bed labels for the preview chips (first 4, then the last one).
  List<String> _buildBedLabels() {
    final capacity = int.tryParse(capacityText.trim()) ?? 0;
    if (capacity <= 0) return const [];
    final rawPrefix = prefixController.text.trim();
    final prefix = rawPrefix.isEmpty ? 'B' : rawPrefix.toUpperCase();
    final start = int.tryParse(startNumberController.text.trim()) ?? 1;
    final end = start + capacity - 1;
    final padLen = end.toString().length.clamp(2, 4);
    String label(int n) => '$prefix${n.toString().padLeft(padLen, '0')}';
    final shown = capacity <= 5 ? capacity : 4;
    return [
      for (var i = 0; i < shown; i++) label(start + i),
      if (capacity > 5) '...',
      if (capacity > 5) label(end),
    ];
  }

  String _buildPreview() {
    final capacity = int.tryParse(capacityText.trim()) ?? 0;
    if (capacity <= 0) return '';

    final rawPrefix = prefixController.text.trim();
    final prefix = rawPrefix.isEmpty ? 'B' : rawPrefix.toUpperCase();
    final start = int.tryParse(startNumberController.text.trim()) ?? 1;
    final end = start + capacity - 1;
    final padLen = end.toString().length.clamp(2, 4);

    final first = '$prefix${start.toString().padLeft(padLen, '0')}';
    final last = '$prefix${end.toString().padLeft(padLen, '0')}';
    return '$first -> $last';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: enabled
            ? AppUIConstants.primarySoft.withValues(alpha: 0.6)
            : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: enabled
              ? AppUIConstants.primaryLight.withValues(alpha: 0.35)
              : AppUIConstants.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toggle row ───────────────────────────────────────────────
          InkWell(
            onTap: () => onToggle(!enabled),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.bed_rounded,
                    size: 18,
                    color: enabled
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customise bed numbers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppUIConstants.primaryLight
                            : AppUIConstants.textPrimary,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: enabled,
                      onChanged: onToggle,
                      activeThumbColor: AppUIConstants.primaryLight,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded fields ──────────────────────────────────────────
          if (enabled) ...[
            Divider(
              height: 1,
              color: AppUIConstants.primaryLight.withValues(alpha: 0.15),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prefix + Start Number fields
                  Row(
                    children: [
                      // Prefix
                      Expanded(
                        child: _buildTextField(
                          controller: prefixController,
                          label: 'Room type / bed prefix',
                          hint: 'e.g. A, R1',
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Start number
                      Expanded(
                        child: _buildTextField(
                          controller: startNumberController,
                          label: 'First bed no.',
                          hint: 'e.g. 1, 20',
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Live preview chip
                  const SizedBox(height: 10),
                  _PreviewChip(
                    previewText: _buildPreview(),
                    bedLabels: _buildBedLabels(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          borderSide: BorderSide(color: AppUIConstants.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          borderSide: BorderSide(color: AppUIConstants.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          borderSide: BorderSide(
            color: AppUIConstants.primaryLight,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: AppUIConstants.surface,
        labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
        hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
        isDense: true,
      ),
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(color: AppUIConstants.textPrimary),
    );
  }
}

// ── Preview chip ──────────────────────────────────────────────────────────────

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.previewText, required this.bedLabels});

  final String previewText;
  final List<String> bedLabels;

  @override
  Widget build(BuildContext context) {
    if (previewText.isEmpty) {
      return const Text(
        'Enter the number of beds above to preview bed numbers',
        style: TextStyle(
          fontSize: 11,
          color: AppUIConstants.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 13,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(width: 4),
            const Text(
              'Beds will be numbered ',
              style: TextStyle(
                fontSize: 12,
                color: AppUIConstants.textTertiary,
              ),
            ),
            Text(
              previewText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppUIConstants.primaryLight,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Wrap(
            key: ValueKey(previewText),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in bedLabels)
                label == '...'
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '...',
                          style: TextStyle(
                            color: AppUIConstants.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppUIConstants.primaryLight.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                          border: Border.all(
                            color: AppUIConstants.primaryLight.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bed_outlined,
                              size: 13,
                              color: AppUIConstants.primaryLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppUIConstants.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
            ],
          ),
        ),
      ],
    );
  }
}
