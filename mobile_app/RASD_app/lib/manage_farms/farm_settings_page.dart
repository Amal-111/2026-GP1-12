// Farm settings: edit farm details, location and photo, or delete the farm.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../services/rasd_errors.dart';
import '../services/rasd_farms_service.dart';
import '../services/rasd_management_service.dart';
import '../widgets/farm_photo.dart';
import '../manage_palms/farm_location_picker.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

/// Farm settings page.
class FarmSettingsPage extends StatefulWidget {
  const FarmSettingsPage({super.key});

  @override
  State<FarmSettingsPage> createState() => _FarmSettingsPageState();
}

class _FarmSettingsPageState extends State<FarmSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  /// Photo shown on screen: a saved web address or a file just picked.
  late String _imagePath;

  /// The photo that was saved when the page opened (to know if it changed).
  late String _savedImagePath;

  /// True while saving (disables the button).
  bool _saving = false;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    final farm = MockData.selectedFarm;

    _nameController = TextEditingController(
      text: farm.name,
    );

    _descriptionController = TextEditingController(
      text: farm.description,
    );

    _imagePath = farm.imagePath;
    _savedImagePath = farm.imagePath;
    _latitude = farm.latitude;
    _longitude = farm.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Opens the Camera / Gallery choice and shows the chosen photo.
  /// The photo is only uploaded when the user taps Save.
  Future<void> _pickImage() async {
    final path = await FarmPhotoPicker.choose(context);
    if (path == null) return;
    setState(() => _imagePath = path);
  }

  /// Opens the map so the user can choose a location.
  Future<void> _openLocationPicker() async {
    final result =
    await Navigator.push<({double latitude, double longitude})>(
      context,
      MaterialPageRoute(
        builder: (_) => _FarmLocationPage(
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  /// Saves the farm details, then uploads the photo if it was changed or removed.
  Future<void> _saveChanges() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showCenterMessage(
        context,
        'Enter the farm name before saving.',
        success: false,
        title: 'Farm name is missing',
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      showCenterMessage(
        context,
        'Tap the location box and choose where the farm is on the map.',
        success: false,
        title: 'Farm location is missing',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 1. Save name, description and location.
      await RasdManagementService.updateFarm(
        name: name,
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
      );

      // 2. Photo: upload a new one, or clear it when it was removed.
      final photoChanged = _imagePath != _savedImagePath;
      if (photoChanged) {
        try {
          final farmId = RasdManagementService.farmId;
          final imageUrl = _imagePath.isEmpty
              ? ''
              : await RasdFarmsService.uploadFarmImage(
                  farmId: farmId,
                  imagePath: _imagePath,
                );
          await RasdFarmsService.updateFarmImage(
            farmId: farmId,
            imageUrl: imageUrl,
          );
          _savedImagePath = _imagePath;
        } catch (error) {
          // The details were saved; only the photo failed.
          if (!mounted) return;
          await showRasdError(context, error, title: 'Photo not saved');
          return;
        }
      }

      if (!mounted) return;
      showCenterMessage(context, 'Farm information updated successfully.');
    } catch (error) {
      if (mounted) {
        showRasdError(context, error, title: 'Could not save the farm');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks for confirmation, then deletes the farm.
  Future<void> _confirmDeleteFarm() async {
    final farm = MockData.selectedFarm;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${farm.name}?'),
        content: const Text(
          'Are you sure you want to delete this farm? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await RasdManagementService.deleteFarm();
    } catch (error) {
      if (mounted) {
        showRasdError(context, error, title: 'Could not delete the farm');
      }
      return;
    }
    if (!mounted) return;

    Navigator.popUntil(
      context,
          (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Farm Settings',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                child: GlassBox(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Farm Photo'),

                      // Add / change / remove the farm photo.
                      FarmPhotoBox(
                        imagePath: _imagePath,
                        onChange: _pickImage,
                        onRemove: () => setState(() => _imagePath = ''),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Farm Name'),

                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter farm name',
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel(
                        'Description (optional)',
                      ),

                      TextField(
                        controller:
                        _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                          'e.g. Location, notes, etc.',
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Location'),

                      GlassBox(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius:
                          BorderRadius.circular(18),
                          onTap: _openLocationPicker,
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.primary,
                                  size: 30,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        'Location',
                                        style: Theme.of(
                                          context,
                                        )
                                            .textTheme
                                            .titleSmall,
                                      ),

                                      const SizedBox(
                                        height: 2,
                                      ),

                                      Text(
                                        _latitude != null &&
                                            _longitude !=
                                                null
                                            ? '${_latitude!.toStringAsFixed(6)}, '
                                            '${_longitude!.toStringAsFixed(6)}'
                                            : MockData
                                            .selectedFarm
                                            .location,
                                        style:
                                        Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color:
                                          AppColors
                                              .textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color:
                                  AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                10,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveChanges,
                  child: Text(
                    _saving ? 'Saving...' : 'Save Changes',
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDeleteFarm,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const Text(
                    'Delete Farm',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                    AppColors.error,
                    side: const BorderSide(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen map for choosing the farm location.
class _FarmLocationPage extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const _FarmLocationPage({
    required this.latitude,
    required this.longitude,
  });

  @override
  State<_FarmLocationPage> createState() =>
      _FarmLocationPageState();
}

class _FarmLocationPageState
    extends State<_FarmLocationPage> {
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    _latitude = widget.latitude;
    _longitude = widget.longitude;
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Farm Location',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20,
          ),
          child: Column(
            children: [
              Expanded(
                child: FarmLocationPicker(
                  latitude: _latitude,
                  longitude: _longitude,
                  pinIcon:
                  Icons.agriculture_rounded,
                  onPicked: (location) {
                    setState(() {
                      _latitude =
                          location.latitude;
                      _longitude =
                          location.longitude;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  _latitude == null ||
                      _longitude == null
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                      (
                      latitude:
                      _latitude!,
                      longitude:
                      _longitude!,
                      ),
                    );
                  },
                  child:
                  const Text('Use This Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small label shown above a form field.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Text(
        text,
        style:
        Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
