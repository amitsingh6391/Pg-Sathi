import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/notice.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/notice_usecases.dart';

/// Cubit for managing notices (Student side)
class StudentNoticeCubit extends Cubit<StudentNoticeState> {
  StudentNoticeCubit({
    required this.getActiveNoticesForStudent,
    required this.getReadStatusForStudent,
    required this.markNoticeAsRead,
    required this.getNoticeById,
    required this.incrementNoticeViewCount,
    required this.libraryRepository,
    required this.userRepository,
  }) : super(const StudentNoticeState());

  final GetActiveNoticesForStudent getActiveNoticesForStudent;
  final GetReadStatusForStudent getReadStatusForStudent;
  final MarkNoticeAsRead markNoticeAsRead;
  final GetNoticeById getNoticeById;
  final IncrementNoticeViewCount incrementNoticeViewCount;
  final LibraryRepository libraryRepository;
  final UserRepository userRepository;

  /// Load active notices for a student
  Future<void> loadNotices({
    required String libraryId,
    required String studentId,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(status: StudentNoticeStatus.loading));

    // Load both notices and read status in parallel
    final results = await Future.wait([
      getActiveNoticesForStudent(libraryId: libraryId, studentId: studentId),
      getReadStatusForStudent(studentId: studentId, libraryId: libraryId),
    ]);

    if (isClosed) return;
    final noticesResult = results[0];
    final readStatusResult = results[1];

    if (noticesResult.isLeft() || readStatusResult.isLeft()) {
      String errorMessage = 'Failed to load notices';
      noticesResult.fold((l) => errorMessage = l.message ?? errorMessage, (_) {});
      if (!isClosed) {
        emit(state.copyWith(
          status: StudentNoticeStatus.error,
          errorMessage: errorMessage,
        ));
      }
      return;
    }

    if (isClosed) return;
    noticesResult.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: StudentNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (noticesList) {
        if (isClosed) return;
        final notices = noticesList as List<Notice>;
        readStatusResult.fold(
          (failure) {
            if (!isClosed) {
              emit(state.copyWith(
                status: StudentNoticeStatus.error,
                errorMessage: failure.message,
              ));
            }
          },
          (readStatusMap) {
            if (isClosed) return;
            final readStatus = readStatusMap as Map<String, NoticeReadStatus>;
            // Separate read and unread notices
            final unreadNotices = <Notice>[];
            final readNotices = <Notice>[];

            for (final notice in notices) {
              final status = readStatus[notice.id];
              if (status != null && status.isRead) {
                readNotices.add(notice);
              } else {
                unreadNotices.add(notice);
              }
            }

            if (!isClosed) {
              emit(state.copyWith(
                status: StudentNoticeStatus.loaded,
                allNotices: notices,
                unreadNotices: unreadNotices,
                readNotices: readNotices,
                readStatus: readStatus,
                unreadCount: unreadNotices.length,
              ));
              // Prefetch library/owner info in one batch.
              _prefetchLibraryInfo(notices);
            }
          },
        );
      },
    );
  }

  /// Mark a notice as read
  Future<void> markAsRead({
    required String noticeId,
    required String studentId,
    required String libraryId,
  }) async {
    final result = await markNoticeAsRead(
      noticeId: noticeId,
      studentId: studentId,
      libraryId: libraryId,
    );

    if (isClosed) return;
    result.fold(
      (failure) {
        // Silently fail - don't disrupt user experience
      },
      (_) {
        if (isClosed) return;
        // Update local state
        final updatedReadStatus = Map<String, NoticeReadStatus>.from(state.readStatus);
        updatedReadStatus[noticeId] = NoticeReadStatus(
          noticeId: noticeId,
          studentId: studentId,
          libraryId: libraryId,
          isRead: true,
          readAt: DateTime.now(),
        );

        // Recalculate unread/read lists
        final unreadNotices = <Notice>[];
        final readNotices = <Notice>[];

        for (final notice in state.allNotices) {
          final status = updatedReadStatus[notice.id];
          if (status != null && status.isRead) {
            readNotices.add(notice);
          } else {
            unreadNotices.add(notice);
          }
        }

        if (!isClosed) {
          emit(state.copyWith(
            readStatus: updatedReadStatus,
            unreadNotices: unreadNotices,
            readNotices: readNotices,
            unreadCount: unreadNotices.length,
          ));
        }
      },
    );
  }

  /// View a notice (increment view count and mark as read)
  Future<void> viewNotice({
    required String noticeId,
    required String studentId,
    required String libraryId,
  }) async {
    // Increment view count
    await incrementNoticeViewCount(
      noticeId: noticeId,
      userId: studentId,
    );

    // Mark as read if not already read
    final readStatus = state.readStatus[noticeId];
    if (readStatus == null || !readStatus.isRead) {
      await markAsRead(
        noticeId: noticeId,
        studentId: studentId,
        libraryId: libraryId,
      );
    }
  }

  /// Get a specific notice by ID
  Future<Notice?> getNotice(String noticeId) async {
    final result = await getNoticeById(noticeId);
    return result.fold(
      (_) => null,
      (notice) => notice,
    );
  }

  /// Refresh notices
  Future<void> refresh({
    required String libraryId,
    required String studentId,
  }) async {
    await loadNotices(libraryId: libraryId, studentId: studentId);
  }

  /// Load notices from multiple libraries (for students with multiple memberships)
  Future<void> loadNoticesFromMultipleLibraries({
    required List<String> libraryIds,
    required String studentId,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(status: StudentNoticeStatus.loading));

    try {
      // Fetch notices from all libraries in parallel
      final noticesResults = await Future.wait(
        libraryIds.map((libraryId) => 
          getActiveNoticesForStudent(libraryId: libraryId, studentId: studentId)
        ),
      );

      // Fetch read status for all libraries
      final readStatusResults = await Future.wait(
        libraryIds.map((libraryId) => 
          getReadStatusForStudent(studentId: studentId, libraryId: libraryId)
        ),
      );

      if (isClosed) return;

      // Combine all notices from all libraries
      final allNoticesList = <Notice>[];
      final allReadStatus = <String, NoticeReadStatus>{};

      for (var i = 0; i < libraryIds.length; i++) {
        final noticesResult = noticesResults[i];
        final readStatusResult = readStatusResults[i];

        noticesResult.fold(
          (failure) => null,
          (notices) {
            allNoticesList.addAll(notices);
          },
        );

        readStatusResult.fold(
          (failure) => null,
          (statusMap) {
            allReadStatus.addAll(statusMap);
          },
        );
      }

      // Sort notices by published date (newest first)
      allNoticesList.sort((a, b) => 
        (b.publishedAt ?? b.createdAt).compareTo(a.publishedAt ?? a.createdAt)
      );

      // Separate read and unread notices
      final unreadNotices = <Notice>[];
      final readNotices = <Notice>[];

      for (final notice in allNoticesList) {
        final status = allReadStatus[notice.id];
        if (status != null && status.isRead) {
          readNotices.add(notice);
        } else {
          unreadNotices.add(notice);
        }
      }

      if (!isClosed) {
        emit(state.copyWith(
          status: StudentNoticeStatus.loaded,
          allNotices: allNoticesList,
          unreadNotices: unreadNotices,
          readNotices: readNotices,
          readStatus: allReadStatus,
          unreadCount: unreadNotices.length,
        ));
        // Prefetch library/owner info in one batch (non-blocking).
        _prefetchLibraryInfo(allNoticesList);
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: StudentNoticeStatus.error,
          errorMessage: 'Failed to load notices: $e',
        ));
      }
    }
  }

  /// Refresh notices from multiple libraries
  Future<void> refreshMultipleLibraries({
    required List<String> libraryIds,
    required String studentId,
  }) async {
    await loadNoticesFromMultipleLibraries(
      libraryIds: libraryIds,
      studentId: studentId,
    );
  }

  /// Prefetches library names and owner names for all loaded notices in a
  /// single batch, avoiding N+1 per-card Firestore reads.
  Future<void> _prefetchLibraryInfo(List<Notice> notices) async {
    final uniqueLibraryIds = notices.map((n) => n.libraryId).toSet().toList();
    final uniqueOwnerIds = notices.map((n) => n.ownerId).toSet().toList();

    // Fetch libraries and owners in parallel.
    final libraryFuture = Future.wait(
      uniqueLibraryIds.map((id) => libraryRepository.getLibraryById(id)),
    );
    final ownerFuture = userRepository.getUsersByIds(uniqueOwnerIds);
    final libraryResults = await libraryFuture;
    final ownerResult = await ownerFuture;

    if (isClosed) return;

    final cache = <String, NoticeLibraryInfo>{};

    // Build cache from library results
    for (var i = 0; i < uniqueLibraryIds.length; i++) {
      final libId = uniqueLibraryIds[i];
      libraryResults[i].fold(
        (_) {},
        (lib) {
          if (lib != null) {
            cache[libId] = NoticeLibraryInfo(
              libraryName: lib.name,
              ownerName: null,
            );
          }
        },
      );
    }

    // Merge owner names from batch user fetch
    ownerResult.fold(
      (_) {},
      (usersMap) {
        for (final notice in notices) {
          final user = usersMap[notice.ownerId];
          if (user != null && cache.containsKey(notice.libraryId)) {
            cache[notice.libraryId] = cache[notice.libraryId]!.copyWith(
              ownerName: user.displayName,
            );
          } else if (user != null) {
            cache[notice.libraryId] = NoticeLibraryInfo(
              libraryName: null,
              ownerName: user.displayName,
            );
          }
        }
      },
    );

    if (!isClosed) {
      emit(state.copyWith(libraryInfoCache: cache));
    }
  }
}

