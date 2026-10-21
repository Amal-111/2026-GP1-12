import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import 'add_palm_page.dart';
import 'palm_ui.dart';
import '../theme/glass_widgets.dart';
import 'farm_location_picker.dart';

/// Step 3 of adding a palm: connect its monitoring sensor.
/// A palm cannot be added without a sensor, so the palm is saved
/// only when "Connect Sensor" succeeds.
class ConnectSensorPage extends StatefulWidget {
  final String palmId;
  final int age;
  final String type;
  final double latitude;
  final double longitude;

  const ConnectSensorPage({
    super.key,
    required this.palmId,
    required this.age,
    required this.type,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<ConnectSensorPage> createState() => _ConnectSensorPageState();
}

class _ConnectSensorPageState extends State<ConnectSensorPage> {
  final PalmStore _store = PalmStore.instance;
  final _formKey = GlobalKey<FormState>();

  final _deviceController = TextEditingController();
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  bool _sameAsPalm = true;
  String? _deviceError;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: '${widget.latitude}');
    _lngController = TextEditingController(text: '${widget.longitude}');
  }

  @override
  void dispose() {
    _deviceController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _connect() {
    setState(() => _deviceError = _store.checkDevice(_deviceController.text));
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _deviceError != null) return;

    final sensorLat = _sameAsPalm
        ? widget.latitude
        : double.parse(_latController.text.trim());
    final sensorLng = _sameAsPalm
        ? widget.longitude
        : double.parse(_lngController.text.trim());

    // Saved in the team's shared data (MockData).
    _store.addPalm(
      id: widget.palmId,
      age: widget.age,
      type: widget.type,
      latitude: widget.latitude,
      longitude: widget.longitude,
      deviceNumber: _deviceController.text,
      sensorLatitude: sensorLat,
      sensorLongitude: sensorLng,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(title: 'Connect Sensor'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PalmHeaderCard(
                        title: 'New Palm ${widget.palmId}',
                        subtitle: '${widget.type} · ${widget.age} yrs',
                        chip: const InfoChip(
                          text: 'Step 3 of 3',
                          icon: Icons.flag_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const GlassBox(child: PalmStepHeader(currentStep: 2)),
                      const SizedBox(height: 14),
                      GlassBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      const SectionTitle(
                        icon: Icons.sensors_rounded,
                        title: 'Sensor Settings',
                      ),
                      _buildLinkedPalmCard(),
                      const SizedBox(height: 22),
                      Text('Device ID',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deviceController,
                        // The user types the number only; the system
                        // adds "D" and the zeros (8 -> D008).
                        // Letters can be typed, but an error message appears.
                        onChanged: (value) {
                          setState(() {
                            _deviceError = PalmStore.isDigits(value) ||
                                    value.trim().isEmpty
                                ? null
                                : 'Device ID must be a number.';
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. 8',
                          prefixIcon: const Icon(Icons.sensors_rounded),
                          prefixText: 'D',
                          helperText: 'Enter the number on the sensor',
                          errorText: _deviceError,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Sensor Location',
                          style: Theme.of(context).textTheme.titleSmall),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _sameAsPalm,
                        activeThumbColor: AppColors.primary,
                        title: const Text('Same as palm location'),
                        onChanged: (v) => setState(() => _sameAsPalm = v),
                      ),
                      if (!_sameAsPalm) ...[
                        FarmLocationPicker(
                          pinIcon: Icons.sensors_rounded,
                          latitude:
                              double.tryParse(_latController.text.trim()),
                          longitude:
                              double.tryParse(_lngController.text.trim()),
                          onPicked: (point) => setState(() {
                            _latController.text = '${point.latitude}';
                            _lngController.text = '${point.longitude}';
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          onChanged: (_) => setState(() {}),
                          controller: _latController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: PalmValidators.latitude,
                          decoration:
                              const InputDecoration(labelText: 'Latitude'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _lngController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: PalmValidators.longitude,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              const InputDecoration(labelText: 'Longitude'),
                        ),
                      ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect Sensor'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows which palm this sensor will be linked to.
  Widget _buildLinkedPalmCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PalmIcon(color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Linked to palm ${widget.palmId}',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${widget.type} · ${widget.age} yrs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${widget.latitude}, ${widget.longitude}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.link_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
