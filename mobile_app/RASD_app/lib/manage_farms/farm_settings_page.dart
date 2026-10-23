import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_data.dart';
import '../services/rasd_management_service.dart';
import '../manage_palms/farm_location_picker.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

class FarmSettingsPage extends StatefulWidget {
  const FarmSettingsPage({super.key});

  @override
  State<FarmSettingsPage> createState() => _FarmSettingsPageState();
}

class _FarmSettingsPageState extends State<FarmSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _imagePath;

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
    _latitude = farm.latitude;
    _longitude = farm.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {
      _imagePath = image.path;
    });
  }

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

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _latitude == null || _longitude == null) {
      showCenterMessage(context, 'Please enter a farm name and location.', success: false);
      return;
    }
    try {
      await RasdManagementService.updateFarm(name: name,
        description: _descriptionController.text.trim(),
        latitude: _latitude!, longitude: _longitude!);
      if (!mounted) return;
      showCenterMessage(context, 'Farm information updated successfully.');
    } catch (error) {
      if (mounted) showCenterMessage(context, error.toString(), success: false);
    }
  }

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
      if (mounted) showCenterMessage(context, error.toString(), success: false);
      return;
    }
    if (!mounted) return;

    Navigator.popUntil(
      context,
          (route) => route.isFirst,
    );
  }

  Widget _buildFarmImage() {
    final isAsset = _imagePath.startsWith('assets/');

    if (isAsset) {
      return Image.asset(
        _imagePath,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _imageFallback();
        },
      );
    }

    return Image.file(
      File(_imagePath),
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return _imageFallback();
      },
    );
  }

  Widget _imageFallback() {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.beige,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 48,
        color: AppColors.primary,
      ),
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
                      const _FieldLabel('Farm Image'),

                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(16),
                            child: _buildFarmImage(),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Material(
                              color: Colors.white.withValues(
                                alpha: 0.88,
                              ),
                              borderRadius:
                              BorderRadius.circular(12),
                              child: IconButton(
                                onPressed: _pickImage,
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: AppColors.primary,
                                ),
                                tooltip: 'Change farm image',
                              ),
                            ),
                          ),
                        ],
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
                  onPressed: _saveChanges,
                  child: const Text(
                    'Save Changes',
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