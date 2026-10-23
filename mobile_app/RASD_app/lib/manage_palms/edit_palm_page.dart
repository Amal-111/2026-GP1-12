
import 'package:flutter/material.dart';

import 'palm_store.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';

/// Edit Palm: opens with the palm's current information filled in.
/// Changes are applied only when "Save Changes" is pressed.
class EditPalmPage extends StatefulWidget {
  final Palm palm;

  const EditPalmPage({
    super.key,
    required this.palm,
  });

  @override
  State<EditPalmPage> createState() => _EditPalmPageState();
}

class _EditPalmPageState extends State<EditPalmPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _ageController;

  String? _type;
  late String _status;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final palm = widget.palm;

    _idController = TextEditingController(
      text: PalmStore.numberFromPalmId(palm.id),
    );

    _ageController = TextEditingController(
      text: '${palm.age ?? ''}',
    );

    _type = palm.type;
    _status = palm.statusLabel;
  }

  @override
  void dispose() {
    _idController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Checks whether the user changed any editable field.
  bool get _hasChanges {
    final palm = widget.palm;

    return _ageController.text.trim() != '${palm.age ?? ''}' ||
        _type != palm.type;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasChanges) {
      showCenterMessage(
        context,
        'No changes were made to this palm.',
        success: false,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await RasdManagementService.updatePalm(
        widget.palm,
        age: int.parse(_ageController.text.trim()),
        type: _type!,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      showCenterMessage(
        context,
        error.toString(),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall;

    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Edit Palm',
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Palm ID - Read Only
                        Text(
                          'Palm ID',
                          style: labelStyle,
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _idController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.tag),
                            prefixText: 'P',
                            helperText:
                            'Assigned by the system; cannot be changed',
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Palm Age
                        Text(
                          'Age (years)',
                          style: labelStyle,
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: PalmValidators.age,
                        ),

                        const SizedBox(height: 18),

                        // Palm Type
                        Text(
                          'Type',
                          style: labelStyle,
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          hint: const Text('Select palm type'),
                          items: _withCurrent(
                            PalmStore.palmTypes,
                            _type,
                          ).map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          validator: PalmValidators.required,
                          onChanged: (value) {
                            setState(() {
                              _type = value;
                            });
                          },
                        ),

                        const SizedBox(height: 18),

                        // Palm Status - Read Only
                        Text(
                          'Status',
                          style: labelStyle,
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          items: _withCurrent(
                            PalmStore.statuses,
                            _status,
                          ).map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: null,
                        ),

                        const SizedBox(height: 18),

                        // Connected Sensor - Read Only
                        Text(
                          'Sensor: ${widget.palm.deviceId.isEmpty ? 'Not connected' : widget.palm.deviceId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Save Changes Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps the current value in the dropdown options.
  List<String> _withCurrent(
      List<String> options,
      String? current,
      ) {
    if (current == null || options.contains(current)) {
      return options;
    }

    return [...options, current];
  }
}
