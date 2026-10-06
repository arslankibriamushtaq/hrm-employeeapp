import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text('Public holidays $_year')),
      body: AsyncBody<List<Holiday>>(
        future: _future,
        onRetry: () => setState(() { _future = _load(); }),
        builder: (context, holidays) => holidays.isEmpty
            ? const Center(child: EmptyView(icon: Icons.event_busy, message: 'No holidays announced yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: holidays.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final h = holidays[i];
                  final past = h.date.isBefore(today);
                  return Opacity(
                    opacity: past ? 0.55 : 1,
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.celebration_outlined),
                        title: Text(h.name),
                        subtitle: Text(fmtShortDate(h.date)),
                        trailing: past ? const Text('Passed') : null,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
