import 'package:flutter/material.dart';
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
            ? AppUIConstants.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: enabled
              ? AppUIConstants.primary.withValues(alpha: 0.18)
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
                    Icons.tag_rounded,
                    size: 18,
                    color: enabled
                        ? AppUIConstants.primary
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customise Bed Numbers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? AppUIConstants.primary
                            : AppUIConstants.textPrimary,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: enabled,
                      onChanged: onToggle,
                      activeThumbColor: AppUIConstants.primary,
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
              color: AppUIConstants.primary.withValues(alpha: 0.15),
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
                          label: 'Prefix',
                          hint: 'e.g. A, B, R1',
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
                          label: 'Start Number',
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
                  _PreviewChip(previewText: _buildPreview()),
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
          borderSide: BorderSide(color: AppUIConstants.primary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.characters,
    );
  }
}

// ── Preview chip ──────────────────────────────────────────────────────────────

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.previewText});

  final String previewText;

  @override
  Widget build(BuildContext context) {
    if (previewText.isEmpty) {
      return Text(
        'Enter seat count above to see preview',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          'Preview: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppUIConstants.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppUIConstants.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            previewText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppUIConstants.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}
