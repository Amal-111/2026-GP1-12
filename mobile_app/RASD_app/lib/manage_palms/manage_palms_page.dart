import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import 'palm_ui.dart';
import '../data/mock_data.dart';
import 'add_palm_page.dart';
import 'edit_palm_page.dart';
import '../theme/glass_widgets.dart';

/// Manage Palms: list of palms with Add, Edit and Delete.
class ManagePalmsPage extends StatefulWidget {
  const ManagePalmsPage({super.key});

  @override
  State<ManagePalmsPage> createState() => _ManagePalmsPageState();
}

class _ManagePalmsPageState extends State<ManagePalmsPage> {
  final PalmStore _store = PalmStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  static const _filters = ['All', 'Healthy', 'Suspected', 'Under Monitoring'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Palm> get _filteredPalms {
    final query = _searchController.text.trim().toLowerCase();
    return _store.palms.where((palm) {
      final matchesSearch = query.isEmpty ||
          palm.id.toLowerCase().contains(query) ||
          (palm.type ?? '').toLowerCase().contains(query);
      final matchesFilter = _filter == 'All' || palm.statusLabel == _filter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showMessage(String text) {
    showCenterMessage(context, text);
  }

  Future<void> _openAddPalm() async {
    // A farm owner who is not assigned to any farm cannot add palms.
    if (_store.activeFarmId == null || _store.activeFarmId!.isEmpty) {
      showCenterMessage(
        context,
        'You are not assigned to any farm yet.',
        success: false,
      );
      return;
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddPalmPage()),
    );
    if (added == true && mounted) {
      _showMessage('Palm tree added successfully.');
    }
  }

  Future<void> _openEditPalm(Palm palm) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditPalmPage(palm: palm)),
    );
    if (saved == true && mounted) {
      _showMessage('Palm tree information updated successfully.');
    }
  }

  Future<void> _confirmDelete(Palm palm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${palm.id}?'),
        content: const Text(
          'Are you sure you want to delete this palm tree? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _store.deletePalm(palm);
      if (mounted) _showMessage('Palm tree deleted successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(title: 'Manage Palms'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store.changes,
          builder: (context, _) {
            final palms = _filteredPalms;
            final total = _store.palms.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Palms',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.brown),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${MockData.selectedFarm.name} · $total palms',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by Palm ID or type...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status filters, like the palm list page.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final selected = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _filter = f),
                                backgroundColor: AppColors.surface,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: palms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded,
                                  size: 52, color: AppColors.textSecondary),
                              const SizedBox(height: 10),
                              Text('No palms found',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text('Try another search or add a palm.',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: palms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildPalmCard(palms[index]),
                        ),
                ),
                // Add Palm button at the bottom of the page.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openAddPalm,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Palm'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPalmCard(Palm palm) {
    final status = palm.statusLabel;
    final color = palmStatusColor(status);
    final details = [
      if (palm.type != null) palm.type!,
      if (palm.age != null) '${palm.age} yrs',
    ].join(' · ');

    return GlassBox(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          StatusTile(status: status),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(palm.id, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${palm.deviceId} · ${timeAgo(palm.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              RoundIconButton(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                tooltip: 'Edit',
                onPressed: () => _openEditPalm(palm),
              ),
              const SizedBox(height: 8),
              RoundIconButton(
                icon: Icons.delete_outline,
                color: AppColors.error,
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(palm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
