import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Four-step indicator: Pick file -> Preview -> Importing -> Done.
class ImportStepper extends StatelessWidget {
  const ImportStepper({required this.currentStep, super.key});

  /// 0 = pick file, 1 = preview, 2 = importing, 3 = done.
  final int currentStep;

  static const _labels = ['Pick file', 'Preview', 'Importing', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      decoration: const BoxDecoration(color: AppUIConstants.surface),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _StepDot(
              index: i,
              label: _labels[i],
              done: i < currentStep,
              active: i == currentStep,
            ),
            if (i < _labels.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i < currentStep
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlight = done || active;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppUIConstants.primaryLight
                : active
                ? AppUIConstants.primaryLight
                : AppUIConstants.surfaceMuted,
            border: Border.all(
              color: highlight ? Colors.transparent : AppUIConstants.border,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppUIConstants.primaryLight.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppUIConstants.background,
                )
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppUIConstants.textTertiary,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            color: highlight
                ? AppUIConstants.textPrimary
                : AppUIConstants.textTertiary,
          ),
        ),
      ],
    );
  }
}
