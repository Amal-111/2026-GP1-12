
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';

/// Lets the farm owner search for a farmer and send an invitation.
class AssignFarmerPage extends StatefulWidget {
  const AssignFarmerPage({super.key});

  @override
  State<AssignFarmerPage> createState() => _AssignFarmerPageState();
}

class _AssignFarmerPageState extends State<AssignFarmerPage> {
  final _nameController = TextEditingController();

  bool _searching = false;
  bool _saving = false;
  bool _searched = false;

  List<Map<String, String>> _results = [];

  String? _selectedFarmerId;
  String? _selectedFarmerName;

  /// Releases controllers when this page closes.

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Searches for available farmers by name.
  Future<void> _searchFarmers() async {
    if (_searching || _saving) return;

    final name = _nameController.text.trim();

    if (name.length < 2) {
      showCenterMessage(
        context,
        AuthStore.arabic.value
            ? 'أدخل حرفين على الأقل للبحث عن المزارع.'
            : 'Enter at least two characters to search.',
        success: false,
      );
      return;
    }

    setState(() {
      _searching = true;
      _searched = false;
      _results = [];
      _selectedFarmerId = null;
      _selectedFarmerName = null;
    });

    try {
      debugPrint('SEARCH FARMERS: Starting search');
      debugPrint('SEARCH FARMERS NAME: $name');

      final results =
      await RasdManagementService.searchFarmers(name);

      debugPrint(
        'SEARCH FARMERS SUCCESS: ${results.length} results',
      );

      if (!mounted) return;

      // Do not show results for an outdated search term.
      if (_nameController.text.trim() != name) return;

      setState(() {
        _results = results;
        _searched = true;
      });
    } on FirebaseFunctionsException catch (error) {
      // Show the actual Firebase Functions error in Run Console.
      debugPrint('=================================');
      debugPrint('SEARCH FARMERS FIREBASE ERROR');
      debugPrint('SEARCH FARMERS ERROR CODE: ${error.code}');
      debugPrint('SEARCH FARMERS ERROR MESSAGE: ${error.message}');
      debugPrint('SEARCH FARMERS ERROR DETAILS: ${error.details}');
      debugPrint('=================================');

      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر البحث عن المزارعين'
              : 'Could not search for farmers',
        );
      }
    } catch (error, stackTrace) {
      // Catch unexpected errors such as invalid response formats.
      debugPrint('=================================');
      debugPrint('SEARCH FARMERS UNEXPECTED ERROR: $error');
      debugPrint('SEARCH FARMERS STACK TRACE: $stackTrace');
      debugPrint('=================================');

      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر البحث عن المزارعين'
              : 'Could not search for farmers',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  /// Sends an invitation to the selected farmer account.
  Future<void> _sendInvitation() async {
    if (_saving || _searching) return;

    final farmerId = _selectedFarmerId;

    if (farmerId == null) {
      showCenterMessage(
        context,
        AuthStore.arabic.value
            ? 'ابحث عن المزارع واختر حسابه أولًا.'
            : 'Search for a farmer and select an account first.',
        success: false,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await RasdManagementService.inviteFarmerById(farmerId);

      if (!mounted) return;

      Navigator.pop(context, true);
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
      if (mounted) {
        setState(() => _saving = false);
      }
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
            title: isArabic ? 'دعوة مزارع' : 'Invite Farmer',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'اسم المزارع'
                                : 'Farmer Name',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall,
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: isArabic
                                  ? 'أدخل اسم المزارع للبحث'
                                  : 'Enter farmer name to search',
                              prefixIcon: const Icon(
                                Icons.search,
                              ),
                            ),
                            onChanged: (_) {
                              setState(() {
                                _results = [];
                                _searched = false;
                                _selectedFarmerId = null;
                                _selectedFarmerName = null;
                              });
                            },
                            onFieldSubmitted: (_) =>
                                _searchFarmers(),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: (_searching || _saving)
                                  ? null
                                  : _searchFarmers,
                              icon: const Icon(Icons.search),
                              label: Text(
                                _searching
                                    ? (isArabic
                                    ? 'جارٍ البحث...'
                                    : 'Searching...')
                                    : (isArabic
                                    ? 'بحث'
                                    : 'Search'),
                              ),
                            ),
                          ),

                          if (_searched) ...[
                            const SizedBox(height: 16),

                            Text(
                              isArabic
                                  ? 'نتائج البحث'
                                  : 'Search Results',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall,
                            ),

                            const SizedBox(height: 8),

                            if (_results.isEmpty)
                              Text(
                                isArabic
                                    ? 'لم يتم العثور على مزارعين متاحين بهذا الاسم.'
                                    : 'No available farmers found with this name.',
                              ),

                            for (final farmer in _results) ...[
                              const SizedBox(height: 8),

                              InkWell(
                                borderRadius:
                                BorderRadius.circular(12),
                                onTap: _saving
                                    ? null
                                    : () {
                                  setState(() {
                                    _selectedFarmerId =
                                    farmer['farmerId'];
                                    _selectedFarmerName =
                                    farmer['fullName'];
                                  });
                                },
                                child: Container(
                                  padding:
                                  const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedFarmerId ==
                                          farmer['farmerId']
                                          ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              farmer['fullName'] ??
                                                  '',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),

                                            Text(
                                              '${isArabic ? "معرّف الحساب" : "Account ID"}: '
                                                  '••••${_idSuffix(farmer['farmerId'] ?? '')}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),

                                      Icon(
                                        _selectedFarmerId ==
                                            farmer['farmerId']
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: _selectedFarmerId ==
                                            farmer['farmerId']
                                            ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            : Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],

                          if (_selectedFarmerId != null) ...[
                            const SizedBox(height: 16),

                            Text(
                              isArabic
                                  ? 'المزارع المحدد: $_selectedFarmerName'
                                  : 'Selected farmer: $_selectedFarmerName',
                            ),
                          ],

                          const SizedBox(height: 16),

                          Text(
                            isArabic
                                ? 'يجب أن يكون لدى المزارع حساب مسجل بدور مزارع وأن يقبل الدعوة.'
                                : 'The farmer must have a registered Farmer account and accept the invitation.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium,
                          ),
                        ],
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
                      onPressed: (_saving ||
                          _searching ||
                          _selectedFarmerId == null)
                          ? null
                          : _sendInvitation,
                      child: Text(
                        _saving
                            ? (isArabic
                            ? 'جارٍ الإرسال...'
                            : 'Sending...')
                            : (isArabic
                            ? 'إرسال الدعوة'
                            : 'Send Invitation'),
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

  /// Displays a short identifier without modifying the actual Firebase UID.
  String _idSuffix(String value) {
    if (value.length <= 4) return value;
    return value.substring(value.length - 4);
  }
}
