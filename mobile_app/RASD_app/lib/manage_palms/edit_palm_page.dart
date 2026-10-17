import 'package:flutter/material.dart';
import 'palm_store.dart';
import '../theme/glass_widgets.dart';

/// Edit Palm: opens with the palm's current information filled in.
/// Changes are applied only when "Save Changes" is pressed.
class EditPalmPage extends StatefulWidget {
  final Palm palm;

  const EditPalmPage({super.key, required this.palm});

  @override
  State<EditPalmPage> createState() => _EditPalmPageState();
}

class _EditPalmPageState extends State<EditPalmPage> {
  final PalmStore _store = PalmStore.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _ageController;
  late final TextEditingController _notesController;
  late String _type;
  late String _status;

  @override
  void initState() {
    super.initState();
    final palm = widget.palm;
    _idController = TextEditingController(text: palm.id);
    _ageController = TextEditingController(text: '${palm.age}');
    _notesController = TextEditingController(text: palm.notes);
    _type = palm.type;
    _status = palm.status;
  }

  @override
  void dispose() {
    _idController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateId(String? value) {
    final error = PalmValidators.palmId(value);
    if (error != null) return error;
    if (_store.idExists(value!, except: widget.palm)) {
      return 'This tree ID already exists in this farm.';
    }
    return null;
  }

  /// True if the user changed at least one field.
  bool get _hasChanges {
    final palm = widget.palm;
    return _idController.text.trim() != palm.id ||
        _ageController.text.trim() != '${palm.age}' ||
        _type != palm.type ||
        _status != palm.status ||
        _notesController.text.trim() != palm.notes;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasChanges) {
      showCenterMessage(
        context,
        'No changes were made to this palm.',
        success: false,
      );
      return;
    }

    _store.updatePalm(
      widget.palm,
      id: _idController.text,
      age: int.parse(_ageController.text.trim()),
      type: _type,
      status: _status,
      notes: _notesController.text,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall;

    return PalmScaffold(
      appBar: glassAppBar(title: 'Edit Palm'),
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
                      Text('Palm ID', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _idController,
                        validator: _validateId,
                        // Letters can be typed, but an error message appears.
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.tag),
                          helperText: '4 digits, e.g. 0007',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Age (years)', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ageController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: PalmValidators.age,
                      ),
                      const SizedBox(height: 18),
                      Text('Type', style: labelStyle),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        items: _withCurrent(PalmStore.palmTypes, _type)
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                      const SizedBox(height: 18),
                      Text('Status', style: labelStyle),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        items: _withCurrent(PalmStore.statuses, _status)
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 18),
                      Text('Notes (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        // Free text: letters, numbers, Arabic or English.
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          hintText: 'e.g. additional notes about this palm',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Sensor: ${widget.palm.deviceId}',
                        style: Theme.of(context).textTheme.bodySmall,
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
                  onPressed: _save,
                  child: const Text('Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Makes sure the current value is in the list (avoids a dropdown crash).
  List<String> _withCurrent(List<String> options, String current) {
    return options.contains(current) ? options : [...options, current];
  }
}
