import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../theme/glass_widgets.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import 'palm_details.dart';

class PalmListPage extends StatefulWidget {
  final PalmStatus? initialStatus;
  final String? farmId;
  const PalmListPage({super.key, this.initialStatus, this.farmId});

  @override
  State<PalmListPage> createState() => _PalmListPageState();
}

class _PalmListPageState extends State<PalmListPage> {
  final TextEditingController _searchController = TextEditingController();
  PalmStatus? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatus;
    MockData.changes.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    MockData.changes.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  String get _farmId => MockData.currentUser.role == UserRole.farmer
      ? (MockData.currentUser.farmId ?? '')
      : (widget.farmId ?? MockData.selectedFarmId);

  List<PalmData> get _filteredPalms {
    final query = _searchController.text.trim().toLowerCase();
    return MockData.palmsForFarm(_farmId).where((palm) {
      final matchesSearch = palm.id.toLowerCase().contains(query) ||
          palm.id.toLowerCase().contains(query);
      return matchesSearch && (_filter == null || palm.status == _filter);
    }).toList();
  }

  Color _color(PalmStatus status) {
    if (status == PalmStatus.healthy) return AppColors.healthy;
    if (status == PalmStatus.suspected) return AppColors.suspected;
    return AppColors.monitoring;
  }

  @override
  Widget build(BuildContext context) {
    final palms = _filteredPalms;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Palms')),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassLabel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Palm List', style: Theme.of(context).textTheme.headlineMedium),
                Text('${palms.length} palms found',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  hintText: 'Search by Palm ID...', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
              children: [null, PalmStatus.healthy, PalmStatus.suspected,
                PalmStatus.underMonitoring].map((status) {
                final selected = _filter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status == null ? 'All' : palmStatusLabel(status)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = status),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                  ),
                );
              }).toList(),
            )),
          ]),
        ),
        Expanded(child: palms.isEmpty
            ? const Center(child: GlassLabel(child: Text('No palms found')))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: palms.length,
          itemBuilder: (context, index) {
            final palm = palms[index];
            final color = _color(palm.status);
            return GlassCard(child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: PalmIcon(size: 38, color: color),
              title: Text(palm.id),
              subtitle: Text('${palmStatusLabel(palm.status)}\n'
                  'Last updated: ${timeAgo(palm.updatedAt)}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PalmDetailsPage(palmId: palm.id)));
                if (mounted) setState(() {});
              },
            ));
          },
        )),
      ])),
    );
  }
}
