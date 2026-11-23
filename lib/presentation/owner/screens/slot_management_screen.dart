import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/slot_management_cubit.dart';
import '../widgets/room_types/room_types_panel.dart';

/// Room types & beds of a PG (stored as custom slots).
class SlotManagementScreen extends StatefulWidget {
  const SlotManagementScreen({super.key, required this.library});

  final Library library;

  @override
  State<SlotManagementScreen> createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends State<SlotManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SlotManagementCubit>().loadSlots(widget.library.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(title: const Text('Room Types & Rent')),
      body: RoomTypesPanel(
        initialTotalBeds: widget.library.totalSeatCapacity,
        onTotalBedsChanged: (total) => context
            .read<SlotManagementCubit>()
            .updateTotalSeatCapacity(widget.library, total),
      ),
    );
  }
}
