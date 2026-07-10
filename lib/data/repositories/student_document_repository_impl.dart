import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/student_document.dart';
import '../../domain/failures/student_document_failures.dart';
import '../../domain/repositories/student_document_repository.dart';
import '../mappers/student_document_mapper.dart';
import '../models/student_document_dto.dart';
import '../services/storage_service.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of StudentDocumentRepository.
class StudentDocumentRepositoryImpl implements StudentDocumentRepository {
  StudentDocumentRepositoryImpl({
    required this.firestore,
    required this.storageService,
  });

  final FirebaseFirestore firestore;
  final StorageService storageService;

  CollectionReference<Map<String, dynamic>> get _documentsCollection =>
      firestore.collection(StudentDocumentDto.collectionName);

  @override
  Future<Either<Failure, StudentDocument>> uploadDocument({
    required String studentId,
    required String filePath,
    required String fileName,
    required StudentDocumentType fileType,
  }) async {
    // Check document count (max 2)
    try {
      final existingDocs = await _documentsCollection
          .where('studentId', isEqualTo: studentId)
          .get();

      if (existingDocs.docs.length >= 2) {
        return const Left(StudentDocumentLimitExceededFailure());
      }
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to check existing documents: ${e.toString()}',
        ),
      );
    }

    return FirebaseErrorHandler.guard(() async {
      // Upload file to Firebase Storage
      final file = File(filePath);
      final fileExtension = fileName.split('.').last;
      final storageFileName = '${const Uuid().v4()}.$fileExtension';
      final storagePath = 'students/$studentId/documents/';

      final downloadUrl = await storageService.uploadFile(
        file: file,
        path: storagePath,
        fileName: storageFileName,
        contentType: fileType.mimeType,
      );

      // Get file size
      final fileSize = await file.length();

      // Create document entity (pending approval by default)
      final document = StudentDocument(
        id: const Uuid().v4(),
        studentId: studentId,
        fileName: fileName,
        downloadUrl: downloadUrl,
        fileType: fileType,
        uploadedAt: DateTime.now(),
        fileSize: fileSize,
        approvalStatus: DocumentApprovalStatus.pending,
      );

      // Save to Firestore
      final dto = StudentDocumentMapper.toDto(document);
      await _documentsCollection.doc(document.id).set(dto.toFirestore());

      return document;
    });
  }

  @override
  Future<Either<Failure, List<StudentDocument>>> getStudentDocuments(
    String studentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _documentsCollection
          .where('studentId', isEqualTo: studentId)
          .get();

      final documents = query.docs.map((doc) {
        final dto = StudentDocumentDto.fromFirestore(doc);
        return StudentDocumentMapper.toEntity(dto);
      }).toList();

      return documents;
    });
  }

  @override
  Future<Either<Failure, void>> deleteDocument(String documentId) async {
    // Get document to get download URL for storage deletion
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _documentsCollection.doc(documentId).get();
      if (!doc.exists) {
        return const Left(StudentDocumentNotFoundFailure());
      }
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to fetch document: ${e.toString()}',
        ),
      );
    }

    return FirebaseErrorHandler.guard(() async {
      final dto = StudentDocumentDto.fromFirestore(doc);
      final document = StudentDocumentMapper.toEntity(dto);

      // Delete from Firestore
      await _documentsCollection.doc(documentId).delete();

      // Delete from Storage (best effort - don't fail if this fails)
      try {
        await storageService.deleteImage(document.downloadUrl);
      } catch (e) {
        // Log but don't fail
      }

      return;
    });
  }

  @override
  Future<Either<Failure, StudentDocument>> approveDocument({
    required String documentId,
    required String approvedBy,
  }) async {
    try {
      final doc = await _documentsCollection.doc(documentId).get();
      if (!doc.exists) {
        return const Left(StudentDocumentNotFoundFailure());
      }

      final dto = StudentDocumentDto.fromFirestore(doc);
      final document = StudentDocumentMapper.toEntity(dto);

      final updatedDocument = document.copyWith(
        approvalStatus: DocumentApprovalStatus.approved,
        approvedAt: DateTime.now(),
        approvedBy: approvedBy,
      );

      final updatedDto = StudentDocumentMapper.toDto(updatedDocument);
      await _documentsCollection
          .doc(documentId)
          .update(updatedDto.toFirestore());

      return Right(updatedDocument);
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to approve document: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudentDocument>> rejectDocument({
    required String documentId,
    required String rejectedBy,
  }) async {
    try {
      final doc = await _documentsCollection.doc(documentId).get();
      if (!doc.exists) {
        return const Left(StudentDocumentNotFoundFailure());
      }

      final dto = StudentDocumentDto.fromFirestore(doc);
      final document = StudentDocumentMapper.toEntity(dto);

      final updatedDocument = document.copyWith(
        approvalStatus: DocumentApprovalStatus.rejected,
        approvedAt: DateTime.now(),
        approvedBy: rejectedBy,
      );

      final updatedDto = StudentDocumentMapper.toDto(updatedDocument);
      await _documentsCollection
          .doc(documentId)
          .update(updatedDto.toFirestore());

      return Right(updatedDocument);
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to reject document: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> batchLinkDocumentsToUser({
    required String phoneNumber,
    required String userId,
  }) async {
    try {
      // Find all documents where studentId is the phone number
      final query = await _documentsCollection
          .where('studentId', isEqualTo: phoneNumber)
          .get();

      if (query.docs.isEmpty) {
        return const Right(null);
      }

      // Batch update all matching documents
      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'studentId': userId});
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to sync documents: ${e.toString()}',
        ),
      );
    }
  }

}

