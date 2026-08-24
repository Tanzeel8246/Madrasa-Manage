// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import '../utils/urdu_number_words.dart';
import 'dashboard.dart';

class SimpleFinancePage extends StatefulWidget {
  const SimpleFinancePage({super.key});

  @override
  State<SimpleFinancePage> createState() => _SimpleFinancePageState();
}

class _SimpleFinancePageState extends State<SimpleFinancePage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  File? _signatureImage;
  bool isIncome = true;
  int? _editingId;

  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _donorController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();

  String? selectedHead;
  List<Map<String, dynamic>> _financeRecords = [];
  // ایڈمن کے لیے یوزر وائز گروپ
  Map<int, Map<String, dynamic>> _userGroups = {};
  Set<int> _expandedUsers = {};

  List<String> incomeHeadsUr = [
    'صدقہ',
    'عطیہ',
    'فطرانہ',
    'چرم قربانی',
    'عشر',
    'فیس'
  ];
  List<String> expenseHeadsUr = [
    'راشن',
    'بل بجلی',
    'مرمت',
    'تعمیرات',
    'وطائف',
    'علاج معالجہ',
    'انٹرنیٹ بل',
    'انعامات',
    'مہمان نوازی',
    'موبائل پیکج'
  ];

  List<String> incomeHeadsEn = [
    'Sadaqah',
    'Donation',
    'Fitrana',
    'Qurbani Skin',
    'Ushr',
    'Fee'
  ];
  List<String> expenseHeadsEn = [
    'Ration',
    'Electricity Bill',
    'Maintenance',
    'Construction',
    'Stipends',
    'Medical',
    'Internet Bill',
    'Rewards',
    'Hospitality',
    'Mobile Package'
  ];

  List<String> get currentHeads => isUrduGlobal.value
      ? (isIncome ? incomeHeadsUr : expenseHeadsUr)
      : (isIncome ? incomeHeadsEn : expenseHeadsEn);

  Key _autocompleteKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(DateTime.now());
    _loadTransactions();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseFinanceDate(String value) {
    final trimmed = value.trim();
    final isoDate = DateTime.tryParse(trimmed);
    if (isoDate != null) return isoDate;
    final parts = trimmed.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  Future<void> _pickEntryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseFinanceDate(_dateController.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _dateController.text = _formatDate(picked);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _donorController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (currentUserRole.value == 'admin') {
      final grouped = await DBHelper().getFinanceGroupedByUser();
      // ایڈمن کے لیے فلیٹ لسٹ بھی بنائیں بالانس کارڈ کے لیے
      final allRecords = await DBHelper().getFinance(userRole: 'admin');
      if (!mounted) return;
      setState(() {
        _userGroups = grouped;
        _financeRecords = allRecords;
        if (_expandedUsers.isEmpty && grouped.isNotEmpty) {
          _expandedUsers = {grouped.keys.first};
        }
      });
    } else {
      final records = await DBHelper().getFinance(
        userId: currentUserId.value,
        userRole: currentUserRole.value,
      );
      if (!mounted) return;
      setState(() {
        _financeRecords = records;
      });
    }
  }

  String _buildDescription() {
    final headVal = selectedHead?.trim() ?? '';
    final donorVal = _donorController.text.trim();
    final addrVal = _addressController.text.trim();
    final descVal = _descController.text.trim();

    if (headVal.isEmpty && donorVal.isEmpty && addrVal.isEmpty) {
      return descVal;
    }

    final buffer = StringBuffer();
    if (headVal.isNotEmpty) {
      buffer.write('\u0645\u062f: $headVal');
    }
    if (isIncome) {
      if (donorVal.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' | ');
        buffer.write('\u0646\u0627\u0645: $donorVal');
      }
      if (addrVal.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' | ');
        buffer.write('\u067e\u062a\u06c1: $addrVal');
      }
    }
    if (descVal.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('\u062a\u0641\u0635\u06cc\u0644: $descVal');
    }
    return buffer.toString();
  }

  String _extractPart(String description, List<String> labels) {
    for (final raw in description.split('|')) {
      final part = raw.trim();
      for (final label in labels) {
        if (part.startsWith(label)) {
          return part.substring(label.length).trim();
        }
      }
    }
    return '';
  }

  void _populateForEdit(Map<String, dynamic> row) {
    final typeValue = (row['type'] ?? '').toString().toLowerCase();
    final description = (row['description'] ?? '').toString();
    final donorName = (row['donor_name'] ?? '').toString();
    final donorAddress = (row['donor_address'] ?? '').toString();

    setState(() {
      _editingId = row['id'] as int?;
      isIncome = typeValue == 'income';
      _amountController.text = (row['amount'] ?? '').toString();
      _dateController.text = (row['date'] ?? '').toString();

      String head = _extractPart(description, ['\u0645\u062f:', 'Ù…Ø¯:']);
      if (head.isEmpty && row['head_name'] != null && row['head_name'].toString().isNotEmpty) {
        head = row['head_name'].toString();
      }
      selectedHead = head.isNotEmpty ? head : null;

      String donor = _extractPart(description, ['\u0646\u0627\u0645:', 'Ù†Ø§Ù…:']);
      if (donor.isEmpty && donorName.isNotEmpty) {
        donor = donorName;
      }
      _donorController.text = donor;

      String addr = _extractPart(description, ['\u067e\u062a\u06c1:', 'Ù¾ØªÛ :']);
      if (addr.isEmpty && donorAddress.isNotEmpty) {
        addr = donorAddress;
      }
      _addressController.text = addr;

      String desc = _extractPart(description, ['\u062a\u0641\u0635\u06cc\u0644:', 'ØªÙ ØµÛŒÙ„:']);
      if (desc.isEmpty) {
        desc = description;
      }
      _descController.text = desc;
      _autocompleteKey = UniqueKey();
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> row) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isUrduGlobal.value
              ? '\u062a\u0627\u0626\u06cc\u062f'
              : 'Confirm'),
          content: Text(
            isUrduGlobal.value
                ? '\u06a9\u06cc\u0627 \u0622\u067e \u06cc\u06c1 \u0641\u0646\u0627\u0646\u0633 \u0627\u0646\u0679\u0631\u06cc \u0688\u06cc\u0644\u06cc\u0679 \u06a9\u0631\u0646\u0627 \u0686\u0627\u06c1\u062a\u06d2 \u06c1\u06cc\u06ba\u061f'
                : 'Do you want to delete this finance entry?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text(isUrduGlobal.value ? '\u0646\u06c1\u06cc\u06ba' : 'No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isUrduGlobal.value ? '\u06c1\u0627\u06ba' : 'Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await DBHelper().deleteFinance((row['id'] ?? 0) as int);
    if (_editingId == row['id']) {
      _resetForm();
    }
    await _loadTransactions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUrduGlobal.value
              ? '\u0627\u0646\u0679\u0631\u06cc \u0688\u06cc\u0644\u06cc\u0679 \u06a9\u0631 \u062f\u06cc \u06af\u0626\u06cc \u06c1\u06d2\u06d4'
              : 'Finance entry deleted.',
        ),
      ),
    );
  }

  Future<void> _shareReceipt() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: isUrduGlobal.value
            ? '\u0645\u062f\u0631\u0633\u06c1 \u0627\u0634\u0631\u0641 \u0627\u0644\u0645\u062f\u0627\u0631\u0633 - \u0631\u0633\u06cc\u062f'
            : 'Madrasa Receipt',
      );
    } catch (e) {
      debugPrint('Sharing Error: $e');
    }
  }

  void _showReceiptDialog(double amount,
      {String? receiptNo, Map<String, dynamic>? transaction}) {
    final rawReceiptNo =
        receiptNo ?? transaction?['computer_receipt_no']?.toString();
    final displayReceiptNo = (rawReceiptNo != null &&
            rawReceiptNo.trim().isNotEmpty &&
            rawReceiptNo.trim() != '0')
        ? rawReceiptNo
        : DateTime.now().millisecondsSinceEpoch.toString().substring(6);

    final String donorName = transaction != null
        ? (transaction['donor_name']?.toString() ?? '')
        : _donorController.text;
    final String dateStr = transaction != null
        ? (transaction['date']?.toString() ?? '')
        : _dateController.text;
    final String address = transaction != null
        ? (transaction['donor_address']?.toString() ?? '')
        : _addressController.text;
    final String head = transaction != null
        ? (transaction['head_name']?.toString() ?? '')
        : (selectedHead ?? '-');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final receiptTextStyle = TextStyle(
                              fontSize: w * 0.034,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.25,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                              decorationColor: Colors.black45,
                            );

                            final isLongName = donorName.length > 20;
                            final nameHeight = isLongName ? 1.4 : 1.25;
                            final addressTop = isLongName ? w * 0.388 : w * 0.375;

                            return AspectRatio(
                              aspectRatio: 1.6,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.asset('assets/receipt_bg.webp',
                                        fit: BoxFit.fill),
                                  ),
                                  Positioned(
                                    top: w * 0.203,
                                    left: w * 0.12,
                                    child: Text(displayReceiptNo,
                                        style: receiptTextStyle.copyWith(
                                            fontSize: w * 0.036, height: 1.0, decoration: TextDecoration.none)),
                                  ),
                                  if (isIncome)
                                    Positioned(
                                      top: w * 0.288,
                                      right: w * 0.06,
                                      left: w * 0.42,
                                      child: Text(
                                        '\u0645\u062d\u062a\u0631\u0645 \u062c\u0646\u0627\u0628: $donorName',
                                        textDirection: ui.TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        style: receiptTextStyle.copyWith(height: nameHeight),
                                      ),
                                    ),
                                  Positioned(
                                    top: w * 0.297,
                                    left: w * 0.08,
                                    child: Text(
                                      '\u062a\u0627\u0631\u06cc\u062e: $dateStr',
                                      textDirection: ui.TextDirection.rtl,
                                      style: receiptTextStyle.copyWith(height: 1.0, decoration: TextDecoration.none),
                                    ),
                                  ),
                                  if (isIncome)
                                    Positioned(
                                      top: addressTop,
                                      right: w * 0.06,
                                      left: w * 0.35,
                                      child: Text(
                                        '\u067e\u062a\u06c1: ${address == '---' ? '' : address}',
                                        textDirection: ui.TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: receiptTextStyle,
                                      ),
                                    ),
                                  Positioned(
                                    top: w * 0.458,
                                    right: w * 0.06,
                                    left: w * 0.38,
                                    child: Text(
                                      '\u0645\u062f: ${head == '---' ? '' : head}',
                                      textDirection: ui.TextDirection.rtl,
                                      textAlign: TextAlign.right,
                                      style: receiptTextStyle,
                                    ),
                                  ),
                                  Positioned(
                                    top: w * 0.458,
                                    left: w * 0.145,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Rs: ${NumberFormat('#,##0').format(double.tryParse(amount.toString()) ?? 0)}/-',
                                          textDirection: ui.TextDirection.ltr,
                                          style: receiptTextStyle.copyWith(height: 1.0, decoration: TextDecoration.none),
                                        ),
                                        SizedBox(height: w * 0.004),
                                        Text(
                                          '(${UrduNumberWords.convert(amount)})',
                                          textDirection: ui.TextDirection.rtl,
                                          style: receiptTextStyle.copyWith(
                                            fontSize: w * 0.024,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                            height: 1.1,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // دستخط وصول کنندہ - دائیں جانب، label دائیں، تصویر بائیں
                                  Positioned(
                                    bottom: w * 0.038,
                                    right: w * 0.06,
                                    left: w * 0.30,
                                    child: Row(
                                      textDirection: ui.TextDirection.rtl,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // label دائیں جانب پہلے
                                        Text(
                                          '\u062f\u0633\u062a\u062e\u0637 \u0648\u0635\u0648\u0644 \u06a9\u0646\u0646\u062f\u06c1:',
                                          textDirection: ui.TextDirection.rtl,
                                          style: receiptTextStyle.copyWith(
                                            fontSize: w * 0.027,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(width: w * 0.015),
                                        // تصویر label کے بائیں
                                        SizedBox(
                                          width: w * 0.28,
                                          height: w * 0.10,
                                          child: _signatureImage != null
                                              ? Image.file(
                                                  _signatureImage!,
                                                  fit: BoxFit.contain,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen),
                              onPressed: () async {
                                final XFile? image = await _picker.pickImage(
                                    source: ImageSource.gallery);
                                if (image == null) return;
                                setDialogState(() {
                                  _signatureImage = File(image.path);
                                });
                              },
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(
                                isUrduGlobal.value
                                    ? '\u0648\u0635\u0648\u0644 \u06a9\u0646\u0646\u062f\u06c1 \u06a9\u06d2 \u062f\u0633\u062a\u062e\u0637 \u06a9\u06cc \u062a\u0635\u0648\u06cc\u0631 \u0644\u06af\u0627\u0626\u06cc\u06ba'
                                    : 'Upload Signature Image',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade800),
                                  onPressed: _shareReceipt,
                                  icon: const Icon(Icons.share,
                                      color: Colors.white, size: 18),
                                  label: Text(
                                    isUrduGlobal.value
                                        ? '\u0634\u06cc\u0626\u0631 \u06a9\u0631\u06cc\u06ba'
                                        : 'Share',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade700),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _resetForm();
                                  },
                                  child: Text(
                                    isUrduGlobal.value
                                        ? '\u0628\u0646\u062f \u06a9\u0631\u06cc\u06ba'
                                        : 'Close',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _amountController.clear();
      _donorController.clear();
      _addressController.clear();
      _descController.clear();
      _signatureImage = null;
      selectedHead = null;
      isIncome = true;
      _autocompleteKey = UniqueKey();
      _dateController.text = _formatDate(DateTime.now());
    });
  }

  Future<void> _saveTransaction() async {
    if (selectedHead == null || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value
                ? '\u0645\u06c1\u0631\u0628\u0627\u0646\u06cc \u06a9\u0631 \u06a9\u06d2 \u0644\u0627\u0632\u0645\u06cc \u062e\u0627\u0646\u06d2 \u067e\u0631 \u06a9\u0631\u06cc\u06ba\u06d4'
                : 'Please fill the required fields.',
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final editingId = _editingId;
    int? compReceiptNo;
    if (editingId == null && isIncome) {
      try {
        final db = await DBHelper().database;
        int userId = currentUserId.value ?? 1;
        int minNo = userId * 100000;
        int maxLimit = (userId + 1) * 100000;

        final result = await db.rawQuery(
            'SELECT MAX(computer_receipt_no) as max_no FROM finance WHERE computer_receipt_no >= ? AND computer_receipt_no < ?',
            [minNo, maxLimit]);
        int maxNo = minNo;
        if (result.isNotEmpty && result.first['max_no'] != null) {
          maxNo = result.first['max_no'] as int;
        }
        compReceiptNo = maxNo + 1;
      } catch (e) {
        debugPrint("Error fetching max receipt no: $e");
        int userId = currentUserId.value ?? 1;
        compReceiptNo = (userId * 100000) + 1;
      }
    }

    final row = {
      'date': _dateController.text,
      'type': isIncome ? 'Income' : 'Expense',
      'amount': amount,
      'description': _buildDescription(),
      'head_id': null,
      'manual_receipt_no': '',
      'donor_name': isIncome ? _donorController.text.trim() : '',
      'donor_address': isIncome ? _addressController.text.trim() : '',
      'user_id': currentUserId.value ?? 1,
      'user_name': currentUserName.value ?? currentUserRole.value ?? 'Admin',
    };
    if (compReceiptNo != null) {
      row['computer_receipt_no'] = compReceiptNo;
    }

    try {
      int? savedLocalId;
      if (editingId != null) {
        await DBHelper().updateFinance(editingId, row);
      } else {
        savedLocalId = await DBHelper().insertFinance(row);
      }

      var syncFailed = false;
      try {
        await SyncService.runTwoWaySync();
      } catch (e) {
        syncFailed = true;
        debugPrint('Finance auto sync failed: $e');
      }

      await _loadTransactions();
      if (!mounted) return;

      if (editingId == null && isIncome) {
        final finalReceiptNo = await _findSavedReceiptNo(savedLocalId, row) ??
            compReceiptNo?.toString();
        _showReceiptDialog(amount, receiptNo: finalReceiptNo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncFailed
                  ? (isUrduGlobal.value
                      ? 'انٹری محفوظ ہو گئی، مگر سنک فی الحال نہیں ہو سکا۔ دوبارہ سنک کریں۔'
                      : 'Entry saved locally, but sync failed. Please sync again.')
                  : editingId != null
                      ? (isUrduGlobal.value
                          ? 'انٹری اپ ڈیٹ کر دی گئی ہے اور سنک ہو گئی ہے۔'
                          : 'Entry updated and synced successfully.')
                      : (isUrduGlobal.value
                          ? 'انٹری محفوظ کر دی گئی ہے اور سنک ہو گئی ہے۔'
                          : 'Entry saved and synced successfully.'),
            ),
          ),
        );
        _resetForm();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value
                ? '\u0627\u0646\u0679\u0631\u06cc \u0645\u062d\u0641\u0648\u0638 \u0646\u06c1\u06cc\u06ba \u06c1\u0648 \u0633\u06a9\u06cc\u06d4'
                : 'Could not save the entry.',
          ),
        ),
      );
    }
  }

  Future<String?> _findSavedReceiptNo(
      int? localId, Map<String, dynamic> row) async {
    final db = await DBHelper().database;
    final byLocalId = localId == null
        ? <Map<String, dynamic>>[]
        : await db.query(
            'finance',
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
    if (byLocalId.isNotEmpty) {
      final receipt = byLocalId.first['computer_receipt_no']?.toString();
      if (receipt != null &&
          receipt.trim().isNotEmpty &&
          receipt.trim() != '0') {
        return receipt;
      }
    }

    final rows = await db.query(
      'finance',
      where:
          'date = ? AND type = ? AND amount = ? AND description = ? AND user_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [
        row['date'],
        row['type'],
        row['amount'],
        row['description'],
        row['user_id'],
      ],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final receipt = rows.first['computer_receipt_no']?.toString();
    if (receipt == null || receipt.trim().isEmpty || receipt.trim() == '0') {
      return null;
    }
    return receipt;
  }

  String _displayTitle(Map<String, dynamic> row) {
    final description = (row['description'] ?? '').toString();
    final head = _extractPart(description, ['\u0645\u062f:', 'Ù…Ø¯:']);
    if (head.isNotEmpty) return head;
    return (row['type'] ?? '').toString();
  }

  String _displaySubtitle(Map<String, dynamic> row) {
    final note = _extractPart((row['description'] ?? '').toString(),
        ['\u062a\u0641\u0635\u06cc\u0644:', 'ØªÙØµÛŒÙ„:']);
    if (note.isNotEmpty) return note;
    return (row['description'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => DashboardPage()),
            );
          },
          child: Directionality(
            textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
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
                    ? '\u0641\u0646\u0627\u0646\u0633 \u0645\u0646\u06cc\u062c\u0645\u0646\u0679'
                    : 'Finance Management'),
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
                          _loadTransactions();
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
              body: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _typeBtn(
                                isUrduGlobal.value
                                    ? '\u0622\u0645\u062f\u0646'
                                    : 'Income',
                                true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _typeBtn(
                                isUrduGlobal.value
                                    ? '\u062e\u0631\u0686'
                                    : 'Expense',
                                false)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInputs(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isIncome
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _saveTransaction,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: Text(
                                _editingId != null
                                    ? (isUrduGlobal.value
                                        ? '\u0627\u067e \u0688\u06cc\u0679 \u06a9\u0631\u06cc\u06ba'
                                        : 'Update Entry')
                                    : (isUrduGlobal.value
                                        ? (isIncome
                                            ? '\u0645\u062d\u0641\u0648\u0638 \u06a9\u0631\u06cc\u06ba \u0627\u0648\u0631 \u0631\u0633\u06cc\u062f \u0646\u06a9\u0627\u0644\u06cc\u06ba'
                                            : '\u0645\u062d\u0641\u0648\u0638 \u06a9\u0631\u06cc\u06ba')
                                        : (isIncome
                                            ? 'Save & Receipt'
                                            : 'Save Entry')),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        if (_editingId != null) ...[
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _resetForm,
                            child: Text(isUrduGlobal.value
                                ? '\u0645\u0646\u0633\u0648\u062e'
                                : 'Cancel'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildBalanceSummary(isUrdu),
                    const SizedBox(height: 16),
                    _buildFinanceSections(isUrdu),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceSummary(bool isUrdu) {
    double income = 0;
    double expense = 0;

    if (currentUserRole.value == 'admin') {
      // ایڈمن: تمام یوزرز کا مجموعی حساب
      for (var ug in _userGroups.values) {
        for (var r in (ug['income'] as List)) {
          income += double.tryParse(r['amount'].toString()) ?? 0;
        }
        for (var r in (ug['expense'] as List)) {
          expense += double.tryParse(r['amount'].toString()) ?? 0;
        }
      }
    } else {
      for (var r in _financeRecords) {
        double amt = double.tryParse(r['amount'].toString()) ?? 0;
        if (r['type'].toString().toLowerCase() == 'income') {
          income += amt;
        } else {
          expense += amt;
        }
      }
    }
    double balance = income - expense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(
            currentUserRole.value == 'admin'
                ? (isUrdu
                    ? 'مجموعی بیلنس (تمام یوزرز)'
                    : 'Total Balance (All Users)')
                : (isUrdu ? 'کل بیلنس' : 'Total Balance'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text('Rs. ${balance.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(isUrdu ? 'کل آمدن' : 'Total Income', income,
                  Colors.greenAccent),
              _summaryItem(isUrdu ? 'کل خرچ' : 'Total Expense', expense,
                  Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text('Rs. ${amount.toStringAsFixed(0)}',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFinanceSections(bool isUrdu) {
    if (currentUserRole.value == 'admin') {
      return _buildAdminUserWiseView(isUrdu);
    }
    // نان ایڈمن: پہلے جیسا نظاریہ
    final incomeList = _financeRecords
        .where((r) => r['type'].toString().toLowerCase() == 'income')
        .toList();
    final expenseList = _financeRecords
        .where((r) => r['type'].toString().toLowerCase() == 'expense')
        .toList();

    return Column(
      children: [
        _buildSectionHeader(isUrdu ? 'آمدن کی انٹریز' : 'Income Entries',
            Colors.green.shade800),
        if (incomeList.isEmpty)
          _emptySection(isUrdu)
        else
          ...incomeList.map((r) => _transactionCard(r, true)),
        const SizedBox(height: 20),
        _buildSectionHeader(
            isUrdu ? 'خرچ کی انٹریز' : 'Expense Entries', Colors.red.shade800),
        if (expenseList.isEmpty)
          _emptySection(isUrdu)
        else
          ...expenseList.map((r) => _transactionCard(r, false)),
      ],
    );
  }

  /// ایڈمن کے لیے یوزر وائز Accordion ویو
  Widget _buildAdminUserWiseView(bool isUrdu) {
    if (_userGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No records found',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
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
              // یوزر ہیڈر
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
                  decoration: BoxDecoration(
                    color: primaryGreen,
                  ),
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
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // منی بیجز
                      _adminBadge(isUrdu ? 'آمدن' : 'In', uInc,
                          Colors.greenAccent.shade700),
                      const SizedBox(width: 6),
                      _adminBadge(
                          isUrdu ? 'خرچ' : 'Exp', uExp, Colors.redAccent),
                      const SizedBox(width: 6),
                      _adminBadge(
                          isUrdu ? 'بیلنس' : 'Bal',
                          uBal,
                          uBal >= 0
                              ? Colors.lightBlueAccent
                              : Colors.orangeAccent),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (isExpanded) ...[
                // ذیلی سمری
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                          child: _userStatChip(isUrdu ? 'آمدن' : 'Income', uInc,
                              Colors.green.shade700)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _userStatChip(isUrdu ? 'خرچ' : 'Expense', uExp,
                              Colors.red.shade700)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _userStatChip(
                        isUrdu ? 'بیلنس' : 'Balance',
                        uBal,
                        uBal >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      )),
                    ],
                  ),
                ),
                // آمدن
                if (incomeList.isNotEmpty) ...[
                  _buildSectionHeader(
                      isUrdu ? 'آمدن کی انٹریز' : 'Income Entries',
                      Colors.green.shade800),
                  ...incomeList.map((r) => _transactionCard(r, true)),
                ],
                // خرچ
                if (expenseList.isNotEmpty) ...[
                  _buildSectionHeader(
                      isUrdu ? 'خرچ کی انٹریز' : 'Expense Entries',
                      Colors.red.shade800),
                  ...expenseList.map((r) => _transactionCard(r, false)),
                ],
                if (incomeList.isEmpty && expenseList.isEmpty)
                  _emptySection(isUrdu),
                const SizedBox(height: 8),
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

  Widget _userStatChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Rs.${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _emptySection(bool isUrdu) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
          child: Text(isUrdu ? 'کوئی ریکارڈ نہیں' : 'No records',
              style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _transactionCard(Map<String, dynamic> row, bool isInc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInc ? Colors.green.shade50 : Colors.red.shade50,
          child: Icon(isInc ? Icons.arrow_downward : Icons.arrow_upward,
              color: isInc ? Colors.green.shade800 : Colors.red.shade800,
              size: 20),
        ),
        title: Text(_displayTitle(row),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${row['date']} | ${_displaySubtitle(row)}',
                style: const TextStyle(fontSize: 12)),
            if (currentUserRole.value == 'admin' &&
                row['user_name'] != null &&
                row['user_name'].toString().isNotEmpty)
              Text('${isInc ? "وصول کنندہ" : "خرچ کنندہ"}: ${row['user_name']}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Rs. ${row['amount']}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isInc ? Colors.green.shade800 : Colors.red.shade800)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInc) ...[
                  InkWell(
                      onTap: () {
                        final amount =
                            double.tryParse(row['amount'].toString()) ?? 0.0;
                        _showReceiptDialog(amount, transaction: row);
                      },
                      child: Icon(Icons.receipt_long,
                          size: 16, color: Colors.blue.shade800)),
                  const SizedBox(width: 10),
                ],
                InkWell(
                    onTap: () => _populateForEdit(row),
                    child: Icon(Icons.edit, size: 16, color: primaryGreen)),
                const SizedBox(width: 10),
                InkWell(
                    onTap: () => _deleteTransaction(row),
                    child:
                        const Icon(Icons.delete, size: 16, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String title, bool type) {
    final active = isIncome == type;
    final color = type ? Colors.green.shade800 : Colors.red.shade800;
    return GestureDetector(
      onTap: () => setState(() {
        isIncome = type;
        selectedHead = null;
        _autocompleteKey = UniqueKey();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
                color: active ? Colors.white : color,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickEntryDate,
              decoration: InputDecoration(
                labelText: isUrduGlobal.value
                    ? '\u062a\u0627\u0631\u06cc\u062e'
                    : 'Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _pickEntryDate,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    key: _autocompleteKey,
                    initialValue: TextEditingValue(text: selectedHead ?? ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return currentHeads;
                      }
                      return currentHeads.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() => selectedHead = selection);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (val) {
                          selectedHead = val;
                        },
                        decoration: InputDecoration(
                          labelText: isUrduGlobal.value
                              ? 'مد (تلاش کریں یا لکھیں)'
                              : 'Head (Search or Type)',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.search),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 56, // Standard TextField height
                  decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(4)),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _showAddHeadDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isUrduGlobal.value ? '\u0631\u0642\u0645' : 'Amount',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.money),
              ),
            ),
            if (isIncome) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _donorController,
                decoration: InputDecoration(
                  labelText: isUrduGlobal.value
                      ? '\u0646\u0627\u0645 \u0645\u0639\u0627\u0648\u0646'
                      : 'Donor Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText:
                      isUrduGlobal.value ? '\u067e\u062a\u06c1' : 'Address',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 15),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isUrduGlobal.value
                    ? '\u062a\u0641\u0635\u06cc\u0644'
                    : 'Details',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHeadDialog() {
    final TextEditingController newHeadCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrduGlobal.value ? 'نئی مد شامل کریں' : 'Add New Head'),
        content: TextField(
          controller: newHeadCtrl,
          decoration: InputDecoration(
            labelText: isUrduGlobal.value ? 'مد کا نام' : 'Head Name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrduGlobal.value ? 'منسوخ' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newHeadCtrl.text.trim().isNotEmpty) {
                final newHead = newHeadCtrl.text.trim();
                setState(() {
                  if (isIncome) {
                    if (isUrduGlobal.value) {
                      incomeHeadsUr.add(newHead);
                    } else {
                      incomeHeadsEn.add(newHead);
                    }
                  } else {
                    if (isUrduGlobal.value) {
                      expenseHeadsUr.add(newHead);
                    } else {
                      expenseHeadsEn.add(newHead);
                    }
                  }
                  selectedHead = newHead;
                  _autocompleteKey = UniqueKey();
                });
              }
              Navigator.pop(context);
            },
            child: Text(isUrduGlobal.value ? 'شامل کریں' : 'Add'),
          ),
        ],
      ),
    );
  }
}

