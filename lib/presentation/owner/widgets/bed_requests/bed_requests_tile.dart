import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/repositories/membership_repository.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../screens/bed_requests_screen.dart';

/// Dashboard tile that opens [BedRequestsScreen] and shows how many resident
/// requests are waiting. Refreshes its count when the screen is closed.
class BedRequestsTile extends StatefulWidget {
  const BedRequestsTile({super.key, required this.library});

  final Library library;

  @override
  State<BedRequestsTile> createState() => _BedRequestsTileState();
}

class _BedRequestsTileState extends State<BedRequestsTile> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final result = await sl<MembershipRepository>()
        .getPendingSeatRequestMemberships(widget.library.id);
    if (!mounted) return;
    setState(() => _count = result.fold((_) => 0, (list) => list.length));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BedRequestsScreen(library: widget.library),
          ),
        );
        _loadCount();
      },
      child: Row(
        children: [
          const Icon(
            Icons.how_to_reg_outlined,
            color: AppUIConstants.textSecondary,
          ),
          const SizedBox(width: AppUIConstants.spacingMd),
          const Expanded(
            child: Text('Bed requests', style: AppUIConstants.bodyLg),
          ),
          if (_count > 0)
            PremiumStatusPill('$_count new', color: AppUIConstants.accent),
          const SizedBox(width: AppUIConstants.spacingSm),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppUIConstants.textTertiary,
          ),
        ],
      ),
    );
  }
}