/// State for Student Notice board
class StudentNoticeState extends Equatable {
  const StudentNoticeState({
    this.status = StudentNoticeStatus.initial,
    this.allNotices = const [],
    this.unreadNotices = const [],
    this.readNotices = const [],
    this.readStatus = const {},
    this.unreadCount = 0,
    this.errorMessage,
    this.libraryInfoCache = const {},
  });

  final StudentNoticeStatus status;
  final List<Notice> allNotices;
  final List<Notice> unreadNotices;
  final List<Notice> readNotices;
  final Map<String, NoticeReadStatus> readStatus;
  final int unreadCount;
  final String? errorMessage;

  /// Pre-fetched library/owner display info keyed by libraryId.
  /// Eliminates per-card Firestore reads.
  final Map<String, NoticeLibraryInfo> libraryInfoCache;

  StudentNoticeState copyWith({
    StudentNoticeStatus? status,
    List<Notice>? allNotices,
    List<Notice>? unreadNotices,
    List<Notice>? readNotices,
    Map<String, NoticeReadStatus>? readStatus,
    int? unreadCount,
    String? errorMessage,
    Map<String, NoticeLibraryInfo>? libraryInfoCache,
  }) {
    return StudentNoticeState(
      status: status ?? this.status,
      allNotices: allNotices ?? this.allNotices,
      unreadNotices: unreadNotices ?? this.unreadNotices,
      readNotices: readNotices ?? this.readNotices,
      readStatus: readStatus ?? this.readStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage ?? this.errorMessage,
      libraryInfoCache: libraryInfoCache ?? this.libraryInfoCache,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allNotices,
        unreadNotices,
        readNotices,
        readStatus,
        unreadCount,
        errorMessage,
        libraryInfoCache,
      ];
}

/// Cached library/owner display info for notice cards.
class NoticeLibraryInfo extends Equatable {
  const NoticeLibraryInfo({this.libraryName, this.ownerName});

  final String? libraryName;
  final String? ownerName;

  NoticeLibraryInfo copyWith({String? libraryName, String? ownerName}) {
    return NoticeLibraryInfo(
      libraryName: libraryName ?? this.libraryName,
      ownerName: ownerName ?? this.ownerName,
    );
  }

  @override
  List<Object?> get props => [libraryName, ownerName];
}

enum StudentNoticeStatus {
  initial,
  loading,
  loaded,
  error,
}
