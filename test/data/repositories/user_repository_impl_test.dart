import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/user_repository_impl.dart';
import 'package:pg_manager/domain/entities/user.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserRepositoryImpl(firestore: fakeFirestore);
  });

  final testUser = const User(
    id: 'user-1',
    name: 'John Doe',
    email: 'john@example.com',
    phone: '1234567890',
    role: UserRole.student,
  );

  group('UserRepositoryImpl', () {
    group('createUser', () {
      test('should_create_user_successfully', () async {
        // Act
        final result = await repository.createUser(testUser);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.id, testUser.id);
          expect(r.name, testUser.name);
          expect(r.email, testUser.email);
        });

        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUser.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()!['name'], testUser.name);
      });
    });

    group('getUserById', () {
      test('should_return_user_when_exists', () async {
        // Arrange
        await repository.createUser(testUser);

        // Act
        final result = await repository.getUserById(testUser.id);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.id, testUser.id);
          expect(r.name, testUser.name);
        });
      });

      test('should_return_failure_when_user_not_found', () async {
        // Act
        final result = await repository.getUserById('non-existent-id');

        // Assert
        expect(result.isLeft(), true);
      });
    });

    group('getUserByEmail', () {
      test('should_return_user_when_email_exists', () async {
        // Arrange
        await repository.createUser(testUser);

        // Act
        final result = await repository.getUserByEmail(testUser.email!);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r, isNotNull);
          expect(r!.email, testUser.email);
        });
      });

      test('should_return_null_when_email_not_found', () async {
        // Act
        final result = await repository.getUserByEmail('notfound@example.com');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isNull),
        );
      });
    });

    group('updateUser', () {
      test('should_update_user_successfully', () async {
        // Arrange
        await repository.createUser(testUser);
        final updatedUser = testUser.copyWith(name: 'Jane Doe');

        // Act
        final result = await repository.updateUser(updatedUser);

        // Assert
        expect(result.isRight(), true);

        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUser.id)
            .get();
        expect(doc.data()!['name'], 'Jane Doe');
      });
    });

    group('userExists', () {
      test('should_return_true_when_user_exists', () async {
        // Arrange
        await repository.createUser(testUser);

        // Act
        final result = await repository.userExists(testUser.id);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, true),
        );
      });

      test('should_return_false_when_user_does_not_exist', () async {
        // Act
        final result = await repository.userExists('non-existent-id');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, false),
        );
      });
    });
  });
}
