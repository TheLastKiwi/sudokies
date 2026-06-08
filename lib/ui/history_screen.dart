import 'package:flutter/material.dart';

import '../app.dart';
import '../data/history_record.dart';
import '../engine/step.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _fmtTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final records = AppScope.of(context).history.records;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: records.isEmpty
          ? const Center(child: Text('No puzzles attempted yet.'))
          : ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final HistoryRecord r = records[i];
                final done = r.isCompleted;
                return ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.timelapse,
                    color: done
                        ? Colors.green
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text('${r.difficulty.label}  ·  ${r.code}'),
                  subtitle: Text(done
                      ? 'Solved in ${_fmtTime(r.elapsedSeconds)} · ${r.hintsUsed} hint(s)'
                      : 'In progress · started ${_fmtDate(r.startedAt)}'),
                );
              },
            ),
    );
  }
}
