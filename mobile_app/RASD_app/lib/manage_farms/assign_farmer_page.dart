// Lets the farm owner invite a farmer to the farm by email.
import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../auth/auth_widgets.dart';
import '../data/auth_store.dart';
/// Invite Farmer page.
class AssignFarmerPage extends StatefulWidget {
  const AssignFarmerPage({super.key});
  @override
  State<AssignFarmerPage> createState() => _AssignFarmerPageState();
}

class _AssignFarmerPageState extends State<AssignFarmerPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  /// True while saving (disables the button).
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Sends an invitation to the farmer email entered by the owner.
  Future<void> _sendInvitation() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RasdManagementService.inviteFarmer(_emailController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر إرسال الدعوة'
              : 'Could not send the invitation',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic ? 'دعوة مزارع' : 'Invite Farmer',
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GlassBox(child: Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'البريد الإلكتروني للمزارع' : 'Farmer Email',
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'أدخل البريد الإلكتروني المسجل للمزارع'
                              : 'Enter registered farmer email',
                        ),
                        validator: AuthValidators.email),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? 'يجب أن يكون لدى المزارع حساب مسجل بدور مزارع وأن يقبل الدعوة.'
                          : 'The farmer must have a registered Farmer account and accept the invitation.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ))),
              )),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _sendInvitation,
                        child: Text(
                          _saving
                              ? (isArabic ? 'جارٍ الإرسال...' : 'Sending...')
                              : (isArabic ? 'إرسال الدعوة' : 'Send Invitation'),
                        ),))),
            ]),
          ),
        );
      },
    );
  }
}
