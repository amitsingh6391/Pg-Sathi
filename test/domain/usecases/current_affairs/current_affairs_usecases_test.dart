import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/current_affair.dart';
import 'package:pg_manager/domain/repositories/current_affairs_repository.dart';
import 'package:pg_manager/domain/usecases/current_affairs/current_affairs_usecases.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'current_affairs_usecases_test.mocks.dart';

@GenerateMocks([CurrentAffairsRepository])
void main() {
  late MockCurrentAffairsRepository mockRepo;

  setUp(() {
    mockRepo = MockCurrentAffairsRepository();
  });

  final testAffair = CurrentAffair(
    id: 'ca-1',
    title: 'India Launches Chandrayaan-4',
    summary: 'ISRO announces the next lunar mission.',
    content: 'Full article content here...',
    category: CurrentAffairsCategory.science,
    createdAt: DateTime(2026, 2, 1),
    source: 'ISRO',
    publishedAt: DateTime(2026, 2, 1),
    createdBy: 'admin-1',
  );

  group('GetCurrentAffairs', () {
    late GetCurrentAffairs useCase;

    setUp(() => useCase = GetCurrentAffairs(repository: mockRepo));

    test('should_return_paginated_result_when_repository_succeeds', () async {
      when(mockRepo.getAll(
        category: anyNamed('category'),
        limit: anyNamed('limit'),
        startAfterId: anyNamed('startAfterId'),
      )).thenAnswer((_) async => Right(PaginatedCurrentAffairs(
            items: [testAffair],
            hasMore: false,
            lastDocumentId: 'ca-1',
          )));

      final result = await useCase();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (page) {
          expect(page.items.length, 1);
          expect(page.items.first.title, 'India Launches Chandrayaan-4');
          expect(page.hasMore, false);
          expect(page.lastDocumentId, 'ca-1');
        },
      );
    });

    test('should_pass_category_filter_and_default_limit', () async {
      when(mockRepo.getAll(
        category: anyNamed('category'),
        limit: anyNamed('limit'),
        startAfterId: anyNamed('startAfterId'),
      )).thenAnswer((_) async => Right(PaginatedCurrentAffairs(
            items: const [],
            hasMore: false,
          )));

      await useCase(category: CurrentAffairsCategory.science);

      verify(mockRepo.getAll(
        category: CurrentAffairsCategory.science,
        limit: 10,
        startAfterId: null,
      )).called(1);
    });

    test('should_pass_startAfterId_for_pagination', () async {
      when(mockRepo.getAll(
        category: anyNamed('category'),
        limit: anyNamed('limit'),
        startAfterId: anyNamed('startAfterId'),
      )).thenAnswer((_) async => Right(PaginatedCurrentAffairs(
            items: const [],
            hasMore: false,
          )));

      await useCase(startAfterId: 'ca-5', limit: 10);

      verify(mockRepo.getAll(
        category: null,
        limit: 10,
        startAfterId: 'ca-5',
      )).called(1);
    });

    test('should_indicate_hasMore_when_more_pages_exist', () async {
      when(mockRepo.getAll(
        category: anyNamed('category'),
        limit: anyNamed('limit'),
        startAfterId: anyNamed('startAfterId'),
      )).thenAnswer((_) async => Right(PaginatedCurrentAffairs(
            items: [testAffair],
            hasMore: true,
            lastDocumentId: 'ca-1',
          )));

      final result = await useCase(limit: 1);

      result.fold(
        (_) => fail('Expected Right'),
        (page) {
          expect(page.hasMore, true);
          expect(page.lastDocumentId, 'ca-1');
        },
      );
    });

    test('should_return_failure_when_repository_fails', () async {
      when(mockRepo.getAll(
        category: anyNamed('category'),
        limit: anyNamed('limit'),
        startAfterId: anyNamed('startAfterId'),
      )).thenAnswer(
        (_) async =>
            const Left(CurrentAffairsFailure(message: 'Network error')),
      );

      final result = await useCase();

      expect(result.isLeft(), true);
    });
  });

  group('GetCurrentAffairById', () {
    late GetCurrentAffairById useCase;

    setUp(() => useCase = GetCurrentAffairById(repository: mockRepo));

    test('should_return_article_when_found', () async {
      when(mockRepo.getById('ca-1'))
          .thenAnswer((_) async => Right(testAffair));

      final result = await useCase('ca-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (affair) => expect(affair.id, 'ca-1'),
      );
    });

    test('should_return_failure_when_not_found', () async {
      when(mockRepo.getById('nonexistent'))
          .thenAnswer((_) async => const Left(
                CurrentAffairsFailure(message: 'Article not found'),
              ));

      final result = await useCase('nonexistent');

      expect(result.isLeft(), true);
    });
  });

  group('CreateCurrentAffair', () {
    late CreateCurrentAffair useCase;

    setUp(() => useCase = CreateCurrentAffair(repository: mockRepo));

    test('should_create_and_return_article', () async {
      when(mockRepo.create(
        title: anyNamed('title'),
        summary: anyNamed('summary'),
        content: anyNamed('content'),
        category: anyNamed('category'),
        source: anyNamed('source'),
        imageUrl: anyNamed('imageUrl'),
        createdBy: anyNamed('createdBy'),
        sendNotification: anyNamed('sendNotification'),
      )).thenAnswer((_) async => Right(testAffair));

      final result = await useCase(
        title: 'India Launches Chandrayaan-4',
        summary: 'ISRO announces the next lunar mission.',
        content: 'Full article content here...',
        category: CurrentAffairsCategory.science,
        source: 'ISRO',
        createdBy: 'admin-1',
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (affair) => expect(affair.title, 'India Launches Chandrayaan-4'),
      );
    });

    test('should_pass_send_notification_flag', () async {
      when(mockRepo.create(
        title: anyNamed('title'),
        summary: anyNamed('summary'),
        content: anyNamed('content'),
        category: anyNamed('category'),
        source: anyNamed('source'),
        imageUrl: anyNamed('imageUrl'),
        createdBy: anyNamed('createdBy'),
        sendNotification: anyNamed('sendNotification'),
      )).thenAnswer((_) async => Right(testAffair));

      await useCase(
        title: 'Test',
        summary: 'Test',
        content: 'Test',
        category: CurrentAffairsCategory.national,
        createdBy: 'admin-1',
        sendNotification: false,
      );

      verify(mockRepo.create(
        title: 'Test',
        summary: 'Test',
        content: 'Test',
        category: CurrentAffairsCategory.national,
        source: null,
        imageUrl: null,
        createdBy: 'admin-1',
        sendNotification: false,
      )).called(1);
    });
  });

  group('ToggleCurrentAffairBookmark', () {
    late ToggleCurrentAffairBookmark useCase;

    setUp(() => useCase = ToggleCurrentAffairBookmark(repository: mockRepo));

    test('should_toggle_bookmark_on', () async {
      when(mockRepo.toggleBookmark(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
        isBookmarked: anyNamed('isBookmarked'),
      )).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isBookmarked: true,
      );

      expect(result.isRight(), true);
      verify(mockRepo.toggleBookmark(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isBookmarked: true,
      )).called(1);
    });
  });

  group('DeleteCurrentAffair', () {
    late DeleteCurrentAffair useCase;

    setUp(() => useCase = DeleteCurrentAffair(repository: mockRepo));

    test('should_delete_article', () async {
      when(mockRepo.delete('ca-1'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('ca-1');

      expect(result.isRight(), true);
      verify(mockRepo.delete('ca-1')).called(1);
    });
  });

  group('RecordArticleView', () {
    late RecordArticleView useCase;

    setUp(() => useCase = RecordArticleView(repository: mockRepo));

    test('should_record_view_when_repository_succeeds', () async {
      when(mockRepo.recordView(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
      );

      expect(result.isRight(), true);
      verify(mockRepo.recordView(
        currentAffairId: 'ca-1',
        userId: 'user-1',
      )).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      when(mockRepo.recordView(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
      )).thenAnswer(
        (_) async =>
            const Left(CurrentAffairsFailure(message: 'Failed to record')),
      );

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
      );

      expect(result.isLeft(), true);
    });
  });

  group('ToggleArticleLike', () {
    late ToggleArticleLike useCase;

    setUp(() => useCase = ToggleArticleLike(repository: mockRepo));

    test('should_like_article_when_isLiked_true', () async {
      when(mockRepo.toggleLike(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
        isLiked: anyNamed('isLiked'),
      )).thenAnswer((_) async => const Right(true));

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isLiked: true,
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (liked) => expect(liked, true),
      );
      verify(mockRepo.toggleLike(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isLiked: true,
      )).called(1);
    });

    test('should_unlike_article_when_isLiked_false', () async {
      when(mockRepo.toggleLike(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
        isLiked: anyNamed('isLiked'),
      )).thenAnswer((_) async => const Right(false));

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isLiked: false,
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (liked) => expect(liked, false),
      );
    });

    test('should_return_failure_when_repository_fails', () async {
      when(mockRepo.toggleLike(
        currentAffairId: anyNamed('currentAffairId'),
        userId: anyNamed('userId'),
        isLiked: anyNamed('isLiked'),
      )).thenAnswer(
        (_) async =>
            const Left(CurrentAffairsFailure(message: 'Toggle failed')),
      );

      final result = await useCase(
        currentAffairId: 'ca-1',
        userId: 'user-1',
        isLiked: true,
      );

      expect(result.isLeft(), true);
    });
  });

  group('CurrentAffair entity', () {
    test('should_default_viewCount_likeCount_isLiked', () {
      expect(testAffair.viewCount, 0);
      expect(testAffair.likeCount, 0);
      expect(testAffair.isLiked, false);
    });

    test('should_copyWith_engagement_fields', () {
      final updated = testAffair.copyWith(
        viewCount: 42,
        likeCount: 7,
        isLiked: true,
      );

      expect(updated.viewCount, 42);
      expect(updated.likeCount, 7);
      expect(updated.isLiked, true);
      expect(updated.title, testAffair.title);
    });

    test('should_include_engagement_fields_in_equality', () {
      final a = testAffair.copyWith(likeCount: 5);
      final b = testAffair.copyWith(likeCount: 10);

      expect(a, isNot(equals(b)));
    });
  });
}
