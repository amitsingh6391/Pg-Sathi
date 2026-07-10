import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_candidates_cubit.dart';
import '../../cubit/jobs/admin_jobs_cubit.dart';
import '../../widgets/jobs/admin_jobs_inbox_tab.dart';
import '../../widgets/jobs/admin_jobs_published_tab.dart';

/// Admin "Jobs & Alerts" hub. Two tabs:
///
/// - **Inbox**: candidates fetched by the scraper, awaiting review.
///   Surfaces extracted vacancies / fees / dates as preview chips so
///   the admin can decide-then-publish without opening the form.
/// - **Published**: live jobs visible to students, with engagement
///   counters and shortcuts to analytics / edit / delete.
///
/// Both tabs share the same DI-provided cubits, declared here so
/// switching tabs is instant and selection state survives swipes.
class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key, required this.adminId});

  final String adminId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AdminJobsCubit>()..load()),
        BlocProvider(create: (_) => sl<AdminJobCandidatesCubit>()..load()),
      ],
      child: _AdminJobsView(adminId: adminId),
    );
  }
}

class _AdminJobsView extends StatelessWidget {
  const _AdminJobsView({required this.adminId});
  final String adminId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Jobs & Alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(icon: Icon(Icons.inbox_rounded, size: 18), text: 'Inbox'),
              Tab(
                icon: Icon(Icons.check_circle_rounded, size: 18),
                text: 'Published',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AdminJobsInboxTab(adminId: adminId),
            AdminJobsPublishedTab(adminId: adminId),
          ],
        ),
      ),
    );
  }
}
