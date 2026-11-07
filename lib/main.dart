import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VetInventoryApp());
}

class VetInventoryApp extends StatelessWidget {
  const VetInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جرد العيادة البيطرية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterialStyle: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFF00897B),
        ),
        fontFamily: 'Roboto',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'EG'),
      ],
      locale: const Locale('ar', 'EG'),
      home: const InventoryHomeScreen(),
    );
  }
}

// ---------------- Database Helper ----------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vet_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buyPrice REAL NOT NULL,
        sellPrice REAL NOT NULL,
        expiryDate TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('items', row);
  }

  Future<List>> fetchItems() async {
    final db = await instance.database;
    return await db.query('items', orderBy: 'id DESC');
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------- Main Screen ----------------
class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  List> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshItemList();
  }

  Future<void> _refreshItemList() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.fetchItems();
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  double get _totalInventoryValue {
    return _items.fold(0, (sum, item) => sum + (item['buyPrice'] * item['quantity']));
  }

  int get _lowStockCount {
    return _items.where((item) => (item['quantity'] as int) <= 5).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      return item['name'].toString().contains(_searchQuery) ||
             item['category'].toString().contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد العيادة البيطرية', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                _buildSearchBox(),
                Expanded(
                  child: filteredItems.isEmpty
                      ? const Center(child: Text('لا توجد أصناف مسجلة حالياً'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildItemCard(item);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('إجمالي الأصناف', '${_items.length}'),
          _buildStatItem('قيمة المخزون', '${_totalInventoryValue.toStringAsFixed(1)} ج.م'),
          _buildStatItem('أوشكت على النفاذ', '$_lowStockCount', isWarning: _lowStockCount > 0),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool isWarning = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red.shade700 : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'بحث باسم الصنف أو الفئة...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final int qty = item['quantity'];
    final DateTime expiry = DateTime.parse(item['expiryDate']);
    final bool isNearExpiry = expiry.difference(DateTime.now()).inDays < 60;
    final bool isLowStock = qty <= 5;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Chip(
              label: Text(item['category'], style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Text('تاريخ الانتهاء: ${DateFormat('yyyy-MM-dd').format(expiry)}',
                  style: TextStyle(color: isNearExpiry ? Colors.red : Colors.grey.shade700)),
              Text('سعر الشراء: ${item['buyPrice']} ج.م | سعر البيع: ${item['sellPrice']} ج.م'),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLowStock ? Colors.red.shade100 : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'الكمية: $qty',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLowStock ? Colors.red.shade900 : Colors.teal.shade900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showFormDialog(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deleteItem(item['id']),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteItem(id);
    _refreshItemList();
  }

  void _showFormDialog(Map<String, dynamic>? item) {
    final isEdit = item != null;
    final nameController = TextEditingController(text: isEdit ? item['name'] : '');
    final categoryController = TextEditingController(text: isEdit ? item['category'] : 'أدوية');
    final qtyController = TextEditingController(text: isEdit ? item['quantity'].toString() : '');
    final buyPriceController = TextEditingController(text: isEdit ? item['buyPrice'].toString() : '');
    final sellPriceController = TextEditingController(text: isEdit ? item['sellPrice'].toString() : '');
    DateTime selectedExpiry = isEdit ? DateTime.parse(item['expiryDate']) : DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل صنف' : 'إضافة صنف جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الصنف/الدواء')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'الفئة (أدوية، تحصينات، مستلزمات...)')),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
                TextField(controller: buyPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء')),
                TextField(controller: sellPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('تاريخ الانتهاء: ${DateFormat('yyyy-MM-dd').format(selectedExpiry)}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedExpiry,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedExpiry = picked);
                        }
                      },
                      child: const Text('تغيير'),
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'category': categoryController.text,
                  'quantity': int.tryParse(qtyController.text) ?? 0,
                  'buyPrice': double.tryParse(buyPriceController.text) ?? 0.0,
                  'sellPrice': double.tryParse(sellPriceController.text) ?? 0.0,
                  'expiryDate': selectedExpiry.toIso8601String(),
                };

                if (isEdit) {
                  data['id'] = item['id'];
                  await DatabaseHelper.instance.updateItem(data);
                } else {
                  await DatabaseHelper.instance.insertItem(data);
                }

                if (mounted) Navigator.pop(ctx);
                _refreshItemList();
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}
