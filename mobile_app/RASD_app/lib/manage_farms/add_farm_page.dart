import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_data.dart';
import '../manage_palms/farm_location_picker.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';

class AddFarmPage extends StatefulWidget {
  const AddFarmPage({super.key});

  @override
  State<AddFarmPage> createState() => _AddFarmPageState();
}

class _AddFarmPageState extends State<AddFarmPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _palmCountController = TextEditingController();

  late final String _farmId;

  String _imagePath = '';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _farmId = MockData.nextFarmId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _palmCountController.dispose();
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

  void _addFarm() {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      showCenterMessage(
        context,
        'Please select the farm location.',
        success: false,
      );
      return;
    }

    final farm = RasdFarm(
      _farmId,
      _nameController.text.trim(),
      location:
      '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
      imagePath: _imagePath,
      description: _descriptionController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      palmCount: int.parse(
        _palmCountController.text.trim(),
      ),
      farmerCount: 0,
    );

    MockData.addFarm(farm);

    Navigator.pop(context, true);
  }

  Widget _buildFarmImage() {
    if (_imagePath.isEmpty) {
      return Container(
        width: double.infinity,
        height: 170,
        color: AppColors.beige,
        alignment: Alignment.center,
        child: const PalmIcon(
          size: 52,
          color: AppColors.primary,
        ),
      );
    }

    return Image.file(
      File(_imagePath),
      width: double.infinity,
      height: 170,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          width: double.infinity,
          height: 170,
          color: AppColors.beige,
          alignment: Alignment.center,
          child: const Icon(
            Icons.agriculture_rounded,
            size: 52,
            color: AppColors.primary,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Add New Farm',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GlassBox(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Farm Image'),

                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildFarmImage(),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Material(
                                color: Colors.white.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: IconButton(
                                  onPressed: _pickImage,
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel('Farm Name'),

                        TextFormField(
                          controller: _nameController,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter the farm name';
                            }

                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Enter farm name',
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel(
                          'Description (optional)',
                        ),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Location, notes, etc.',
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel('Number of Palms'),

                        TextFormField(
                          controller: _palmCountController,
                          keyboardType: TextInputType.number,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            final count = int.tryParse(
                              value?.trim() ?? '',
                            );

                            if (count == null) {
                              return 'Please enter the number of palms';
                            }

                            if (count < 0) {
                              return 'Number of palms cannot be negative';
                            }

                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'e.g. 120',
                            prefixIcon: Icon(
                              Icons.numbers_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel('Location'),

                        GlassBox(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _openLocationPicker,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
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
                                    child: Text(
                                      _latitude != null &&
                                          _longitude != null
                                          ? '${_latitude!.toStringAsFixed(6)}, '
                                          '${_longitude!.toStringAsFixed(6)}'
                                          : 'Select farm location',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        color:
                                        AppColors.textSecondary,
                                      ),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addFarm,
                  child: const Text('Add Farm'),
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

class _FarmLocationPageState extends State<_FarmLocationPage> {
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: FarmLocationPicker(
                  latitude: _latitude,
                  longitude: _longitude,
                  pinIcon: Icons.agriculture_rounded,
                  onPicked: (location) {
                    setState(() {
                      _latitude = location.latitude;
                      _longitude = location.longitude;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  _latitude == null || _longitude == null
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                      (
                      latitude: _latitude!,
                      longitude: _longitude!,
                      ),
                    );
                  },
                  child: const Text('Use This Location'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}