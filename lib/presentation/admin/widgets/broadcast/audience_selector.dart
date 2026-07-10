import 'package:flutter/material.dart';

import '../../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../../core/app_ui_constants.dart';

/// Audience selector widget with modern UI.
class AudienceSelector extends StatelessWidget {
  const AudienceSelector({
    super.key,
    required this.selectedAudience,
    required this.onAudienceChanged,
  });

  final BroadcastAudience selectedAudience;
  final ValueChanged<BroadcastAudience> onAudienceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Audience',
          style: AppUIConstants.headingSm.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose who will receive this notification',
          style: AppUIConstants.caption.copyWith(
            color: AppUIConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _buildAudienceGrid(context),
      ],
    );
  }

  Widget _buildAudienceGrid(BuildContext context) {
    return Column(
      children: [
        // Owners Section
        _SectionHeader(
          icon: Icons.business_rounded,
          title: 'Library Owners',
          color: AppUIConstants.primary,
        ),
        const SizedBox(height: 8),
        _AudienceCard(
          title: 'All Owners',
          description: 'Every registered owner',
          icon: Icons.people_rounded,
          color: AppUIConstants.primary,
          isSelected: selectedAudience == BroadcastAudience.allOwners,
          onTap: () => onAudienceChanged(BroadcastAudience.allOwners),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AudienceCard(
                title: 'Active',
                description: 'With library setup',
                icon: Icons.check_circle_rounded,
                color: AppUIConstants.success,
                isSelected: selectedAudience == BroadcastAudience.ownersWithLibrary,
                onTap: () => onAudienceChanged(BroadcastAudience.ownersWithLibrary),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AudienceCard(
                title: 'Pending',
                description: 'No library yet',
                icon: Icons.pending_rounded,
                color: AppUIConstants.warning,
                isSelected: selectedAudience == BroadcastAudience.ownersWithoutLibrary,
                onTap: () => onAudienceChanged(BroadcastAudience.ownersWithoutLibrary),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Students Section
        _SectionHeader(
          icon: Icons.school_rounded,
          title: 'Students',
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        _AudienceCard(
          title: 'All Students',
          description: 'Every registered student',
          icon: Icons.groups_rounded,
          color: Colors.blue,
          isSelected: selectedAudience == BroadcastAudience.allStudents,
          onTap: () => onAudienceChanged(BroadcastAudience.allStudents),
        ),
        const SizedBox(height: 8),
        _AudienceCard(
          title: 'Active Members',
          description: 'Students with active membership',
          icon: Icons.card_membership_rounded,
          color: Colors.green,
          isSelected: selectedAudience == BroadcastAudience.studentsWithActiveMembership,
          onTap: () => onAudienceChanged(BroadcastAudience.studentsWithActiveMembership),
        ),
        const SizedBox(height: 8),
        _AudienceCard(
          title: 'Recently Active (30 days)',
          description: 'Attended recently - saves Cloud Function time',
          icon: Icons.trending_up_rounded,
          color: Colors.purple,
          isSelected: selectedAudience == BroadcastAudience.activeStudents,
          onTap: () => onAudienceChanged(BroadcastAudience.activeStudents),
        ),
        const SizedBox(height: 20),

        // Custom Selection Section
        _SectionHeader(
          icon: Icons.tune_rounded,
          title: 'Custom Selection',
          color: Colors.orange,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AudienceCard(
                title: 'Library Owners',
                description: 'Select libraries',
                icon: Icons.checklist_rounded,
                color: Colors.orange,
                isSelected: selectedAudience == BroadcastAudience.selectedLibraries,
                onTap: () => onAudienceChanged(BroadcastAudience.selectedLibraries),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AudienceCard(
                title: 'Library Students',
                description: 'Select libraries',
                icon: Icons.filter_list_rounded,
                color: Colors.teal,
                isSelected: selectedAudience == BroadcastAudience.selectedLibraryStudents,
                onTap: () => onAudienceChanged(BroadcastAudience.selectedLibraryStudents),
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppUIConstants.bodyMd.copyWith(
            fontWeight: FontWeight.w600,
            color: AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            color: isSelected ? null : AppUIConstants.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.5) : AppUIConstants.border.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: compact ? 18 : 22,
                  color: color,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (compact ? AppUIConstants.bodySm : AppUIConstants.bodyMd).copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppUIConstants.textPrimary,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      description,
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textSecondary,
                        fontSize: compact ? 10 : 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: compact ? 14 : 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
