// Lists the palms of a farm with search, edit and delete.
import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import '../services/rasd_management_service.dart';
import 'add_palm_page.dart';
import 'edit_palm_page.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';
/// Manage Palms: list of palms with Add, Edit and Delete.
class ManagePalmsPage extends StatefulWidget {
  const ManagePalmsPage({super.key});

  @override
  State<ManagePalmsPage> createState() => _ManagePalmsPageState();
}

class _ManagePalmsPageState extends State<ManagePalmsPage> {
  final PalmStore _store = PalmStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filters palms by the search text.
  List<Palm> _filteredPalms(List<Palm> allPalms) {
    final query = _searchController.text.trim().toLowerCase();
    return allPalms.where((palm) {
      return query.isEmpty ||
          palm.id.toLowerCase().contains(query) ||
          (palm.type ?? '').toLowerCase().contains(query);
    }).toList();
  }

  /// Shows a short centred message.
  void _showMessage(String text) {
    showCenterMessage(context, text);
  }

  /// Opens the Add Palm page.
  Future<void> _openAddPalm() async {
    // A farm owner who is not assigned to any farm cannot add palms.
    if (_store.activeFarmId == null || _store.activeFarmId!.isEmpty) {
      showCenterMessage(
        context,
        AuthStore.arabic.value
            ? 'اطلبي من مالك المزرعة دعوتك إلى مزرعة قبل إضافة النخيل.'
            : 'Ask the farm owner to invite you to a farm before adding palms.',
        success: false,
        title: AuthStore.arabic.value ? 'لا توجد مزرعة مرتبطة' : 'No farm assigned',
      );
      return;
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddPalmPage()),
    );
    if (added == true && mounted) {
      _showMessage(
        AuthStore.arabic.value
            ? 'تمت إضافة النخلة بنجاح.'
            : 'Palm tree added successfully.',
      );
    }
  }

  /// Opens the Edit Palm page.
  Future<void> _openEditPalm(Palm palm) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditPalmPage(palm: palm)),
    );
    if (saved == true && mounted) {
      _showMessage(
        AuthStore.arabic.value
            ? 'تم تحديث معلومات النخلة بنجاح.'
            : 'Palm tree information updated successfully.',
      );
    }
  }

  /// Asks for confirmation before removing the item.
  Future<void> _confirmDelete(Palm palm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AuthStore.arabic.value
              ? 'حذف ${palm.id}؟'
              : 'Delete ${palm.id}?',
        ),
        content: Text(
          AuthStore.arabic.value
              ? 'هل أنت متأكدة من حذف هذه النخلة؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'Are you sure you want to delete this palm tree? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AuthStore.arabic.value ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AuthStore.arabic.value ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RasdManagementService.deletePalm(palm);
if (mounted) {
_showMessage(
AuthStore.arabic.value
? 'تم حذف النخلة بنجاح.'
: 'Palm tree deleted successfully.',
);
}
} catch (error) {
        if (mounted) {
showRasdError(
context,
error,
title: AuthStore.arabic.value
? 'تعذر حذف النخلة'
: 'Could not delete the palm',
);
        }
      }
    }
  }

  /// Maps a palm status to its colour.
  Color _statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Under Monitoring':
        return AppColors.monitoring;
      case 'Treated':
        return AppColors.treated;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Maps a palm status to its icon.
  IconData _statusIcon(String status) {
    switch (status) {
      case 'Suspected':
        return Icons.warning_rounded;
      case 'Under Monitoring':
        return Icons.access_time_rounded;
      case 'Treated':
        return Icons.medical_services_rounded;
      default:
        return Icons.park_rounded;
    }
  }

String _translateStatus(String status) {
switch (status) {
case 'Healthy':
return 'سليمة';
case 'Suspected':
return 'مشتبه بالإصابة';
case 'Under Monitoring':
return 'تحت المراقبة';
case 'Treated':
return 'تم علاجها';
default:
return status;
}
}
@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PalmScaffold(
      appBar: glassAppBar(
title: isArabic ? 'إدارة النخيل' : 'Manage Palms',
      ),
      body: SafeArea(
        child: StreamBuilder<List<Palm>>(
          stream: RasdManagementService.watchPalms(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final palms = _filteredPalms(snapshot.data!);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
decoration: InputDecoration(
hintText: isArabic ? 'ابحثي برقم النخلة...' : 'Search by Palm ID...',
prefixIcon: const Icon(Icons.search),
),
                  ),
                ),
                Expanded(
                  child: palms.isEmpty
                      ? Center(
                          child: GlassBox(
                            child: Text(
isArabic ? 'لم يتم العثور على نخيل' : 'No palms found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
label: Text(isArabic ? 'إضافة نخلة' : 'Add Palm'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
),
);
},
);
}

  /// Builds one palm row.
  Widget _buildPalmCard(Palm palm) {
    final color = _statusColor(palm.statusLabel);

    return GlassBox(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      child: Row(
          children: [
            Container(
              width: 52,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: appIcon(_statusIcon(palm.statusLabel), color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(palm.id,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
AuthStore.arabic.value
? _translateStatus(palm.statusLabel)
: palm.statusLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
Text(
'${palm.type ?? '-'} · '
'${palm.age == null ? '-' : '${palm.age} ${AuthStore.arabic.value ? 'سنة' : 'yrs'}'} · '
'${palm.deviceId.isEmpty ? (AuthStore.arabic.value ? 'لا يوجد مستشعر' : 'No device') : palm.deviceId}',
style: Theme.of(context).textTheme.bodySmall,
),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _openEditPalm(palm),
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primary,
tooltip: AuthStore.arabic.value ? 'تعديل' : 'Edit',
            ),
            IconButton(
              onPressed: () => _confirmDelete(palm),
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
tooltip: AuthStore.arabic.value ? 'حذف' : 'Delete',
            ),
          ],
        ),
    );
  }
}
