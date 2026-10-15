import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'palm_details.dart';

class PalmListPage extends StatefulWidget {
  const PalmListPage({super.key});

  @override
  State<PalmListPage> createState() => _PalmListPageState();
}

class _PalmListPageState extends State<PalmListPage> {
  final TextEditingController _searchController =
  TextEditingController();

  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _palms = [
    {
      'id': '0001',
      'status': 'Healthy',
      'updated': '5 min ago',
    },
    {
      'id': '0024',
      'status': 'Suspected',
      'updated': '10 min ago',
    },
    {
      'id': '0031',
      'status': 'Monitoring',
      'updated': '1 hour ago',
    },
    {
      'id': '0042',
      'status': 'Healthy',
      'updated': '3 hours ago',
    },
    {
      'id': '0055',
      'status': 'Healthy',
      'updated': '30 min ago',
    },
  ];

  final List<String> _filters = [
    'All',
    'Healthy',
    'Suspected',
    'Monitoring',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        return Icons.park_rounded;
    }
  }

  List<Map<String, dynamic>> get _filteredPalms {
    final query = _searchController.text.trim().toLowerCase();

    return _palms.where((palm) {
      final matchesSearch =
          'Palm #${palm['id']}'.toLowerCase().contains(query) ||
              palm['id'].toString().contains(query);

      final matchesStatus = _selectedFilter == 'All' ||
          palm['status'] == _selectedFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Palms'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Palm List',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredPalms.length} palms found',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by Palm ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final selected =
                            _selectedFilter == filter;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
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
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Palm list
            Expanded(
              child: _filteredPalms.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 52,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No palms found',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try another search or status.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    20, 0, 20, 20),
                itemCount: _filteredPalms.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final palm = _filteredPalms[index];
                  final status = palm['status'] as String;
                  final color = _statusColor(status);

                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius:
                      BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PalmDetailsPage(
                              palmId: palm['id'].toString(),
                              status: status,
                              updated: palm['updated'].toString(),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 58,
                              decoration: BoxDecoration(
                                color: color.withValues(
                                    alpha: 0.12),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: Icon(
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
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Last updated: ${palm['updated']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 26,
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
        ),
      ),
    );
  }
}
