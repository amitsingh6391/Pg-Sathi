import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/current_affair.dart';
import '../../../domain/usecases/current_affairs/current_affairs_usecases.dart';
import '../../../domain/usecases/current_affairs/generate_on_demand_current_affairs.dart';

/// Page size for admin current affairs list.
const int _kAdminPageSize = 15;

/// Cubit for admin management of current affairs.
class CurrentAffairsManagementCubit
    extends Cubit<CurrentAffairsManagementState> {
  CurrentAffairsManagementCubit({
    required this.createCurrentAffair,
    required this.getCurrentAffairs,
    required this.deleteCurrentAffair,
    required this.generateOnDemand,
  }) : super(const CurrentAffairsManagementState());

  final CreateCurrentAffair createCurrentAffair;
  final GetCurrentAffairs getCurrentAffairs;
  final DeleteCurrentAffair deleteCurrentAffair;
  final GenerateOnDemandCurrentAffairs generateOnDemand;

  /// Loads the first page of current affairs.
  Future<void> loadAll() async {
    if (isClosed) return;
    emit(state.copyWith(
      status: CAManagementStatus.loading,
      items: const [],
      hasMore: false,
      lastDocumentId: null,
    ));

    final result = await getCurrentAffairs(limit: _kAdminPageSize);

    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(
        status: CAManagementStatus.error,
        failure: failure,
      )),
      (page) => emit(state.copyWith(
        status: CAManagementStatus.loaded,
        items: page.items,
        hasMore: page.hasMore,
        lastDocumentId: page.lastDocumentId,
      )),
    );
  }

  /// Loads the next page and appends to existing list.
  Future<void> loadMore() async {
    if (isClosed || state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await getCurrentAffairs(
      limit: _kAdminPageSize,
      startAfterId: state.lastDocumentId,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed) emit(state.copyWith(isLoadingMore: false));
      },
      (page) {
        if (!isClosed) {
          emit(state.copyWith(
            items: [...state.items, ...page.items],
            hasMore: page.hasMore,
            lastDocumentId: page.lastDocumentId,
            isLoadingMore: false,
          ));
        }
      },
    );
  }

  /// Creates a new current affair with push notification.
  Future<bool> create({
    required String title,
    required String summary,
    required String content,
    required CurrentAffairsCategory category,
    String? source,
    required String createdBy,
    bool sendNotification = true,
  }) async {
    if (isClosed) return false;
    emit(state.copyWith(isCreating: true));

    final result = await createCurrentAffair(
      title: title,
      summary: summary,
      content: content,
      category: category,
      source: source,
      createdBy: createdBy,
      sendNotification: sendNotification,
    );

    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(isCreating: false, failure: failure));
        return false;
      },
      (affair) {
        final updated = [affair, ...state.items];
        emit(state.copyWith(isCreating: false, items: updated));
        return true;
      },
    );
  }

  /// Deletes a current affair.
  Future<void> delete(String id) async {
    final result = await deleteCurrentAffair(id);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) {
        final updated = state.items.where((i) => i.id != id).toList();
        emit(state.copyWith(items: updated));
      },
    );
  }

  /// Generates articles on-demand using Groq AI via Cloud Function.
  /// No Cloud Function dependency — runs entirely in the app.
  Future<bool> generateWithAi({
    int count = 3,
    String? category,
  }) async {
    if (isClosed) return false;
    emit(state.copyWith(isAiGenerating: true));

    debugPrint('[AI Generate] Starting client-side: count=$count, '
        'category=$category');

    final result = await generateOnDemand(
      count: count,
      category: category,
      sendNotification: true,
    );

    if (isClosed) return false;

    return result.fold(
      (failure) {
        debugPrint('[AI Generate] Failed: ${failure.message}');
        emit(state.copyWith(
          isAiGenerating: false,
          failure: failure,
        ));
        return false;
      },
      (articles) {
        debugPrint('[AI Generate] Success: ${articles.length} articles');
        // Refresh list to show newly generated articles.
        loadAll();
        emit(state.copyWith(isAiGenerating: false));
        return true;
      },
    );
  }
}

// =============================================================================
// State
// =============================================================================

class CurrentAffairsManagementState extends Equatable {
  const CurrentAffairsManagementState({
    this.status = CAManagementStatus.initial,
    this.items = const [],
    this.isCreating = false,
    this.isAiGenerating = false,
    this.failure,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.lastDocumentId,
  });

  final CAManagementStatus status;
  final List<CurrentAffair> items;
  final bool isCreating;
  final bool isAiGenerating;
  final Failure? failure;

  /// Pagination state.
  final bool hasMore;
  final bool isLoadingMore;
  final String? lastDocumentId;

  bool get isLoading => status == CAManagementStatus.loading;
  bool get isLoaded => status == CAManagementStatus.loaded;
  bool get isBusy => isCreating || isAiGenerating;

  CurrentAffairsManagementState copyWith({
    CAManagementStatus? status,
    List<CurrentAffair>? items,
    bool? isCreating,
    bool? isAiGenerating,
    Failure? failure,
    bool? hasMore,
    bool? isLoadingMore,
    String? lastDocumentId,
  }) {
    return CurrentAffairsManagementState(
      status: status ?? this.status,
      items: items ?? this.items,
      isCreating: isCreating ?? this.isCreating,
      isAiGenerating: isAiGenerating ?? this.isAiGenerating,
      failure: failure,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocumentId: lastDocumentId ?? this.lastDocumentId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    isCreating,
    isAiGenerating,
    failure,
    hasMore,
    isLoadingMore,
    lastDocumentId,
  ];
}

enum CAManagementStatus { initial, loading, loaded, error }
