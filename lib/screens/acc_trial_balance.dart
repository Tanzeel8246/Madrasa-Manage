import 'package:flutter/material.dart';
import '../utils/sync_service.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';

class AccTrialBalancePage extends StatefulWidget {
  const AccTrialBalancePage({super.key});

  @override
  State<AccTrialBalancePage> createState() => _AccTrialBalancePageState();
}

class _AccTrialBalancePageState extends State<AccTrialBalancePage> {
  DateTime _asOf = DateTime.now();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final all = await DBHelper().getFinance(userRole: 'admin');
    final asOfText = _date(_asOf);
    final grouped = <String, Map<String, dynamic>>{};

    for (final row in all) {
      if ((row['is_deleted'] ?? 0) == 1) continue;
      final date = row['date']?.toString() ?? '';
      if (date.isNotEmpty && date.compareTo(asOfText) > 0) continue;

      final head = (row['title'] ?? row['head_name'] ?? row['description'] ?? 'General')
          .toString();
      final type = row['type']?.toString().toLowerCase() ?? '';
      final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      grouped.putIfAbsent(head, () => {'name': head, 'debit': 0.0, 'credit': 0.0});
      if (type == 'income' || type == 'receipt') {
        grouped[head]!['credit'] = (grouped[head]!['credit'] as double) + amount;
      } else {
        grouped[head]!['debit'] = (grouped[head]!['debit'] as double) + amount;
      }
    }

    if (!mounted) return;
    setState(() {
      _rows = grouped.values.toList()
        ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _asOf = picked;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = isUrduGlobal.value;
    final totalDebit = _rows.fold<double>(
        0, (sum, row) => sum + ((row['debit'] as double?) ?? 0));
    final totalCredit = _rows.fold<double>(
        0, (sum, row) => sum + ((row['credit'] as double?) ?? 0));

    return Scaffold(
      appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing data...')));
                try {
                  await SyncService.runTwoWaySync();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync complete')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: ')));
                }
              },
            )
          ],
        title: Text(isUrdu ? 'میزان' : 'Trial Balance'),
        backgroundColor: const Color(0xFF284D3D),
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(isUrdu ? 'کس تاریخ تک' : 'As of Date'),
                    subtitle: Text(_date(_asOf)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _pickDate,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: Text(isUrdu ? 'کل ڈیبٹ' : 'Total Debit'),
                    trailing: Text('Rs ${totalDebit.toStringAsFixed(0)}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: Text(isUrdu ? 'کل کریڈٹ' : 'Total Credit'),
                    trailing: Text('Rs ${totalCredit.toStringAsFixed(0)}'),
                  ),
                ),
                const SizedBox(height: 8),
                ..._rows.map((row) => Card(
                      child: ListTile(
                        title: Text(row['name'].toString()),
                        subtitle: Text(
                            'Dr: ${((row['debit'] as double?) ?? 0).toStringAsFixed(0)} | Cr: ${((row['credit'] as double?) ?? 0).toStringAsFixed(0)}'),
                      ),
                    )),
              ],
            ),
    );
  }
}
