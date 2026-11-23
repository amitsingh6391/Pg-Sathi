import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/core.dart';
import '../../../domain/usecases/reminder_template_usecases.dart';
import 'reminder_template_state.dart';

/// Loads, saves and removes the owner's reminder template.
class ReminderTemplateCubit extends Cubit<ReminderTemplateState> {
  ReminderTemplateCubit({
    required this.getReminderTemplate,
    required this.saveReminderTemplate,
    required this.clearReminderTemplate,
  }) : super(const ReminderTemplateState());

  final GetReminderTemplate getReminderTemplate;
  final SaveReminderTemplate saveReminderTemplate;
  final ClearReminderTemplate clearReminderTemplate;

  Future<void> load() async {
    final result = await getReminderTemplate(const NoParams());
    result.fold(
      (_) {},
      (template) => emit(ReminderTemplateState(template: template)),
    );
  }

  /// Returns false when the template could not be saved.
  Future<bool> save(String template) async {
    final result = await saveReminderTemplate(template);
    return result.fold((_) => false, (_) {
      emit(ReminderTemplateState(template: template));
      return true;
    });
  }

  /// Returns false when the template could not be removed.
  Future<bool> clear() async {
    final result = await clearReminderTemplate(const NoParams());
    return result.fold((_) => false, (_) {
      emit(const ReminderTemplateState());
      return true;
    });
  }
}
