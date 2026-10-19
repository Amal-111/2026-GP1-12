import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

class AssignFarmerPage extends StatefulWidget {
  const AssignFarmerPage({super.key});

  @override
  State<AssignFarmerPage> createState() => _AssignFarmerPageState();
}

class _AssignFarmerPageState extends State<AssignFarmerPage> {
  final TextEditingController _searchController = TextEditingController();

  FarmerData? _selectedFarmer;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FarmerData> get _filteredFarmers {
    final query = _searchController.text.trim().toLowerCase();

    return MockData.farmers.where((farmer) {
      return query.isEmpty ||
          farmer.name.toLowerCase().contains(query) ||
          farmer.email.toLowerCase().contains(query);
    }).toList();
  }

  void _assignFarmer() {
    if (_selectedFarmer == null) {
      showCenterMessage(
        context,
        'Please select a farmer.',
        success: false,
      );
      return;
    }

    MockData.assignFarmerToFarm(
      _selectedFarmer!,
      MockData.selectedFarmId,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Assign Farmer',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search for a farmer...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),

            Expanded(
              child: ListenableBuilder(
                listenable: MockData.changes,
                builder: (context, _) {
                  final farmers = _filteredFarmers;

                  if (farmers.isEmpty) {
                    return Center(
                      child: GlassBox(
                        child: Text(
                          'No farmers found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: farmers.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final farmer = farmers[index];
                      final isSelected = _selectedFarmer == farmer;

                      return GlassBox(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (_) {
                                setState(() {
                                  _selectedFarmer =
                                  isSelected ? null : farmer;
                                });
                              },
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmer.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    farmer.email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color:
                                      AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _assignFarmer,
                  child: const Text('Assign'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}