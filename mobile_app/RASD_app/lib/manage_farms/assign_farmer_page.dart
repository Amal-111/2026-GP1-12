import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';

class AssignFarmerPage extends StatefulWidget {
  const AssignFarmerPage({super.key});
  @override
  State<AssignFarmerPage> createState() => _AssignFarmerPageState();
}

class _AssignFarmerPageState extends State<AssignFarmerPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RasdManagementService.inviteFarmer(_emailController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showCenterMessage(context, error.toString(), success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(title: 'Invite Farmer'),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: GlassBox(child: Form(key: _formKey, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Farmer Email', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Enter registered farmer email'),
                  validator: (value) => value == null || !value.contains('@')
                    ? 'Please enter a valid email' : null),
                const SizedBox(height: 12),
                Text('The farmer must have a registered Farmer account and accept the invitation.',
                  style: Theme.of(context).textTheme.bodyMedium),
              ],
            ))),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: _saving ? null : _sendInvitation,
                child: Text(_saving ? 'Sending...' : 'Send Invitation')))),
        ]),
      ),
    );
  }
}
