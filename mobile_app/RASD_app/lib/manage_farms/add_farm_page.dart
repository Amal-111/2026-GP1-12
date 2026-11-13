// Add Farm screen: farm details, location on the map and an optional farm photo.
import 'package:flutter/material.dart';

import '../services/rasd_errors.dart';
import '../services/rasd_farms_service.dart';
import '../widgets/farm_photo.dart';
import '../manage_palms/farm_location_picker.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../data/auth_store.dart';
/// Add Farm page.
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

  /// True while saving (disables the button).
  bool _saving = false;

  /// Path of the photo chosen on this device.
  String _imagePath = '';
  double? _latitude;
  double? _longitude;

  /// Releases controllers when this page closes.

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _palmCountController.dispose();
    super.dispose();
  }

  /// Opens the Camera / Gallery choice and keeps the chosen photo path.
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

  /// Validates the form, creates the farm and uploads the photo if one was chosen.
  Future<void> _addFarm() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      showCenterMessage(
        context,
        AuthStore.arabic.value
            ? 'اضغط على مربع الموقع وحدد موقع المزرعة على الخريطة.'
            : 'Tap the location box and choose where the farm is on the map.',
        success: false,
        title: AuthStore.arabic.value
            ? 'موقع المزرعة غير محدد'
            : 'Farm location is missing',
      );
      return;
    }
    setState(() => _saving = true);
    try {

      final farmId = await RasdFarmsService.createFarm(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        totalPalms: int.parse(_palmCountController.text.trim()),
        latitude: _latitude!,
        longitude: _longitude!,
      );

      if (_imagePath.isNotEmpty) {
        try {
          final imageUrl = await RasdFarmsService.uploadFarmImage(
            farmId: farmId,
            imagePath: _imagePath,
          );

          await RasdFarmsService.updateFarmImage(
            farmId: farmId,
            imageUrl: imageUrl,
          );
        } catch (error) {
          // The farm exists already; only the photo failed.
          debugPrint('Farm image upload failed: $error');

          if (!mounted) return;

          await showCenterMessage(
            context,
            AuthStore.arabic.value
                ? 'تمت إضافة المزرعة، ولكن تعذر حفظ الصورة. يمكنك إضافتها مرة أخرى من إعدادات المزرعة.'
                : 'The farm was added, but the photo could not be saved. '
                'Add it again from Farm Settings.',
            success: false,
            title: AuthStore.arabic.value ? 'تمت إضافة المزرعة' : 'Farm added',
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showRasdError(
        context,
        error,
        title: AuthStore.arabic.value
            ? 'تعذرت إضافة المزرعة'
            : 'Could not add farm',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

/// Builds the page using the selected language.

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PalmScaffold(
      appBar: glassAppBar(
        title: isArabic ? 'إضافة مزرعة جديدة' : 'Add New Farm',
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
                        _FieldLabel(isArabic ? 'صورة المزرعة (اختياري)' : 'Farm Photo (optional)'),

                        // Add / change / remove the farm photo.
                        FarmPhotoBox(
                          imagePath: _imagePath,
                          onChange: _pickImage,
                          onRemove: () => setState(() => _imagePath = ''),
                        ),

                        const SizedBox(height: 18),

                        _FieldLabel(isArabic ? 'اسم المزرعة' : 'Farm Name'),

                        TextFormField(
                          controller: _nameController,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return AuthStore.arabic.value
                                  ? 'هذا الحقل مطلوب.'
                                  : 'This field is required.';
                            }

                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: isArabic ? 'أدخل اسم المزرعة' : 'Enter farm name',
                          ),
                        ),

                        const SizedBox(height: 18),

                        _FieldLabel(
                          isArabic ? 'الوصف (اختياري)' : 'Description (optional)',
                        ),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: isArabic
                                ? 'مثال: الموقع، ملاحظات، وغيرها'
                                : 'e.g. Location, notes, etc.',
                          ),
                        ),

                        const SizedBox(height: 18),

                        _FieldLabel(isArabic ? 'عدد النخيل' : 'Number of Palms'),

                        TextFormField(
                          controller: _palmCountController,
                          keyboardType: TextInputType.number,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            final count = int.tryParse(
                              value?.trim() ?? '',
                            );

                            if ((value ?? '').trim().isEmpty) {
                              return AuthStore.arabic.value
                                  ? 'هذا الحقل مطلوب.'
                                  : 'This field is required.';
                            }

                            if (count == null) {
                              return AuthStore.arabic.value
                                  ? 'أدخل عدد النخيل كعدد صحيح.'
                                  : 'Enter the number of palms as a whole number.';
                            }

                            if (count < 0) {
                              return AuthStore.arabic.value
                                  ? 'أدخل عددًا يساوي صفرًا أو أكثر.'
                                  : 'Enter a number of palms that is 0 or more.';
                            }

                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: isArabic ? 'مثال: 120' : 'e.g. 120',
                            prefixIcon: Icon(
                              Icons.numbers_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        _FieldLabel(isArabic ? 'الموقع' : 'Location'),

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
                                          : (isArabic ? 'حدد موقع المزرعة' : 'Select farm location'),
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
                  onPressed: _saving ? null : _addFarm,
                  child: Text(
                    _saving
                        ? (isArabic ? 'جارٍ الحفظ...' : 'Saving...')
                        : (isArabic ? 'إضافة المزرعة' : 'Add Farm'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
);
},
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

class _FarmLocationPageState extends State<_FarmLocationPage> {
  double? _latitude;
  double? _longitude;

  /// Restores the current values when the page opens.

  @override
  void initState() {
    super.initState();

    _latitude = widget.latitude;
    _longitude = widget.longitude;
  }

/// Builds the page using the selected language.

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PalmScaffold(
      appBar: glassAppBar(
title: isArabic ? 'موقع المزرعة' : 'Farm Location',
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
child: Text(
isArabic ? 'استخدم هذا الموقع' : 'Use This Location',
),
                ),
              ),
            ],
          ),
        ),
      ),
);
},
);
}
}

/// Small label shown above a form field.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  /// Builds the page using the selected language.

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
