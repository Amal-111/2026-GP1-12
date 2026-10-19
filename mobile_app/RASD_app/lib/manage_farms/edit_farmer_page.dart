import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

class EditFarmerPage extends StatefulWidget {
  final FarmerData farmer;

  const EditFarmerPage({
    super.key,
    required this.farmer,
  });

  @override
  State<EditFarmerPage> createState() => _EditFarmerPageState();
}

class _EditFarmerPageState extends State<EditFarmerPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.farmer.name,
    );

    _emailController = TextEditingController(
      text: widget.farmer.email,
    );

    _phoneController = TextEditingController(
      text: widget.farmer.phoneNumber,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;

    MockData.updateFarmer(
      widget.farmer,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Edit Farmer',
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
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 42,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        const _FieldLabel('Full Name'),

                        TextFormField(
                          controller: _nameController,
                          autovalidateMode:
                          AutovalidateMode
                              .onUserInteraction,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter the farmer name';
                            }

                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel('Email'),

                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          autovalidateMode:
                          AutovalidateMode
                              .onUserInteraction,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter the email';
                            }

                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Email',
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _FieldLabel(
                          'Phone Number',
                        ),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType:
                          TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Phone Number',
                          ),
                        ),
                      ],
                    ),
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
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ),
          ],
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
        style:
        Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}