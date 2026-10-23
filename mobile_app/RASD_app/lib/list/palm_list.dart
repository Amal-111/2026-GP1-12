
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import '../manage_palms/add_palm_page.dart';
import 'palm_details.dart';

class PalmListPage extends StatefulWidget {
  final String farmId;
  final String? initialStatus;

  const PalmListPage({
    super.key,
    required this.farmId,
    this.initialStatus,
  });

  @override
  State<PalmListPage> createState() => _PalmListPageState();
}

class _PalmListPageState extends State<PalmListPage> {
  final _searchController = TextEditingController();

  late String _selectedFilter;

  final _filters = const [
    'All',
    'Healthy',
    'Suspected',
    'Monitoring',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = _normalizeStatus(
      widget.initialStatus ?? 'All',
    );
  }

  @override
  void didUpdateWidget(covariant PalmListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.farmId != widget.farmId) {
      _selectedFilter = _normalizeStatus(
        widget.initialStatus ?? 'All',
      );
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeStatus(Object? value) {
    final raw = (value ?? '').toString()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .toLowerCase();

    switch (raw) {
      case 'healthy':
        return 'Healthy';
      case 'suspected':
        return 'Suspected';
      case 'monitoring':
      case 'undermonitoring':
        return 'Monitoring';
      default:
        return 'All';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Monitoring':
        return AppColors.monitoring;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Healthy':
        return Icons.park_rounded;
      case 'Suspected':
        return Icons.warning_rounded;
      case 'Monitoring':
        return Icons.access_time_rounded;
      default:
        return Icons.info_outline;
    }
  }

  List<Map<String, dynamic>> _parsePalms(Object? value) {
    if (value is! Map) return [];

    final result = <Map<String, dynamic>>[];

    for (final entry in value.entries) {
      if (entry.value is! Map) continue;

      final data = Map<String, dynamic>.from(entry.value as Map);

      result.add({
        ...data,
        'id': entry.key.toString(),
        'status': _normalizeStatus(data['healthStatus']),
      });
    }

    result.sort(
          (a, b) => a['id'].toString().compareTo(
        b['id'].toString(),
      ),
    );

    return result;
  }

  String _lastUpdated(Map<String, dynamic> palm) {
    final raw = palm['updatedAt'] ??
        palm['lastSeen'] ??
        palm['createdAt'];

    if (raw == null) return 'Not available';

    DateTime? date;

    if (raw is num) {
      final number = raw.toInt();
      date = DateTime.fromMillisecondsSinceEpoch(
        number < 100000000000
            ? number * 1000
            : number,
      );
    } else {
      date = DateTime.tryParse(raw.toString());
    }

    if (date == null) return 'Not available';

    final local = date.toLocal();

    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addPalm() async {
    try {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddPalmPage(),
        ),
      );

      // No manual refresh is needed.
      // Firebase onValue updates the list automatically.
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add palm: $error')),
      );
    }
  }

  void _openDetails(Map<String, dynamic> palm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PalmDetailsPage(
          farmId: widget.farmId,
          palmId: palm['id'].toString(),
          status: palm['status'].toString(),
          updated: _lastUpdated(palm),
          deviceId: (palm['deviceId'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Palms'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPalm,
        icon: const Icon(Icons.add),
        label: const Text('Add Palm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          key: ValueKey(widget.farmId),
          stream: FirebaseDatabase.instance
              .ref('palms/${widget.farmId}')
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load palms:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allPalms = _parsePalms(
              snapshot.data!.snapshot.value,
            );

            final query = _searchController.text
                .trim()
                .toLowerCase();

            final filtered = allPalms.where((palm) {
              final palmId = palm['id'].toString().toLowerCase();

              final matchesSearch = palmId.contains(query);

              final matchesStatus =
                  _selectedFilter == 'All' ||
                      palm['status'] == _selectedFilter;

              return matchesSearch && matchesStatus;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20, 12, 20, 16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Palm List',
                        style: Theme.of(context)
                            .textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${filtered.length} palms found '
                            '(${allPalms.length} total)',
                        style: Theme.of(context)
                            .textTheme.bodyMedium
                            ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by Palm ID...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final selected =
                                _selectedFilter == filter;

                            return Padding(
                              padding: const EdgeInsets.only(
                                right: 8,
                              ),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
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
                  child: filtered.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 52,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          allPalms.isEmpty
                              ? 'No palms added yet'
                              : 'No palms found',
                          style: Theme.of(context)
                              .textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allPalms.isEmpty
                              ? 'Tap Add Palm to register your first palm.'
                              : 'Try another search or status.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      20, 0, 20, 90,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final palm = filtered[index];
                      final status =
                      palm['status'].toString();
                      final color = _statusColor(status);

                      return Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius:
                          BorderRadius.circular(16),
                          onTap: () => _openDetails(palm),
                          child: Padding(
                            padding:
                            const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: appIcon(
                                        _statusIcon(status),
                                    color: color,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Palm #${palm['id']}',
                                        style: Theme.of(context)
                                            .textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Last updated: '
                                            '${_lastUpdated(palm)}',
                                        style: Theme.of(context)
                                            .textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
