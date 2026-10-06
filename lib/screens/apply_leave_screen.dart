import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// POST /leave-requests. Pops `true` when a request was created.
///
/// Leave types come from the employee's own quotas: /leave-types is back-office only,
/// so /leave-quotas/me is the list of types an employee can see.
class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late Future<List<LeaveQuota>> _quotas;
  LeaveQuota? _type;
  DateTimeRange? _range;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _quotas = AppScope.read(context).api.myQuotas(DateTime.now().year);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Select leave dates',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final range = _range!;
    setState(() => _busy = true);
    try {
      final created = await AppScope.read(context).api.applyLeave(
            leaveTypeId: _type!.leaveTypeId,
            startDate: range.start,
            endDate: range.end,
            reason: _reason.text,
          );
      if (!mounted) return;
      final days = created.totalDays;
      showSnack(context,
          'Leave request submitted${days == null ? '' : ' for $days working day${days == 1 ? '' : 's'}'}.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateRange() {
    final r = _range;
    if (r == null) return 'Select the leave dates';
    if (r.start.year != r.end.year) {
      return 'Leave cannot span two calendar years - submit one request per year';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for leave')),
      body: AsyncBody<List<LeaveQuota>>(
        future: _quotas,
        onRetry: () => setState(() { _quotas = AppScope.read(context).api.myQuotas(DateTime.now().year); }),
        builder: (context, quotas) {
          if (quotas.isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.info_outline,
                message: 'No leave types are assigned to you yet.\nPlease contact HR.',
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<LeaveQuota>(
                    value: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final q in quotas)
                        DropdownMenuItem(
                          value: q,
                          child: Text('${q.leaveTypeName}  (${q.remainingQuota} left)'),
                        ),
                    ],
                    onChanged: (q) => setState(() => _type = q),
                    validator: (q) => q == null ? 'Select a leave type' : null,
                  ),
                  const SizedBox(height: 16),
                  FormField<DateTimeRange>(
                    validator: (_) => _validateRange(),
                    builder: (field) => InkWell(
                      onTap: () async {
                        await _pickDates();
                        field.didChange(_range);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Dates',
                          prefixIcon: const Icon(Icons.date_range),
                          errorText: field.errorText,
                        ),
                        child: Text(
                          _range == null ? 'Tap to select' : fmtDateRange(_range!.start, _range!.end),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Text('Weekends and public holidays are not counted.',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_type != null && _type!.remainingQuota <= 0)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const ListTile(
                        leading: Icon(Icons.warning_amber),
                        title: Text('You have no balance left for this leave type'),
                        subtitle: Text('The request may be rejected automatically on approval.'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.send),
                    label: const Text('Submit request'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
