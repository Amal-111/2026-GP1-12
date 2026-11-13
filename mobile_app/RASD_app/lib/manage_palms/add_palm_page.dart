// Add Palm screen (two steps: palm information, then location).
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import 'farm_location_picker.dart';
import 'connect_sensor_page.dart';
import '../data/auth_store.dart';
/// Add New Palm: step 1 (palm information) and step 2 (location).
/// Step 3 (connect sensor) is on ConnectSensorPage.
/// The palm is only saved after the sensor is connected.
class AddPalmPage extends StatefulWidget {
  const AddPalmPage({super.key});

  @override
  State<AddPalmPage> createState() => _AddPalmPageState();
}

class _AddPalmPageState extends State<AddPalmPage> {
  final PalmStore _store = PalmStore.instance;

  final _infoFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String? _type;
  /// Current step of the form.
  int _step = 0; // 0 = information, 1 = location

  /// Releases text controllers.
  @override
  void dispose() {
    _ageController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  /// Fills the location with the device's current position.
  void _useCurrentLocation() {
    // TODO: get the real GPS location with the "geolocator" package.
    // For now it fills a sample location in the farm.
    setState(() {
      _latController.text = '24.7136';
      _lngController.text = '46.6753';
    });
  }

  /// Validates the current step and moves forward (or saves on the last step).
  Future<void> _next() async {
    if (_step == 0) {
      if (_infoFormKey.currentState!.validate()) {
        setState(() => _step = 1);
      }
      return;
    }

    if (!_locationFormKey.currentState!.validate()) return;

    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectSensorPage(
          age: int.parse(_ageController.text.trim()),
          type: _type!, latitude: lat, longitude: lng,
        ),
      ),
    );
    if (added == true && mounted) Navigator.pop(context, true);
  }

  /// Goes back one step.
  void _back() {
    if (_step == 1) {
      setState(() => _step = 0);
    } else {
      Navigator.pop(context);
    }
  }

  /// Translates palm types only for display.
  String _translatePalmType(String type, bool isArabic) {
    if (!isArabic) return type;

    switch (type) {
      case 'Sukkari':
        return 'سكري';
      case 'Khalas':
        return 'خلاص';
      case 'Ajwa':
        return 'عجوة';
      case 'Barhi':
        return 'برحي';
      default:
        return type;
    }
  }

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: PalmScaffold(
        appBar: glassAppBar(
title: isArabic ? 'إضافة نخلة جديدة' : 'Add New Palm',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _back,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassBox(child: PalmStepHeader(currentStep: _step)),
                      const SizedBox(height: 16),
                      GlassBox(
child: _step == 0
? _buildInfoStep(isArabic)
: _buildLocationStep(isArabic),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
child: Text(
_step == 0
? (isArabic ? 'التالي' : 'Next')
: (isArabic ? 'التالي: ربط المستشعر' : 'Next: Connect Sensor'),
),
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

  /// Step 1: palm information fields.
Widget _buildInfoStep(bool isArabic) {
    return Form(
      key: _infoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
_FieldLabel(isArabic ? 'معرّف النخلة' : 'Palm ID'),
          // Given by the system, cannot be changed here.
          TextFormField(
initialValue: isArabic ? 'يُحدد عند الحفظ' : 'Assigned on save',
            readOnly: true,
            enabled: false,
decoration: InputDecoration(
helperText: isArabic
? 'يتم تعيين المعرّف النهائي تلقائيًا عند الحفظ'
: 'Final ID assigned automatically when saved',
prefixIcon: const Icon(Icons.tag),
),
          ),
          const SizedBox(height: 18),
_FieldLabel(isArabic ? 'العمر (بالسنوات)' : 'Age (years)'),
          TextFormField(
            controller: _ageController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: PalmValidators.age,
decoration: InputDecoration(
hintText: isArabic ? 'مثال: 10' : 'e.g. 10',
),
          ),
          const SizedBox(height: 18),
_FieldLabel(isArabic ? 'النوع' : 'Type'),
          DropdownButtonFormField<String>(
            initialValue: _type,
hint: Text(
isArabic ? 'اختر نوع النخلة' : 'Select palm type',
),
            items: PalmStore.palmTypes
                .map((t) => DropdownMenuItem(
              value: t,
              child: Text(_translatePalmType(t, isArabic)),
            ))
                .toList(),
            onChanged: (value) => setState(() => _type = value),
            validator: PalmValidators.required,
          ),
        ],
      ),
    );
  }

  /// Step 2: choose the palm location.
Widget _buildLocationStep(bool isArabic) {
    return Form(
      key: _locationFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FarmLocationPicker(
            latitude: double.tryParse(_latController.text.trim()),
            longitude: double.tryParse(_lngController.text.trim()),
            onPicked: (point) => setState(() {
              _latController.text = '${point.latitude}';
              _lngController.text = '${point.longitude}';
            }),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location_rounded),
label: Text(
isArabic ? 'استخدم موقعي الحالي' : 'Use Current Location',
),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 18),
          // The numbers update when the map is tapped, and typing
          // here moves the pin on the map.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
_FieldLabel(isArabic ? 'خط العرض' : 'Latitude'),
                    TextFormField(
                      controller: _latController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: PalmValidators.latitude,
                      onChanged: (_) => setState(() {}),
decoration: InputDecoration(
hintText: isArabic ? 'مثال: 24.7136' : 'e.g. 24.7136',
),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
_FieldLabel(isArabic ? 'خط الطول' : 'Longitude'),
                    TextFormField(
                      controller: _lngController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: PalmValidators.longitude,
                      onChanged: (_) => setState(() {}),
decoration: InputDecoration(
hintText: isArabic ? 'مثال: 46.6753' : 'e.g. 46.6753',
),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
Text(
isArabic
? 'سيتم حفظ موقع النخلة.'
: 'This will save the location of the palm tree.',
style: Theme.of(context).textTheme.bodySmall,
),
        ],
      ),
    );
  }
}

/// The 3 steps shown at the top of Add Palm and Connect Sensor.
class PalmStepHeader extends StatelessWidget {
  final int currentStep; // 0, 1 or 2

  const PalmStepHeader({super.key, required this.currentStep});

  static const _titles = [
    'Enter Palm Information',
    'Set Location',
    'Connect Sensor',
  ];

  @override
  Widget build(BuildContext context) {
    final titles = AuthStore.arabic.value
        ? [
      'أدخل معلومات النخلة',
      'حدد الموقع',
      'اربط المستشعر',
    ]
        : _titles;
    return Column(
      children: List.generate(titles.length, (i) {
        final active = i <= currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    active ? AppColors.primary : AppColors.border,
                child: i < currentStep
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Text(
titles[i],
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
