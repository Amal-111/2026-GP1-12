import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import 'farm_location_picker.dart';
import 'connect_sensor_page.dart';

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
  int _step = 0; // 0 = information, 1 = location

  @override
  void dispose() {
    _ageController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _useCurrentLocation() {
    // TODO: get the real GPS location with the "geolocator" package.
    // For now it fills a sample location in the farm.
    setState(() {
      _latController.text = '24.7136';
      _lngController.text = '46.6753';
    });
  }

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

  void _back() {
    if (_step == 1) {
      setState(() => _step = 0);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: PalmScaffold(
        appBar: glassAppBar(
          title: 'Add New Palm',
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
                      PalmHeaderCard(
                        title: 'New Palm $_palmId',
                        subtitle: MockData.selectedFarm.name,
                        chip: InfoChip(
                          text: 'Step ${_step + 1} of 3',
                          icon: Icons.flag_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassBox(child: PalmStepHeader(currentStep: _step)),
                      const SizedBox(height: 14),
                      GlassBox(
                        child: _step == 0
                            ? _buildInfoStep()
                            : _buildLocationStep(),
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
                    child: Text(_step == 0 ? 'Next' : 'Next: Connect Sensor'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep() {
    return Form(
      key: _infoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.info_outline_rounded,
            title: 'Palm Information',
          ),
          const _FieldLabel('Palm ID'),
          // Given by the system, cannot be changed here.
          TextFormField(
            initialValue: 'Assigned on save',
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              helperText: 'Final ID assigned automatically when saved',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Age (years)'),
          TextFormField(
            controller: _ageController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: PalmValidators.age,
            decoration: const InputDecoration(
              hintText: 'e.g. 10',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Type'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            hint: const Text('Select palm type'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: PalmStore.palmTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) => setState(() => _type = value),
            validator: PalmValidators.required,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Form(
      key: _locationFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.location_on_outlined,
            title: 'Palm Location',
          ),
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
            label: const Text('Use Current Location'),
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
                    const _FieldLabel('Latitude'),
                    TextFormField(
                      controller: _latController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: PalmValidators.latitude,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          const InputDecoration(hintText: 'e.g. 24.7136'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Longitude'),
                    TextFormField(
                      controller: _lngController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: PalmValidators.longitude,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          const InputDecoration(hintText: 'e.g. 46.6753'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This will save the location of the palm tree.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The 3 steps shown at the top of Add Palm and Connect Sensor:
/// numbered circles joined by a line, with a short description.
class PalmStepHeader extends StatelessWidget {
  final int currentStep; // 0, 1 or 2

  const PalmStepHeader({super.key, required this.currentStep});

  static const _titles = [
    'Enter Palm Information',
    'Set Location',
    'Connect Sensor',
  ];

  static const _descriptions = [
    'Age and type of the palm',
    'Choose where the palm is on the map',
    'Link a monitoring sensor to the palm',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_titles.length, (i) {
        final done = i < currentStep;
        final current = i == currentStep;
        final active = done || current;
        final isLast = i == _titles.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Circle + line to the next step.
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
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
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: done ? AppColors.primary : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titles[i],
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _descriptions[i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (current)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: InfoChip(text: 'Now'),
                ),
            ],
          ),
        );
      }),
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
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
