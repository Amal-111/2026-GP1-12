
import 'package:flutter/material.dart';
import '../theme/glass_widgets.dart';
import '../theme/app_colors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TreatmentRecordPage extends StatefulWidget {
  final String palmId;
  final String farmId;
  final VoidCallback? onMarkedTreated;

  const TreatmentRecordPage({
    super.key,
    required this.palmId,
    required this.farmId,
    this.onMarkedTreated,
  });

  @override
  State<TreatmentRecordPage> createState() =>
      _TreatmentRecordPageState();
}

class _TreatmentRecordPageState
    extends State<TreatmentRecordPage> {

  static const List<String> _treatmentMethods = [
    'Chemical Treatment',
    'Biological Treatment',
    'Mechanical Treatment',
    'Other',
  ];

  late DateTime _selectedDate;
  String? _selectedMethod;
  final TextEditingController _notesController =
  TextEditingController();

  bool _isSaving = false;

  Stream<DatabaseEvent> get _palmStream => FirebaseDatabase.instance
      .ref('palms/${widget.farmId}/${widget.palmId}')
      .onValue;

  Stream<DatabaseEvent> get _treatmentsStream => FirebaseDatabase.instance
      .ref('treatmentRecords/${widget.farmId}/${widget.palmId}')
      .onValue;

  List<Map<String, dynamic>> _readRecords(Object? value) {
    if (value is! Map) return [];
    final records = <Map<String, dynamic>>[];
    value.forEach((key, raw) {
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      final date = DateTime.tryParse(data['treatmentDate']?.toString() ?? '');
      if (date == null) return;
      records.add({
        'id': key.toString(),
        'method': data['treatmentMethod']?.toString() ?? '',
        'date': date,
        'notes': data['notes']?.toString() ?? '',
      });
    });
    records.sort((a, b) =>
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return records;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _markAsTreated() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a treatment method.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('recordTreatment').call({
        'farmId': widget.farmId,
        'palmId': widget.palmId,
        'treatmentMethod': _selectedMethod!,
        'treatmentDate':
            '${_selectedDate.year.toString().padLeft(4, '0')}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        'notes': _notesController.text.trim(),
      });

      if (!mounted) return;
      if (result.data is Map && result.data['success'] != true) {
        throw Exception('Treatment could not be saved.');
      }
      setState(() {
        _selectedDate = DateTime.now();
        _selectedMethod = null;
        _notesController.clear();
      });
      widget.onMarkedTreated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Treatment record added successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message ?? 'Unable to save treatment.';

      debugPrint('Treatment Error Code: ${e.code}');
      debugPrint('Treatment Error Message: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save treatment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treatment Record'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20, 12, 20, 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassLabel(child: Text(
                'Treatment  •  ${widget.palmId}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              )),
              const SizedBox(height: 20),

              // Treatment form
              StreamBuilder<DatabaseEvent>(
                stream: _palmStream,
                builder: (context, palmSnapshot) {
                  final palmData = palmSnapshot.data?.snapshot.value;
                  final healthStatus = palmData is Map
                      ? palmData['healthStatus']?.toString().trim()
                      : null;
                  final canTreat = !palmSnapshot.hasError &&
                      healthStatus == 'Suspected';

                  return AbsorbPointer(
                    absorbing: !canTreat || _isSaving,
                    child: GlassCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark as Treated',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record treatment after inspecting the palm.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      const SizedBox(height: 24),

                      // Treatment date
                      Text(
                        'Treatment Date',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius:
                        BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.calendar_month_rounded,
                            ),
                            suffixIcon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                          child: Text(
                            _formatDate(_selectedDate),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Treatment method
                      Text(
                        'Treatment Method',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedMethod,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Select method',
                          prefixIcon: Icon(
                            Icons.science_outlined,
                          ),
                        ),
                        items: _treatmentMethods.map((method) {
                          return DropdownMenuItem<String>(
                            value: method,
                            child: Text(
                              method,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMethod = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Optional notes
                      Text(
                        'Notes (optional)',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Add any notes...',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit treatment
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isSaving || !canTreat)
                              ? null
                              : _markAsTreated,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                          ),
                          label: const Text('Mark as Treated'),
                        ),
                      ),
                    ],
                  ),
                ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Treatment history heading
              GlassLabel(child: Text(
                'Treatment History',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              )),
              const SizedBox(height: 12),

              // Empty state or previous treatments
              StreamBuilder<DatabaseEvent>(
                stream: _treatmentsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return GlassCard(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Unable to load treatment records: ${snapshot.error}'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = _readRecords(snapshot.data!.snapshot.value);
                  return Column(
                    children: [
                    if (records.isEmpty)
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 36,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 48,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No treatment records yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The treatment records will appear here '
                                  'after marking the palm as treated.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.6),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                    else
                      ...records.map((record) {
                    final method = record['method'] as String;
                    final date = record['date'] as DateTime;
                    final notes = record['notes'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: notes.isEmpty ? 64 : 84,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDate(date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      method,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        notes,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(height: 1.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
