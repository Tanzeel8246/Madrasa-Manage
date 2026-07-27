// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';

import '../db_helper.dart';

class AccChartPage extends StatefulWidget {
  const AccChartPage({super.key});

  @override
  State<AccChartPage> createState() => _AccChartPageState();
}

class _AccChartPageState extends State<AccChartPage> {
  final Color primary = const Color(0xFF284D3D);
  List<Map<String, dynamic>> _accounts = [];
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
      isLoading = false;
    });
  }

  Future<void> _showAccountDialog({Map<String, dynamic>? account}) async {
    final codeController =
        TextEditingController(text: account?['code']?.toString() ?? '');
    final nameController =
        TextEditingController(text: account?['name']?.toString() ?? '');
    String type = account?['type']?.toString() ?? 'Asset';
    int? parentId = account?['parent_id'] != null
        ? int.tryParse(account!['parent_id'].toString())
        : null;

    final availableParents = _accounts
        .where((a) => account == null || a['id'] != account['id'])
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(account == null ? 'نیا اکاؤنٹ' : 'اکاؤنٹ ایڈٹ کریں'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'کوڈ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اکاؤنٹ کا نام',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'قسم',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Asset', child: Text('Asset')),
                  DropdownMenuItem(
                      value: 'Liability', child: Text('Liability')),
                  DropdownMenuItem(value: 'Equity', child: Text('Equity')),
                  DropdownMenuItem(value: 'Revenue', child: Text('Revenue')),
                  DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'Asset'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: parentId,
                decoration: const InputDecoration(
                  labelText: 'پیرنٹ اکاؤنٹ (Parent Account - Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('-- کوئی نہیں (None) --'),
                  ),
                  ...availableParents.map(
                    (a) => DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(
                        '${a['code'] ?? ''} - ${a['name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                ],
                onChanged: (v) => setDialogState(() => parentId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final code = codeController.text.trim();
                final name = nameController.text.trim();
                if (code.isEmpty || name.isEmpty) return;
                final payload = {
                  'code': code,
                  'name': name,
                  'type': type,
                  'parent_id': parentId,
                };
                var syncFailed = false;
                if (account == null) {
                  await DBHelper().insertAccChartAccount(payload);
                } else {
                  await DBHelper()
                      .updateAccChartAccount(account['id'] as int, payload);
                }
                try {
                  await SyncService.runTwoWaySync();
                } catch (e) {
                  syncFailed = true;
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAccounts();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(syncFailed
                        ? 'اکاؤنٹ محفوظ ہو گیا، مگر سنک نہیں ہو سکا۔'
                        : 'اکاؤنٹ محفوظ اور سنک ہو گیا۔'),
                  ));
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('محفوظ کریں'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(int id) async {
    await DBHelper().deleteAccChartAccount(id);
    try {
      await SyncService.runTwoWaySync();
    } catch (_) {}
    _loadAccounts();
  }

  Color _typeColor(String type) {
    return switch (type) {
      'Asset' => Colors.green,
      'Liability' => Colors.red,
      'Equity' => Colors.blueGrey,
      'Revenue' => Colors.blue,
      'Expense' => Colors.orange,
      _ => primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing data...')));
              try {
                await SyncService.runTwoWaySync();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync complete')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                }
              }
            },
          )
        ],
        title: const Text('اکاؤنٹس کا چارٹ'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAccountDialog(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(child: Text('ابھی تک کوئی اکاؤنٹ موجود نہیں'))
              : ListView.builder(
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final type = account['type']?.toString() ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _typeColor(type).withOpacity(0.12),
                          child:
                              Icon(Icons.account_tree, color: _typeColor(type)),
                        ),
                        title: Text(
                          account['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${account['code'] ?? ''} • ${type.isEmpty ? '-' : type}${account['parent_name'] != null ? '\nپیرنٹ: ${account['parent_code']} - ${account['parent_name']}' : ''}",
                        ),
                        isThreeLine: account['parent_name'] != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showAccountDialog(account: account),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteAccount(account['id'] as int),
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
