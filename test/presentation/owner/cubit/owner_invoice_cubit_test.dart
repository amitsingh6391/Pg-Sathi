import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/services/invoice_pdf_service.dart';
import 'package:pg_manager/domain/entities/invoice.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/usecases/delete_invoice.dart';
import 'package:pg_manager/domain/usecases/get_invoices_for_owner.dart';
import 'package:pg_manager/presentation/owner/cubit/owner_invoice_cubit.dart';
import 'package:pg_manager/presentation/owner/cubit/owner_invoice_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetInvoicesForOwner extends Mock implements GetInvoicesForOwner {}

class MockInvoicePdfService extends Mock implements InvoicePdfService {}

class MockDeleteInvoice extends Mock implements DeleteInvoice {}

void main() {
  late OwnerInvoiceCubit cubit;
  late MockGetInvoicesForOwner mockGetInvoicesForOwner;
  late MockInvoicePdfService mockPdfService;
  late MockDeleteInvoice mockDeleteInvoice;

  final testInvoices = [
    Invoice(
      id: '1',
      invoiceNumber: 'INV-001',
      libraryId: 'lib1',
      libraryName: 'Test Library',
      libraryAddress: '123 Test St',
      ownerId: 'owner1',
      ownerName: 'Owner',
      ownerContact: '+919999999999',
      studentId: 'student1',
      studentName: 'John Doe',
      studentPhone: '+911111111111',
      membershipId: 'mem1',
      seatNumber: 'S01',
      slot: Slot.morning,
      sessionTiming: '6AM-12PM',
      billingMonth: '2024-01',
      amountPaid: 1000,
      currency: 'INR',
      paymentId: 'pay1',
      paymentDate: DateTime(2024, 1, 15),
      generatedAt: DateTime(2024, 1, 15),
      expiryDate: DateTime(2024, 2, 15),
    ),
    Invoice(
      id: '2',
      invoiceNumber: 'INV-002',
      libraryId: 'lib1',
      libraryName: 'Test Library',
      libraryAddress: '123 Test St',
      ownerId: 'owner1',
      ownerName: 'Owner',
      ownerContact: '+919999999999',
      studentId: 'student2',
      studentName: 'Jane Smith',
      studentPhone: '+912222222222',
      membershipId: 'mem2',
      seatNumber: 'S02',
      slot: Slot.evening,
      sessionTiming: '12PM-6PM',
      billingMonth: '2024-02',
      amountPaid: 1500,
      currency: 'INR',
      paymentId: 'pay2',
      paymentDate: DateTime(2024, 2, 10),
      generatedAt: DateTime(2024, 2, 10),
      expiryDate: DateTime(2024, 3, 10),
    ),
    Invoice(
      id: '3',
      invoiceNumber: 'INV-003',
      libraryId: 'lib1',
      libraryName: 'Test Library',
      libraryAddress: '123 Test St',
      ownerId: 'owner1',
      ownerName: 'Owner',
      ownerContact: '+919999999999',
      studentId: 'student1',
      studentName: 'John Doe',
      studentPhone: '+911111111111',
      membershipId: 'mem1',
      seatNumber: 'S01',
      slot: Slot.morning,
      sessionTiming: '6AM-12PM',
      billingMonth: '2024-02',
      amountPaid: 1000,
      currency: 'INR',
      paymentId: 'pay3',
      paymentDate: DateTime(2024, 2, 15),
      generatedAt: DateTime(2024, 2, 15),
      expiryDate: DateTime(2024, 3, 15),
    ),
  ];

  setUp(() {
    mockGetInvoicesForOwner = MockGetInvoicesForOwner();
    mockPdfService = MockInvoicePdfService();
    mockDeleteInvoice = MockDeleteInvoice();
    cubit = OwnerInvoiceCubit(
      getInvoicesForOwner: mockGetInvoicesForOwner,
      pdfService: mockPdfService,
      deleteInvoice: mockDeleteInvoice,
    );

    registerFallbackValue(const GetInvoicesForOwnerParams(ownerId: ''));
  });

  tearDown(() {
    cubit.close();
  });

  group('OwnerInvoiceCubit', () {
    group('loadInvoices', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_emit_loaded_state_with_invoices_when_successful',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) => cubit.loadInvoices('owner1'),
        expect: () => [
          isA<OwnerInvoiceState>().having(
            (s) => s.status,
            'status',
            OwnerInvoiceStatus.loading,
          ),
          isA<OwnerInvoiceState>()
              .having((s) => s.status, 'status', OwnerInvoiceStatus.loaded)
              .having((s) => s.allInvoices.length, 'invoice count', 3)
              .having((s) => s.students.length, 'student count', 2)
              .having((s) => s.availableMonths.length, 'month count', 2),
        ],
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_extract_unique_students_sorted_alphabetically',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) => cubit.loadInvoices('owner1'),
        verify: (cubit) {
          expect(cubit.state.students.length, 2);
          expect(cubit.state.students[0].name, 'Jane Smith');
          expect(cubit.state.students[1].name, 'John Doe');
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_extract_months_sorted_newest_first',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) => cubit.loadInvoices('owner1'),
        verify: (cubit) {
          expect(cubit.state.availableMonths.length, 2);
          expect(cubit.state.availableMonths[0], '2024-02');
          expect(cubit.state.availableMonths[1], '2024-01');
        },
      );
    });

    group('search filtering', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_student_name_case_insensitive',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('john');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 2);
          expect(
            cubit.state.filteredInvoices.every(
              (i) => i.studentName.toLowerCase().contains('john'),
            ),
            true,
          );
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_phone_number_partial_match',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('222222');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
          expect(cubit.state.filteredInvoices.first.studentName, 'Jane Smith');
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_return_empty_when_no_match_found',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('nonexistent');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.isEmpty, true);
        },
      );
    });

    group('invoice ID search', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_invoice_number',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.searchInvoiceId('INV-002');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
          expect(cubit.state.filteredInvoices.first.invoiceNumber, 'INV-002');
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_invoice_id_partial_match',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.searchInvoiceId('002');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
        },
      );
    });

    group('date range filtering', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_date_range_inclusive',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByDateRange(DateTime(2024, 2, 1), DateTime(2024, 2, 28));
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 2);
          expect(
            cubit.state.filteredInvoices.every((i) => i.paymentDate.month == 2),
            true,
          );
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_include_start_date_boundary',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByDateRange(DateTime(2024, 2, 10), DateTime(2024, 2, 28));
        },
        verify: (cubit) {
          // Should include invoice with paymentDate = 2024-02-10
          expect(cubit.state.filteredInvoices.length, 2);
        },
      );
    });

    group('month filtering', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_filter_by_billing_month',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByMonth('2024-01');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
          expect(cubit.state.filteredInvoices.first.billingMonth, '2024-01');
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_clear_month_filter_when_null',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByMonth('2024-01');
          cubit.filterByMonth(null);
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 3);
          expect(cubit.state.selectedMonth, null);
        },
      );
    });

    group('payment status filtering', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_show_all_invoices_for_paid_filter',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByPaymentStatus(InvoicePaymentFilter.paid);
        },
        verify: (cubit) {
          // All invoices are paid in this system
          expect(cubit.state.filteredInvoices.length, 3);
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_show_no_invoices_for_pending_filter',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.filterByPaymentStatus(InvoicePaymentFilter.pending);
        },
        verify: (cubit) {
          // No pending invoices in this system
          expect(cubit.state.filteredInvoices.isEmpty, true);
        },
      );
    });

    group('combined filtering', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_apply_multiple_filters_together',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('john');
          cubit.filterByMonth('2024-02');
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
          expect(cubit.state.filteredInvoices.first.studentName, 'John Doe');
          expect(cubit.state.filteredInvoices.first.billingMonth, '2024-02');
        },
      );

      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_apply_search_and_date_range_together',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('john');
          cubit.filterByDateRange(DateTime(2024, 1, 1), DateTime(2024, 1, 31));
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 1);
          expect(cubit.state.filteredInvoices.first.paymentDate.month, 1);
        },
      );
    });

    group('clearFilters', () {
      blocTest<OwnerInvoiceCubit, OwnerInvoiceState>(
        'should_reset_all_filters_and_show_all_invoices',
        build: () {
          when(
            () => mockGetInvoicesForOwner(any()),
          ).thenAnswer((_) async => Right(testInvoices));
          return cubit;
        },
        act: (cubit) async {
          await cubit.loadInvoices('owner1');
          cubit.search('john');
          cubit.filterByMonth('2024-02');
          cubit.clearFilters();
        },
        verify: (cubit) {
          expect(cubit.state.filteredInvoices.length, 3);
          expect(cubit.state.searchQuery, '');
          expect(cubit.state.selectedMonth, null);
          expect(cubit.state.hasFilters, false);
        },
      );
    });

    group('activeFilterCount', () {
      test('should_count_zero_when_no_filters_active', () async {
        when(
          () => mockGetInvoicesForOwner(any()),
        ).thenAnswer((_) async => Right(testInvoices));

        await cubit.loadInvoices('owner1');

        expect(cubit.state.activeFilterCount, 0);
      });

      test('should_count_each_active_filter', () async {
        when(
          () => mockGetInvoicesForOwner(any()),
        ).thenAnswer((_) async => Right(testInvoices));

        await cubit.loadInvoices('owner1');

        cubit.search('john');
        expect(cubit.state.activeFilterCount, 1);

        cubit.filterByMonth('2024-01');
        expect(cubit.state.activeFilterCount, 2);

        cubit.filterByDateRange(DateTime(2024, 1, 1), DateTime(2024, 12, 31));
        expect(cubit.state.activeFilterCount, 3);

        cubit.searchInvoiceId('INV');
        expect(cubit.state.activeFilterCount, 4);

        cubit.clearFilters();
        expect(cubit.state.activeFilterCount, 0);
      });
    });

    group('hasFilters', () {
      test('should_return_false_when_no_filters_applied', () async {
        when(
          () => mockGetInvoicesForOwner(any()),
        ).thenAnswer((_) async => Right(testInvoices));

        await cubit.loadInvoices('owner1');

        expect(cubit.state.hasFilters, false);
      });

      test('should_return_true_when_any_filter_applied', () async {
        when(
          () => mockGetInvoicesForOwner(any()),
        ).thenAnswer((_) async => Right(testInvoices));

        await cubit.loadInvoices('owner1');

        cubit.search('test');
        expect(cubit.state.hasFilters, true);

        cubit.clearFilters();
        expect(cubit.state.hasFilters, false);

        cubit.filterByMonth('2024-01');
        expect(cubit.state.hasFilters, true);
      });
    });

    group('formatMonth', () {
      test('should_format_month_correctly', () {
        expect(cubit.state.formatMonth('2024-01'), 'Jan 2024');
        expect(cubit.state.formatMonth('2024-12'), 'Dec 2024');
        expect(cubit.state.formatMonth('2023-06'), 'Jun 2023');
      });

      test('should_return_original_string_for_invalid_format', () {
        expect(cubit.state.formatMonth('invalid'), 'invalid');
        expect(cubit.state.formatMonth('2024'), '2024');
      });
    });
  });
}
