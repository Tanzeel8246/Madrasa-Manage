import 'package:flutter/material.dart';
import '../utils/sync_service.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';

class AccIncomeStatementPage extends StatefulWidget {
  const AccIncomeStatementPage({super.key});

  @override
  State<AccIncomeStatementPage> createState() => _AccIncomeStatementPageState();
}

class _AccIncomeStatementPageState extends State<AccIncomeStatementPage> {
  late DateTime _from;
  late DateTime _to;
  double _revenue = 0;
  double _expense = 0;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final all = await DBHelper().getFinance(userRole: 'admin');
    final fromText = _date(_from);
    final toText = _date(_to);
    var revenue = 0.0;
    var expense = 0.0;
    final rows = <Map<String, dynamic>>[];

    for (final row in all) {
      if ((row['is_deleted'] ?? 0) == 1) continue;
      final date = row['date']?.toString() ?? '';
      if (date.isNotEmpty && (date.compareTo(fromText) < 0 || date.compareTo(toText) > 0)) {
        continue;
      }
      final type = row['type']?.toString().toLowerCase() ?? '';
      final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      if (type == 'income' || type == 'receipt') {
        revenue += amount;
      } else {
        expense += amount;
      }
      rows.add(row);
    }

    if (!mounted) return;
    setState(() {
      _revenue = revenue;
      _expense = expense;
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = isUrduGlobal.value;
    final net = _revenue - _expense;
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
        title: Text(isUrdu ? 'گوشوارہ آمدن و اخراجات' : 'Income Statement'),
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
                    leading: const Icon(Icons.date_range),
                    title: Text(isUrdu ? 'مدت' : 'Period'),
                    subtitle: Text('${_date(_from)} - ${_date(_to)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _pickRange,
                    ),
                  ),
                ),
                _summaryTile(isUrdu ? 'آمدن' : 'Revenue', _revenue, Colors.green),
                _summaryTile(isUrdu ? 'اخراجات' : 'Expenses', _expense, Colors.red),
                _summaryTile(
                  net >= 0
                      ? (isUrdu ? 'خالص بچت' : 'Net Surplus')
                      : (isUrdu ? 'خالص نقصان' : 'Net Deficit'),
                  net.abs(),
                  net >= 0 ? Colors.blue : Colors.red,
                ),
                const SizedBox(height: 8),
                Text(
                  isUrdu ? 'مدت کی تفصیل' : 'Period Entries',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ..._rows.map((row) => Card(
                      child: ListTile(
                        title: Text(
                            (row['title'] ?? row['description'] ?? 'Entry').toString()),
                        subtitle: Text(row['date']?.toString() ?? ''),
                        trailing: Text('Rs ${row['amount'] ?? 0}'),
                      ),
                    )),
              ],
            ),
    );
  }

  Widget _summaryTile(String title, double amount, Color color) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          'Rs ${amount.toStringAsFixed(0)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
