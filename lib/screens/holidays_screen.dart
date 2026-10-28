import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  late Future<List<Holiday>> _future;
  final int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Holiday>> _load() async {
    final all = await AppScope.read(context).api.holidays();
    return all.where((h) => h.date.year == _year).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Public holidays $_year')),
      body: AsyncBody<List<Holiday>>(
        future: _future,
        onRetry: () => setState(() { _future = _load(); }),
        skeleton: LoadingSkeleton.list(count: 6, itemHeight: 76),
        builder: (context, holidays) => holidays.isEmpty
            ? const Center(child: EmptyState(icon: Icons.event_busy, message: 'No holidays announced yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(Space.lg),
                itemCount: holidays.length,
                separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) {
                  final h = holidays[i];
                  final past = h.date.isBefore(today);
                  // Past days are muted with colour, not an Opacity layer.
                  final fg = past ? scheme.onSurfaceVariant : null;
                  return AppCard(
                    padding: const EdgeInsets.all(Space.md + 2),
                    child: Row(
                      children: [
                        DateBadge(date: h.date, caption: fmtMonthShort(h.date), muted: past),
                        const SizedBox(width: Space.md + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg)),
                              const SizedBox(height: 2),
                              Text(fmtShortDate(h.date), style: TextStyle(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (past) ...[
                          const SizedBox(width: Space.sm),
                          const StatusChip(null, label: 'Passed'),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
