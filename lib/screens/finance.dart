import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import 'simple_finance.dart';
import 'acc_invoices.dart';
import 'acc_payroll.dart';
import 'acc_chart.dart';
import 'acc_income_statement.dart';
import 'acc_trial_balance.dart';
import 'acc_vouchers.dart';
import 'acc_ledger.dart';
import 'departments.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  double totalRevenue = 0;
  double totalExpenses = 0;
  double netIncome = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DBHelper();
    await db.ensureSimpleFinanceAccountingBackfill();
    final records = await db.getFinance(
        userRole: 'admin'); // Assuming admin can see all for ERP dashboard

    double inc = 0;
    double exp = 0;

    for (var r in records) {
      if (r['is_deleted'] == 1) continue;
      final type = r['type']?.toString().toLowerCase() ?? '';
      final amount = double.tryParse(r['amount']?.toString() ?? '0') ?? 0;
      if (type == 'income') {
        inc += amount;
      } else if (type == 'expense') {
        exp += amount;
      }
    }

    setState(() {
      totalRevenue = inc;
      totalExpenses = exp;
      netIncome = inc - exp;
    });
  }

  Widget _buildCard(String title, String amount, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Rs $amount",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(String title, IconData icon, Widget page) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: primaryGreen),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing data...')));
              // Call your sync logic here
              // ApiSync.syncData();
            },
          )
        ],
        title: Text(isUrduGlobal.value
            ? 'ای آر پی اکاؤنٹس ڈیش بورڈ'
            : 'ERP Accounts Dashboard'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCard(
                      isUrduGlobal.value ? 'کل آمدن' : 'Total Revenue',
                      totalRevenue.toStringAsFixed(0),
                      Icons.arrow_downward,
                      Colors.green),
                  _buildCard(
                      isUrduGlobal.value ? 'کل اخراجات' : 'Total Expenses',
                      totalExpenses.toStringAsFixed(0),
                      Icons.arrow_upward,
                      Colors.red),
                  _buildCard(
                      isUrduGlobal.value ? 'خالص منافع' : 'Net Income',
                      netIncome.toStringAsFixed(0),
                      Icons.account_balance_wallet,
                      Colors.blue),
                  _buildCard(
                      isUrduGlobal.value
                          ? 'نقد اور بینک بیلنس'
                          : 'Cash & Bank Balances',
                      netIncome.toStringAsFixed(0),
                      Icons.account_balance,
                      Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(isUrduGlobal.value ? 'اکاؤنٹس مینیو' : 'Accounts Menu',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuTile(
                      isUrduGlobal.value
                          ? 'چارٹ آف اکاؤنٹس'
                          : 'Chart of Accounts',
                      Icons.account_tree,
                      const AccChartPage()),
                  _buildMenuTile(isUrduGlobal.value ? 'واؤچرز' : 'Vouchers',
                      Icons.receipt_long, const AccVouchersPage()),
                  _buildMenuTile(
                      isUrduGlobal.value ? 'جنرل لیجر' : 'General Ledger',
                      Icons.menu_book,
                      const AccLedgerPage()),
                  _buildMenuTile(
                      isUrduGlobal.value ? 'شعبہ جات' : 'Departments',
                      Icons.business,
                      const DepartmentsPage()),
                  _buildMenuTile(isUrduGlobal.value ? 'میزان' : 'Trial Balance',
                      Icons.balance, const AccTrialBalancePage()),
                  _buildMenuTile(
                      isUrduGlobal.value
                          ? 'گوشوارہ آمدن و اخراجات'
                          : 'Income Statement',
                      Icons.pie_chart,
                      const AccIncomeStatementPage()),
                  _buildMenuTile(
                      isUrduGlobal.value
                          ? 'آمدن و خرچ'
                          : 'Simple Income & Expense',
                      Icons.account_balance_wallet,
                      const SimpleFinancePage()),
                  _buildMenuTile(
                      isUrduGlobal.value ? 'فیس انوائسز' : 'Fee Invoices',
                      Icons.receipt,
                      const AccInvoicesPage()),
                  _buildMenuTile(isUrduGlobal.value ? 'پے رول' : 'Payroll',
                      Icons.people, const AccPayrollPage()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
