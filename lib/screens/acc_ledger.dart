import 'package:flutter/material.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';
import 'package:intl/intl.dart';

import '../db_helper.dart';

class AccLedgerPage extends StatefulWidget {
  const AccLedgerPage({super.key});

  @override
  State<AccLedgerPage> createState() => _AccLedgerPageState();
}

class _AccLedgerPageState extends State<AccLedgerPage> {
  final Color primary = const Color(0xFF284D3D);
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _accounts = [];
  int? _accountId;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _ledger;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await DBHelper().getAccChartAccounts();
    setState(() {
      _accounts = accounts;
      _accountId = accounts.isNotEmpty ? accounts.first['id'] as int? : null;
      isLoading = false;
    });
    if (_accountId != null) await _loadLedger();
  }

  Future<void> _loadLedger() async {
    if (_accountId == null) return;
    setState(() => isLoading = true);
    final ledger = await DBHelper().getGeneralLedger(
      accountId: _accountId!,
      fromDate: _fmt.format(_from),
      toDate: _fmt.format(_to),
    );
    setState(() {
      _ledger = ledger;
      isLoading = false;
    });
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
    await _loadLedger();
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    return amount.abs().toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        (_ledger?['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final account = _ledger?['account'] as Map<String, dynamic>?;

    return Scaffold(
      drawer: const AppDrawer(),
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
        title: const Text('جنرل لیجر'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _filters(),
          if (account != null) _accountHeader(account),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _accounts.isEmpty
                    ? const Center(
                        child:
                            Text('پہلے اکاؤنٹس کا چارٹ میں اکاؤنٹس شامل کریں۔'),
                      )
                    : entries.isEmpty
                        ? _emptyLedger()
                        : _entriesList(entries),
          ),
          if (_ledger != null) _totalsFooter(),
        ],
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _accountId,
            decoration: const InputDecoration(
              labelText: 'اکاؤنٹ منتخب کریں',
              border: OutlineInputBorder(),
            ),
            items: _accounts
                .map(
                  (a) => DropdownMenuItem<int>(
                    value: a['id'] as int,
                    child: Text('${a['code'] ?? ''} - ${a['name'] ?? ''}'),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              setState(() => _accountId = v);
              await _loadLedger();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.today),
                  label: Text('سے: ${_fmt.format(_from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event),
                  label: Text('تک: ${_fmt.format(_to)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountHeader(Map<String, dynamic> account) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${account['code'] ?? ''} - ${account['name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text('قسم: ${account['type'] ?? '-'}'),
          Text(
            'Opening: ${_money(_ledger?['opening_balance'])} ${_ledger?['opening_side'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _emptyLedger() {
    return Center(
      child: Text(
        _ledger == null
            ? 'اکاؤنٹ منتخب کریں'
            : 'اس مدت میں کوئی ledger entry موجود نہیں۔',
      ),
    );
  }

  Widget _entriesList(List<Map<String, dynamic>> entries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        final debit = double.tryParse(e['debit']?.toString() ?? '0') ?? 0;
        final credit = double.tryParse(e['credit']?.toString() ?? '0') ?? 0;
        return Card(
          child: ListTile(
            title: Text(
              '${e['date'] ?? ''} • ${e['voucher_no'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${e['voucher_type'] ?? ''}\n${e['voucher_description'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  debit > 0
                      ? 'Dr ${debit.toStringAsFixed(2)}'
                      : 'Cr ${credit.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: debit > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Bal ${_money(e['running_balance'])} ${e['balance_side'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _totalsFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: primary.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                _footerMetric('Debit', _ledger?['total_debit'], Colors.green),
          ),
          Expanded(
            child:
                _footerMetric('Credit', _ledger?['total_credit'], Colors.red),
          ),
          Expanded(
            child: _footerMetric(
              'Closing',
              _ledger?['closing_balance'],
              primary,
              side: _ledger?['closing_side']?.toString() ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerMetric(String label, dynamic value, Color color,
      {String side = ''}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(
          '${_money(value)} $side',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
