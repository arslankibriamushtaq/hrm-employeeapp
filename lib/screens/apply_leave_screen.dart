import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../theme/tokens.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for leave')),
      body: AsyncBody<List<LeaveQuota>>(
        future: _quotas,
        onRetry: () => setState(() { _quotas = AppScope.read(context).api.myQuotas(DateTime.now().year); }),
        skeleton: const LoadingSkeleton(
          children: [
            SkeletonBox(width: 100, height: 18),
            SkeletonBox(height: 56),
            SkeletonBox(width: 80, height: 18),
            SkeletonBox(height: 56),
            SkeletonBox(width: 120, height: 18),
            SkeletonBox(height: 120),
          ],
        ),
        builder: (context, quotas) {
          if (quotas.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.info_outline,
                message: 'No leave types are assigned to you yet.\nPlease contact HR.',
              ),
            );
          }
          final type = _type;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('Leave type'),
                  DropdownButtonFormField<LeaveQuota>(
                    value: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Select a leave type',
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
                  if (type != null) ...[
                    const SizedBox(height: Space.md),
                    _BalanceCard(quota: type),
                  ],
                  const SectionHeader('Dates'),
                  FormField<DateTimeRange>(
                    validator: (_) => _validateRange(),
                    builder: (field) => InkWell(
                      onTap: () async {
                        await _pickDates();
                        field.didChange(_range);
                      },
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.date_range),
                          suffixIcon: const Icon(Icons.edit_calendar_outlined),
                          errorText: field.errorText,
                        ),
                        child: Text(
                          _range == null ? 'Tap to select' : fmtDateRange(_range!.start, _range!.end),
                          style: _range == null
                              ? TextStyle(color: scheme.onSurfaceVariant)
                              : const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: Space.xs + 2),
                        Expanded(
                          child: Text('Weekends and public holidays are not counted.',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Reason (optional)'),
                  TextFormField(
                    controller: _reason,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(alignLabelWithHint: true),
                  ),
                  const SizedBox(height: Space.lg),
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

/// The chosen leave type's balance, plus the existing warning when nothing is left.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.quota});

  final LeaveQuota quota;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = quota.remainingQuota <= 0;
    final ratio = quota.totalQuota == 0 ? 0.0 : quota.remainingQuota / quota.totalQuota;
    return AppCard(
      color: empty ? scheme.errorContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(empty ? Icons.warning_amber : Icons.account_balance_wallet_outlined,
                  color: empty ? scheme.error : null, size: 36),
              const SizedBox(width: Space.md),
              Expanded(
                child: empty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You have no balance left for this leave type',
                              style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onErrorContainer)),
                          const SizedBox(height: 2),
                          Text('The request may be rejected automatically on approval.',
                              style: TextStyle(color: scheme.onErrorContainer)),
                        ],
                      )
                    : Text('${quota.remainingQuota} of ${quota.totalQuota} days left',
                        style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          if (!empty) ...[
            const SizedBox(height: Space.md),
            LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), borderRadius: BorderRadius.circular(4)),
          ],
        ],
      ),
    );
  }
}
