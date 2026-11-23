import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../data/services/registration_qr_card_preference.dart';
import '../../../../domain/entities/library.dart';
import '../../../core/app_ui_constants.dart';
import 'registration_qr_banner.dart';

/// Dashboard entry for the registration QR. The owner can hide the card and
/// bring it back from the compact row that replaces it.
///
/// Wiring: `RegistrationQrSection(library: library, onOpen: () =>
/// Navigator.push(context, MaterialPageRoute(builder: (_) =>
/// PgQrScreen(library: library))))`.
class RegistrationQrSection extends StatefulWidget {
  const RegistrationQrSection({
    super.key,
    required this.library,
    required this.onOpen,
  });

  final Library library;
  final VoidCallback onOpen;

  @override
  State<RegistrationQrSection> createState() => _RegistrationQrSectionState();
}

class _RegistrationQrSectionState extends State<RegistrationQrSection> {
  final _preference = sl<RegistrationQrCardPreference>();
  late bool _hidden = _preference.isHidden;

  void _setHidden(bool hidden) {
    setState(() => _hidden = hidden);
    _preference.setHidden(hidden);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _hidden
          ? _CollapsedRow(
              key: const ValueKey('collapsed'),
              onOpen: widget.onOpen,
              onShow: () => _setHidden(false),
            )
          : RegistrationQrBanner(
              key: const ValueKey('banner'),
              library: widget.library,
              onTap: widget.onOpen,
              onHide: () => _setHidden(true),
            ),
    );
  }
}

class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({super.key, required this.onOpen, required this.onShow});

  final VoidCallback onOpen;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUIConstants.surface,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 20,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Registration QR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShow,
                child: const Text(
                  'Show card',
                  style: TextStyle(color: AppUIConstants.primaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
