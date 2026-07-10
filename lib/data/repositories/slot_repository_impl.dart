import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/custom_slot.dart';
import '../../domain/repositories/slot_repository.dart';
import '../mappers/slot_mapper.dart';
import '../models/slot_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of SlotRepository.
/// Slots are stored in subcollection: /libraries/{libraryId}/slots/{slotId}
class SlotRepositoryImpl implements SlotRepository {
  SlotRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _slotsCollection(
    String libraryId,
  ) => firestore
      .collection('libraries')
      .doc(libraryId)
      .collection(SlotDto.collectionName);

  @override
  Future<Either<Failure, CustomSlot>> createSlot(CustomSlot slot) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = SlotMapper.toDto(slot);
      await _slotsCollection(
        slot.libraryId,
      ).doc(slot.id).set(dto.toFirestore());
      return slot;
    });
  }

  @override
  Future<Either<Failure, CustomSlot>> updateSlot(CustomSlot slot) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = SlotMapper.toDto(slot);
      await _slotsCollection(
        slot.libraryId,
      ).doc(slot.id).update(dto.toFirestore());
      return slot;
    });
  }

  @override
  Future<Either<Failure, void>> deleteSlot(
    String libraryId,
    String slotId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      await _slotsCollection(libraryId).doc(slotId).delete();
    });
  }

  @override
  Future<Either<Failure, CustomSlot?>> getSlotById(
    String libraryId,
    String slotId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _slotsCollection(libraryId).doc(slotId).get();
      if (!doc.exists) {
        return null;
      }
      final dto = SlotDto.fromFirestore(doc);
      return SlotMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, List<CustomSlot>>> getSlotsByLibraryId(
    String libraryId, {
    bool? activeOnly,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      Query<Map<String, dynamic>> query = _slotsCollection(libraryId);

      if (activeOnly == true) {
        query = query.where('isActive', isEqualTo: true);
      }

      final querySnapshot = await query.orderBy('startTime').get();

      return querySnapshot.docs.map((doc) {
        final dto = SlotDto.fromFirestore(doc);
        return SlotMapper.toEntity(dto);
      }).toList();
    });
  }

  @override
  Future<Either<Failure, List<CustomSlot>>> getActiveSlotsByLibraryId(
    String libraryId,
  ) async {
    return getSlotsByLibraryId(libraryId, activeOnly: true);
  }

  @override
  Future<Either<Failure, bool>> hasOverlappingSlot(
    String libraryId,
    CustomSlot slot,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Get all active slots for the library
      final slotsResult = await getActiveSlotsByLibraryId(libraryId);

      return slotsResult.fold((failure) => throw Exception(failure.message), (
        slots,
      ) {
        // Check if any slot overlaps with the given slot
        for (final existingSlot in slots) {
          if (slot.overlapsWith(existingSlot)) {
            return true;
          }
        }
        return false;
      });
    });
  }
}
