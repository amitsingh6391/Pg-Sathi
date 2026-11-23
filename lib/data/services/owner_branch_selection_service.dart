import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which branch (library) an owner last selected so the dashboard
/// reopens on the same branch after an app restart or re-navigation, instead
/// of resetting to the first branch. Keyed per owner.
class OwnerBranchSelectionService {
  static const _keyPrefix = 'owner_selected_library_';

  final SharedPreferences _prefs;

  OwnerBranchSelectionService(this._prefs);

  /// The library ID the owner last selected, or null if never saved.
  String? getSelectedLibraryId(String ownerId) {
    return _prefs.getString('$_keyPrefix$ownerId');
  }

  /// Persist the library the owner selected.
  Future<void> setSelectedLibraryId(String ownerId, String libraryId) async {
    await _prefs.setString('$_keyPrefix$ownerId', libraryId);
  }
}
