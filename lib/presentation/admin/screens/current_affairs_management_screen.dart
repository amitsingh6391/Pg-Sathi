import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/app_ui_constants.dart';
import '../../../domain/entities/current_affair.dart';
import '../cubit/current_affairs_management_cubit.dart';
import 'admin_article_detail_screen.dart';

/// Admin screen for creating and managing current affairs articles.
class CurrentAffairsManagementScreen extends StatefulWidget {
  const CurrentAffairsManagementScreen({super.key, required this.adminId});

  final String adminId;

  @override
  State<CurrentAffairsManagementScreen> createState() =>
      _CurrentAffairsManagementScreenState();
}

class _CurrentAffairsManagementScreenState
    extends State<CurrentAffairsManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CurrentAffairsManagementCubit>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Current Affairs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI Generate button
          BlocBuilder<CurrentAffairsManagementCubit,
              CurrentAffairsManagementState>(
            builder: (context, state) {
              return FloatingActionButton.extended(
                heroTag: 'ai_generate',
                backgroundColor: const Color(0xFF8B5CF6),
                onPressed: state.isBusy
                    ? null
                    : () => _showAiGenerateDialog(context),
                icon: state.isAiGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  state.isAiGenerating ? 'Generating...' : 'AI Generate',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Manual create button
          FloatingActionButton(
            heroTag: 'manual_create',
            backgroundColor: AppUIConstants.accent,
            onPressed: () => _showCreateSheet(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: BlocBuilder<CurrentAffairsManagementCubit,
          CurrentAffairsManagementState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper_rounded, size: 56,
                      color: AppUIConstants.textTertiary),
                  const SizedBox(height: 12),
                  Text('No articles yet', style: AppUIConstants.headingSm),
                  const SizedBox(height: 4),
                  Text('Tap + to create one', style: AppUIConstants.bodyMd),
                ],
              ),
            );
          }

          final totalCount =
              state.items.length + (state.hasMore ? 1 : 0);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == state.items.length && state.hasMore) {
                return _buildLoadMoreButton(state);
              }
              final item = state.items[index];
              return _ArticleTile(
                item: item,
                onTap: () => _openDetail(context, item),
                onDelete: () => _confirmDelete(context, item.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<CurrentAffairsManagementCubit>(),
        child: _CreateArticleSheet(adminId: widget.adminId),
      ),
    );
  }

  void _showAiGenerateDialog(BuildContext context) {
    int articleCount = 3;
    String selectedCategory = 'all';

    final categoryOptions = <String, String>{
      'all': 'All Categories',
      'national': 'National',
      'international': 'International',
      'economy': 'Economy',
      'science': 'Science & Tech',
      'environment': 'Environment',
      'polity': 'Polity & Governance',
      'sports': 'Sports',
      'defense': 'Defense',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Expanded(child: Text('AI Generate News')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI will generate today\'s latest exam-relevant news and notify all students.',
                  style: AppUIConstants.bodySm,
                ),
                const SizedBox(height: 20),

                // --- Article count ---
                Text('Number of articles', style: AppUIConstants.labelMd),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: articleCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        activeColor: const Color(0xFF8B5CF6),
                        label: '$articleCount',
                        onChanged: (v) =>
                            setDialogState(() => articleCount = v.round()),
                      ),
                    ),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$articleCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Category ---
                Text('News category', style: AppUIConstants.labelMd),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categoryOptions.entries.map((entry) {
                    final isSelected = selectedCategory == entry.key;
                    return ChoiceChip(
                      label: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF8B5CF6),
                      backgroundColor: AppUIConstants.surface,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : AppUIConstants.border,
                      ),
                      onSelected: (_) =>
                          setDialogState(() => selectedCategory = entry.key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _triggerAiGeneration(
                  context,
                  articleCount,
                  selectedCategory,
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text('Generate $articleCount'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerAiGeneration(
    BuildContext context,
    int count,
    String category,
  ) async {
    final cubit = context.read<CurrentAffairsManagementCubit>();
    final success = await cubit.generateWithAi(
      count: count,
      category: category,
    );

    if (!context.mounted) return;

    final state = cubit.state;
    final errorMsg = state.failure?.message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Generated $count articles successfully!'
              : errorMsg ?? 'AI generation failed. Please try again.',
        ),
        backgroundColor: success ? AppUIConstants.success : AppUIConstants.error,
        duration: Duration(seconds: success ? 3 : 5),
      ),
    );
  }

  void _openDetail(BuildContext context, CurrentAffair item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminArticleDetailScreen(
          item: item,
          onDelete: () =>
              context.read<CurrentAffairsManagementCubit>().delete(item.id),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(CurrentAffairsManagementState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: state.isLoadingMore
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : TextButton.icon(
                onPressed: () =>
                    context.read<CurrentAffairsManagementCubit>().loadMore(),
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: const Text('Load More'),
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.primary,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CurrentAffairsManagementCubit>().delete(id);
            },
            child: Text('Delete', style: TextStyle(color: AppUIConstants.error)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Article Tile
// =============================================================================

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final CurrentAffair item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppUIConstants.accent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.categoryLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppUIConstants.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.publishedAt != null)
                            Text(
                              DateFormat('dd MMM yy')
                                  .format(item.publishedAt!),
                              style: AppUIConstants.caption,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: AppUIConstants.bodyLg,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.summary,
                        style: AppUIConstants.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: AppUIConstants.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.viewCount}',
                            style: AppUIConstants.caption,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                            color: AppUIConstants.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.likeCount}',
                            style: AppUIConstants.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppUIConstants.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Create Article Sheet
// =============================================================================

class _CreateArticleSheet extends StatefulWidget {
  const _CreateArticleSheet({required this.adminId});
  final String adminId;

  @override
  State<_CreateArticleSheet> createState() => _CreateArticleSheetState();
}

class _CreateArticleSheetState extends State<_CreateArticleSheet> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _sourceController = TextEditingController();
  CurrentAffairsCategory _category = CurrentAffairsCategory.national;
  bool _sendNotification = true;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty ||
        _summaryController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final success =
        await context.read<CurrentAffairsManagementCubit>().create(
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      content: _contentController.text.trim(),
      category: _category,
      source: _sourceController.text.trim().isEmpty
          ? null
          : _sourceController.text.trim(),
      createdBy: widget.adminId,
      sendNotification: _sendNotification,
    );

    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppUIConstants.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('New Article', style: AppUIConstants.headingMd),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField('Title *', _titleController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildField('Summary *', _summaryController, maxLines: 3),
                  const SizedBox(height: 12),
                  _buildField('Full Content *', _contentController,
                      maxLines: 8),
                  const SizedBox(height: 12),
                  _buildField('Source (optional)', _sourceController),
                  const SizedBox(height: 16),

                  // Category dropdown
                  Text('Category', style: AppUIConstants.labelMd),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<CurrentAffairsCategory>(
                    initialValue: _category,
                    onChanged: (v) => setState(() => _category = v!),
                    items: CurrentAffairsCategory.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ))
                        .toList(),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notification toggle
                  SwitchListTile(
                    title: const Text('Send push notification to all students'),
                    subtitle: const Text('Students will be notified immediately'),
                    value: _sendNotification,
                    onChanged: (v) => setState(() => _sendNotification = v),
                    activeThumbColor: AppUIConstants.accent,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 20),

                  BlocBuilder<CurrentAffairsManagementCubit,
                      CurrentAffairsManagementState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state.isCreating ? null : _create,
                        style: AppUIConstants.primaryButtonStyle.copyWith(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        child: state.isCreating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Publish Article'),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.labelMd),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppUIConstants.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppUIConstants.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10,
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
