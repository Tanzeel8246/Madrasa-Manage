// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import 'dashboard.dart';

class ReportsFinancePage extends StatefulWidget {
  const ReportsFinancePage({super.key});

  @override
  _ReportsFinancePageState createState() => _ReportsFinancePageState();
}

class _ReportsFinancePageState extends State<ReportsFinancePage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF1E3A2F);

  List<Map<String, dynamic>> _financeRecords = [];
  Map<int, Map<String, dynamic>> _userGroups = {}; // For Admin grouped view
  Set<int> _expandedUsers = {}; // Track expanded user accordions

  bool isLoading = true;
  String? fromDate;
  String? toDate;

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  double totalIncome = 0;
  double totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    setState(() => isLoading = true);
    // ایڈمن سب یوزرز کا ڈیٹا، نان ایڈمن صرف اپنا
    final allFinance = await DBHelper().getFinance(
      userId: currentUserId.value,
      userRole: currentUserRole.value,
    );

    List<Map<String, dynamic>> filtered = [];
    Map<int, Map<String, dynamic>> grouped = {};
    totalIncome = 0;
    totalExpense = 0;

    for (var f in allFinance) {
      if (fromDate != null && toDate != null) {
        try {
          DateTime fDate =
              intl.DateFormat('d/M/yyyy').parse(f['date'].toString());
          DateTime sDate = intl.DateFormat('d/M/yyyy').parse(fromDate!);
          DateTime eDate = intl.DateFormat('d/M/yyyy').parse(toDate!);
          if (fDate.isBefore(sDate) || fDate.isAfter(eDate)) continue;
        } catch (e) {
          try {
            DateTime fDate = DateTime.parse(f['date'].toString());
            DateTime sDate = intl.DateFormat('d/M/yyyy').parse(fromDate!);
            DateTime eDate = intl.DateFormat('d/M/yyyy').parse(toDate!);
            if (fDate.isBefore(sDate) || fDate.isAfter(eDate)) continue;
          } catch (_) {
            continue;
          }
        }
      }
      filtered.add(f);
      double amt = f['amount'] is double
          ? f['amount']
          : double.tryParse(f['amount'].toString()) ?? 0.0;
      String typeLower = f['type']?.toString().toLowerCase() ?? '';

      if (typeLower == 'income') totalIncome += amt;
      if (typeLower == 'expense') totalExpense += amt;

      if (currentUserRole.value == 'admin' ||
          currentUserRole.value == 'nazim') {
        int uid = (f['user_id'] as int?) ?? 0;
        String uname = (f['user_name'] as String?) ?? 'نامعلوم';
        if (!grouped.containsKey(uid)) {
          grouped[uid] = {
            'name': uname,
            'income': <Map<String, dynamic>>[],
            'expense': <Map<String, dynamic>>[]
          };
        }
        if (typeLower == 'income') {
          (grouped[uid]!['income'] as List).add(f);
        } else {
          (grouped[uid]!['expense'] as List).add(f);
        }
      }
    }

    setState(() {
      _financeRecords = filtered;
      _userGroups = grouped;
      if (_expandedUsers.isEmpty && grouped.isNotEmpty) {
        _expandedUsers = {grouped.keys.first};
      }
      isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      String formatted = "${picked.day}/${picked.month}/${picked.year}";
      setState(() {
        if (isFrom) {
          fromDate = formatted;
          _fromDateController.text = formatted;
        } else {
          toDate = formatted;
          _toDateController.text = formatted;
        }
      });
      _loadFinance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => const DashboardPage()));
      },
      child: Scaffold(
        backgroundColor: bgColor,
        drawer: const AppDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(isUrduGlobal.value
              ? "مالیاتی تفصیلی رپورٹ"
              : "Detailed Finance Report"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isUrduGlobal.value
                        ? "ڈیٹا سنک ہو رہا ہے..."
                        : "Syncing data...")));
                try {
                  await SyncService.runTwoWaySync();
                  if (mounted) {
                    _loadFinance();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value
                            ? "سنک مکمل ہو گیا!"
                            : "Sync complete!"),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value
                            ? "سنک میں خرابی آئی"
                            : "Sync failed"),
                        backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter Section
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                          labelText: isUrduGlobal.value
                              ? "ابتدائی تاریخ"
                              : "From Date",
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0)),
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _toDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                          labelText:
                              isUrduGlobal.value ? "آخری تاریخ" : "To Date",
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0)),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        fromDate = null;
                        toDate = null;
                        _fromDateController.clear();
                        _toDateController.clear();
                      });
                      _loadFinance();
                    },
                  )
                ],
              ),
            ),

            // Summary Dashboard
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Text(
                                isUrduGlobal.value ? "کل آمدن" : "Total Income",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800)),
                            const SizedBox(height: 5),
                            Text("Rs. ${totalIncome.toStringAsFixed(0)}",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Text(
                                isUrduGlobal.value ? "کل خرچ" : "Total Expense",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800)),
                            const SizedBox(height: 5),
                            Text("Rs. ${totalExpense.toStringAsFixed(0)}",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),

            // List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _financeRecords.isEmpty
                      ? Center(
                          child: Text(isUrduGlobal.value
                              ? "کوئی ریکارڈ نہیں ملا"
                              : "No records found"))
                      : (currentUserRole.value == 'admin' ||
                              currentUserRole.value == 'nazim')
                          ? _buildAdminGroupedList()
                          : _buildFlatList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList() {
    return ListView.builder(
      itemCount: _financeRecords.length,
      itemBuilder: (context, index) {
        final f = _financeRecords[index];
        bool isInc = (f['type']?.toString().toLowerCase() == 'income');
        return _transactionCard(f, isInc);
      },
    );
  }

  Widget _buildAdminGroupedList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      children: _userGroups.entries.map((entry) {
        final uid = entry.key;
        final ug = entry.value;
        final uname = ug['name'] as String;
        final incomeList = (ug['income'] as List).cast<Map<String, dynamic>>();
        final expenseList =
            (ug['expense'] as List).cast<Map<String, dynamic>>();

        double uInc = incomeList.fold(
            0, (s, r) => s + (double.tryParse(r['amount'].toString()) ?? 0));
        double uExp = expenseList.fold(
            0, (s, r) => s + (double.tryParse(r['amount'].toString()) ?? 0));
        double uBal = uInc - uExp;
        final isExpanded = _expandedUsers.contains(uid);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedUsers.remove(uid);
                    } else {
                      _expandedUsers.add(uid);
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: primaryGreen,
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          uname,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                      _adminBadge(isUrduGlobal.value ? 'آمدن' : 'In', uInc,
                          Colors.greenAccent.shade700),
                      const SizedBox(width: 6),
                      _adminBadge(isUrduGlobal.value ? 'خرچ' : 'Exp', uExp,
                          Colors.redAccent),
                      const SizedBox(width: 6),
                      _adminBadge(
                          isUrduGlobal.value ? 'بیلنس' : 'Bal',
                          uBal,
                          uBal >= 0
                              ? Colors.lightBlueAccent
                              : Colors.orangeAccent),
                      const SizedBox(width: 6),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                if (incomeList.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.green.shade50,
                    child: Text(isUrduGlobal.value ? 'آمدن' : 'Income',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800)),
                  ),
                  ...incomeList.map((r) => _transactionCard(r, true)),
                ],
                if (expenseList.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.shade50,
                    child: Text(isUrduGlobal.value ? 'خرچ' : 'Expense',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800)),
                  ),
                  ...expenseList.map((r) => _transactionCard(r, false)),
                ],
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _adminBadge(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          Text(amount.toStringAsFixed(0),
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _compactFinanceText(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _valueAfterLabel(String text, List<String> labels) {
    for (final label in labels) {
      final index = text.indexOf(label);
      if (index == -1) continue;
      var value = text.substring(index + label.length).trim();
      if (value.startsWith(':') || value.startsWith('：')) {
        value = value.substring(1).trim();
      }
      final slashIndex = value.indexOf('/');
      if (slashIndex != -1) value = value.substring(0, slashIndex).trim();
      return value;
    }
    return '';
  }

  String _incomeName(Map<String, dynamic> f) {
    final donorName = _compactFinanceText(f['donor_name']);
    if (donorName.isNotEmpty) return donorName;
    final description = _compactFinanceText(f['description']);
    return _valueAfterLabel(description, const ['نام', 'Name']);
  }

  String _incomeHead(Map<String, dynamic> f) {
    final description = _compactFinanceText(f['description']);
    final head = _valueAfterLabel(description, const ['مد', 'Head']);
    if (head.isNotEmpty) return head;
    final slashIndex = description.indexOf('/');
    return slashIndex == -1
        ? description
        : description.substring(0, slashIndex).trim();
  }

  Widget _transactionCard(Map<String, dynamic> f, bool isInc) {
    final amountText = "Rs. ${f['amount']}";
    final dateText = _compactFinanceText(f['date']);
    final descriptionText = _compactFinanceText(f['description']);
    final receiverText = _compactFinanceText(f['user_name']);
    final incomeName = _incomeName(f);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInc ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isInc ? Icons.arrow_downward : Icons.arrow_upward,
            color: isInc ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        title: isInc
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incomeName.isEmpty ? '-' : incomeName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amountText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              )
            : Text(amountText,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateText,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 2),
            if (isInc) ...[
              Text(_incomeHead(f), style: const TextStyle(fontSize: 13)),
              if (receiverText.isNotEmpty)
                Text(receiverText, style: const TextStyle(fontSize: 13)),
            ] else
              Text(descriptionText, style: const TextStyle(fontSize: 13)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
