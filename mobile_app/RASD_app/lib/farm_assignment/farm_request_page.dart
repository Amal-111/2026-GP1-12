import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';

/// The farmer chooses a farm and sends a request to its owner.
/// Pops with `true` when the request was sent.
class FarmRequestPage extends StatefulWidget {
  const FarmRequestPage({super.key});

  @override
  State<FarmRequestPage> createState() => _FarmRequestPageState();
}

class _FarmRequestPageState extends State<FarmRequestPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFarmId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RasdFarm> get _filteredFarms {
    final query = _searchController.text.trim().toLowerCase();

    return MockData.farms.where((farm) {
      return query.isEmpty || farm.name.toLowerCase().contains(query);
    }).toList();
  }

  void _sendRequest() {
    if (_selectedFarmId == null) {
      showCenterMessage(context, 'Please select a farm.', success: false);
      return;
    }

    AuthStore.sendRequest(_selectedFarmId!);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final farms = _filteredFarms;

    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Farm Assignment Request',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  GlassLabel(
                    child: Text(
                      'Choose the farm you work at. The farm owner will '
                      'receive your request and approve it.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search for a farm...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: farms.isEmpty
                  ? Center(
                      child: GlassBox(
                        child: Text(
                          'No farms found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: farms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final farm = farms[index];
                        final selected = _selectedFarmId == farm.id;

                        return GlassBox(
                          padding: EdgeInsets.zero,
                          tint: selected
                              ? const Color(0xFFDCEDE0)
                              : Colors.white,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  setState(() => _selectedFarmId = farm.id),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: farm.imagePath.isEmpty
                                            ? _imageFallback()
                                            : Image.asset(
                                                farm.imagePath,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _imageFallback(),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            farm.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${farm.palmCount} Palms · '
                                            '${farm.farmerCount} '
                                            '${farm.farmerCount == 1 ? 'Farmer' : 'Farmers'}',
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
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendRequest,
                  child: const Text('Send Request'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.beige,
      alignment: Alignment.center,
      child: const PalmIcon(size: 34, color: AppColors.primary),
    );
  }
}
