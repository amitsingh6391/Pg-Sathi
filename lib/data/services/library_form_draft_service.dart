import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/library.dart';

/// Service to persist library form draft data.
class LibraryFormDraftService {
  LibraryFormDraftService(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyDraft = 'library_form_draft';
  static const String _keyCurrentSection = 'library_form_current_section';
  static const String _keyOwnerId = 'library_form_owner_id';

  /// Saves draft library data.
  Future<void> saveDraft({
    required Library library,
    required int currentSection,
    required String ownerId,
  }) async {
    try {
      // Convert library to JSON
      final libraryJson = {
        'id': library.id,
        'ownerId': library.ownerId,
        'name': library.name,
        'fullAddress': library.fullAddress ?? '',
        'area': library.area ?? '',
        'latitude': library.latitude,
        'longitude': library.longitude,
        'capacity': library.capacity,
        'hasWifi': library.hasWifi,
        'hasAC': library.hasAC,
        'hasPowerBackup': library.hasPowerBackup,
        'hasWashroom': library.hasWashroom,
        'hasDrinkingWater': library.hasDrinkingWater,
        'hasCCTV': library.hasCCTV,
        'ownerUpiId': library.ownerUpiId,
        'ownerPhone': library.ownerPhone,
        'totalSeatCapacity': library.totalSeatCapacity,
      };

      final jsonString = jsonEncode(libraryJson);
      await _prefs.setString(_keyDraft, jsonString);
      debugPrint('💾 [DraftService] Draft saved to SharedPreferences');
      await _prefs.setInt(_keyCurrentSection, currentSection);
      await _prefs.setString(_keyOwnerId, ownerId);
    } catch (e) {
      // Silently fail - draft saving is not critical
      // Error is ignored to prevent breaking the form flow
    }
  }

  /// Loads draft library data.
  LibraryDraft? loadDraft() {
    try {
      final draftJson = _prefs.getString(_keyDraft);
      final currentSection = _prefs.getInt(_keyCurrentSection) ?? 0;
      final ownerId = _prefs.getString(_keyOwnerId);

      if (draftJson == null || ownerId == null) {
        return null;
      }

      final data = jsonDecode(draftJson) as Map<String, dynamic>;

      // Helper to convert empty strings to null
      String? stringOrNull(String key) {
        final value = data[key];
        if (value == null) return null;
        if (value is String) {
          return value.trim().isEmpty ? null : value.trim();
        }
        return null;
      }

      final library = Library(
        id: data['id'] as String? ?? const Uuid().v4(),
        ownerId: data['ownerId'] as String? ?? ownerId,
        name: data['name'] as String? ?? '',
        fullAddress: stringOrNull('fullAddress'),
        area: stringOrNull('area'),
        latitude: data['latitude'] as double?,
        longitude: data['longitude'] as double?,
        capacity: data['capacity'] as int? ?? 0,
        hasWifi: data['hasWifi'] as bool? ?? false,
        hasAC: data['hasAC'] as bool? ?? false,
        hasPowerBackup: data['hasPowerBackup'] as bool? ?? false,
        hasWashroom: data['hasWashroom'] as bool? ?? false,
        hasDrinkingWater: data['hasDrinkingWater'] as bool? ?? false,
        hasCCTV: data['hasCCTV'] as bool? ?? false,
        ownerUpiId: stringOrNull('ownerUpiId'),
        ownerPhone: stringOrNull('ownerPhone'),
        totalSeatCapacity: data['totalSeatCapacity'] as int?,
      );

      return LibraryDraft(
        library: library,
        currentSection: currentSection,
        ownerId: ownerId,
      );
    } catch (e) {
      // Silently fail - draft loading is not critical
      return null;
    }
  }

  /// Clears draft data.
  Future<void> clearDraft() async {
    try {
      await _prefs.remove(_keyDraft);
      await _prefs.remove(_keyCurrentSection);
      await _prefs.remove(_keyOwnerId);
    } catch (e) {
      // Silently fail - draft clearing is not critical
    }
  }

  /// Checks if draft exists.
  bool hasDraft() {
    return _prefs.getString(_keyDraft) != null;
  }
}

/// Draft data model.
class LibraryDraft {
  const LibraryDraft({
    required this.library,
    required this.currentSection,
    required this.ownerId,
  });

  final Library library;
  final int currentSection;
  final String ownerId;
}
