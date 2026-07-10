import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';
import '../dataLayer/orders_repository.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final OrdersRepository _repo = OrdersRepository();
  final TextEditingController _searchController = TextEditingController();

  List<ProductRow> _products = [];
  StreamSubscription<List<ProductRow>>? _productsSub;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _productsSub = _repo.streamProducts().listen((items) {
      if (!mounted) return;
      setState(() => _products = items);
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ProductRow> get _filteredProducts {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      return p.productCode.toLowerCase().contains(q) ||
          p.productName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDeleteProduct(ProductRow product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove ${product.productName} from the product list and the order flow?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.deleteProduct(
      productCode: product.productCode,
      storageKey: product.firebaseKey,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
    }
  }

  Future<void> _confirmClearAllProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all products?'),
        content: const Text('This will remove every product from Product Manager and the order flow. You can add them again afterward.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.clearAllProducts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All products cleared')),
      );
    }
  }

  Future<void> _openProductForm({ProductRow? existing}) async {
    final isEditing = existing != null;
    final safeExisting = existing;
    final codeCtrl = TextEditingController(text: safeExisting?.productCode ?? '');
    final nameCtrl = TextEditingController(text: safeExisting?.productName ?? '');
    final mrpCtrl = TextEditingController(text: safeExisting?.mrp == 0 ? '' : (safeExisting?.mrp ?? 0).toString());
    final rateCtrl = TextEditingController(text: safeExisting?.rate == 0 ? '' : (safeExisting?.rate ?? 0).toString());
    final schemeBillingQtyCtrl = TextEditingController(
      text: (safeExisting?.schemeBillingQty ?? 0) == 0
          ? ''
          : (safeExisting?.schemeBillingQty ?? 0).toString(),
    );
    final schemeFreeQtyCtrl = TextEditingController(
      text: (safeExisting?.schemeFreeQty ?? 0) == 0
          ? ''
          : (safeExisting?.schemeFreeQty ?? 0).toString(),
    );

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Theme.of(ctx).colorScheme.surface,
                  Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Product' : 'Add New Product',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Store the product details that will appear in the client order forms.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  _buildField('Product Code', codeCtrl, required: true),
                  const SizedBox(height: 12),
                  _buildField('Product Name', nameCtrl, required: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildField('MRP', mrpCtrl, required: true, keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Rate', rateCtrl, required: true, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'With Scheme',
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Free Quantity for every Billing Quantity.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                'Billing Quantity',
                                schemeBillingQtyCtrl,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                'Free Quantity',
                                schemeFreeQtyCtrl,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          final code = codeCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          final mrp = double.tryParse(mrpCtrl.text.trim()) ?? 0;
                          final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                          final schemeBillingQty = int.tryParse(
                                schemeBillingQtyCtrl.text.trim(),
                              ) ??
                              0;
                          final schemeFreeQty = int.tryParse(
                                schemeFreeQtyCtrl.text.trim(),
                              ) ??
                              0;

                          if ((schemeBillingQty > 0 && schemeFreeQty <= 0) ||
                              (schemeFreeQty > 0 && schemeBillingQty <= 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter both Billing Quantity and Free Quantity for With Scheme',
                                ),
                              ),
                            );
                            return;
                          }

                          if (isEditing) {
                            await _repo.updateProduct(
                              oldProductCode: existing!.productCode,
                              productCode: code,
                              productName: name,
                              mrp: mrp,
                              rate: rate,
                              schemeBillingQty: schemeBillingQty,
                              schemeFreeQty: schemeFreeQty,
                            );
                          } else {
                            await _repo.addProduct(
                              productCode: code,
                              productName: name,
                              mrp: mrp,
                              rate: rate,
                              schemeBillingQty: schemeBillingQty,
                              schemeFreeQty: schemeFreeQty,
                            );
                          }
                          if (mounted) {
                            Navigator.pop(ctx, true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Product updated' : 'Product added')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(isEditing ? 'Update' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: required
              ? (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please enter $label';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.72),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            hintText: label,
            hintStyle: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07111F) : const Color(0xFFF4F7FF),
      body: SafeArea(
        child: Column(
          children: [
            const CommonHeader(pageTitle: 'Product Management'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF18253A), const Color(0xFF0F172A)]
                                  : [const Color(0xFFFFFFFF), const Color(0xFFEEF4FF)],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Manage products for orders',
                                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add new products or update existing ones to populate the order selection in client details.',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: () => _openProductForm(),
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                    label: const Text('Add Product'),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: _confirmClearAllProducts,
                                    icon: const Icon(Icons.delete_sweep_rounded),
                                    label: const Text('Clear All Products'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by code or name',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121C2C) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_filteredProducts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF111A2B) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: const Text('No products found. Add your first product to get started.'),
                      )
                    else
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _filteredProducts.map((product) => SizedBox(
                          width: 320,
                          child: _ProductCard(
                            product: product,
                            onEdit: () => _openProductForm(existing: product),
                            onDelete: () => _confirmDeleteProduct(product),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CommonFooter(),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final ProductRow product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({required this.product, required this.onEdit, required this.onDelete});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(_hovered ? 1.01 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF16233A), const Color(0xFF0F172A)]
                : [const Color(0xFFFFFFFF), const Color(0xFFF2F6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hovered ? 0.14 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit product',
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete product',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(widget.product.productCode.isEmpty ? '—' : widget.product.productCode, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(widget.product.productName.isEmpty ? 'Unnamed product' : widget.product.productName, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DetailTile(label: 'MRP', value: '₹${widget.product.mrp.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DetailTile(label: 'Rate', value: '₹${widget.product.rate.toStringAsFixed(2)}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DetailTile(
                label: 'With Scheme',
                value: '${widget.product.schemeBillingQty}:${widget.product.schemeFreeQty}  (Billing:Free)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
