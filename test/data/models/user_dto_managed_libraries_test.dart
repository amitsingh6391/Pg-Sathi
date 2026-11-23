import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/models/user_dto.dart';

void main() {
  group('UserDto.readManagedLibraryIds', () {
    test('should_read_list_field', () {
      expect(
        UserDto.readManagedLibraryIds({
          'managedLibraryIds': ['a', 'b'],
          'managedLibraryId': 'a',
        }),
        ['a', 'b'],
      );
    });

    test('should_fall_back_to_legacy_single_id', () {
      expect(UserDto.readManagedLibraryIds({'managedLibraryId': 'a'}), ['a']);
    });

    test('should_return_empty_when_not_a_manager', () {
      expect(UserDto.readManagedLibraryIds({}), isEmpty);
      expect(UserDto.readManagedLibraryIds(null), isEmpty);
    });

    test('should_read_invite_keys', () {
      expect(
        UserDto.readManagedLibraryIds(
          {'libraryId': 'x'},
          listKey: 'libraryIds',
          legacyKey: 'libraryId',
        ),
        ['x'],
      );
    });
  });
}
