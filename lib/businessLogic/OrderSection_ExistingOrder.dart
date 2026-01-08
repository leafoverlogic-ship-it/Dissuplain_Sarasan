import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dissuplain_app_web_mobile/dataLayer/orders_repository.dart';
import 'package:dissuplain_app_web_mobile/app_session.dart';

class OrderSectionExistingOrder extends StatefulWidget {
  final OrdersRepository ordersRepo;
  final String customerCode;
  final Map<String, String>? userNameById; // optional map for approver names
  final String? initialOrderId;
  const OrderSectionExistingOrder({
    super.key,
    required this.ordersRepo,
    required this.customerCode,
    this.userNameById,
    this.initialOrderId,
  });

  @override
  State<OrderSectionExistingOrder> createState() =>
      _OrderSectionExistingOrderState();
}

class _OrderSectionExistingOrderState extends State<OrderSectionExistingOrder> {
  final _statusFilters = const [
    'All',
    'New',
    'Confirmed',
    'Cancelled',
    'AM Confirmed',
    'GM Confirmed',
    'CEO Confirmed',
  ];
  final ScrollController _hCtrl = ScrollController();

  String _filter = 'All';
  List<OrderEntry> _orders = [];
  List<DistributorRow> _distributors = [];
  final Map<String, GlobalKey> _orderKeys = {};
  bool _didJump = false;

  final String _currentUserId = AppSession().salesPersonId ?? '';
  final String _roleId = AppSession().roleId ?? '';
  bool get _canEditStatus {
    final n = int.tryParse(_roleId);
    if (n == null) return false;
    return n >= 2; // Area Manager or above
  }

  bool _gmNeeded(double total) => total > 10000;
  bool _ceoNeeded(double total) => total >= 20001;

  String _gmLabel(String name, double total) {
    if (!_gmNeeded(total)) return 'N/A';
    return name.isEmpty ? 'Needed' : name;
  }

  String _ceoLabel(String name, double total) {
    if (!_ceoNeeded(total)) return 'N/A';
    return name.isEmpty ? 'Needed' : name;
  }

  bool _canApproveStage(
    String targetStatus,
    double total,
    String currentStatus,
  ) {
    final role = int.tryParse(_roleId) ?? 0;
    if (targetStatus == 'Cancelled') return true;
    switch (targetStatus) {
      case 'AM Confirmed':
        return role >= 2;
      case 'GM Confirmed':
        if (total <= 10000) return false; // GM not needed below 10k
        if (currentStatus != 'AM Confirmed') return false; // needs AM first
        return role >= 5; // GM or higher
      case 'CEO Confirmed':
        if (total < 20001) return false; // CEO only 20001+
        if (currentStatus != 'GM Confirmed') return false; // needs GM first
        return role == 7;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.ordersRepo
        .streamForCustomer(widget.customerCode)
        .listen((v) => setState(() => _orders = v));
    widget.ordersRepo.streamDistributors().listen(
          (v) => setState(() => _distributors = v),
        );
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders
        .where((o) => _filter == 'All' ? true : o.orderConfirmation == _filter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            DropdownButton<String>(
              value: _filter,
              items: _statusFilters
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _filter = v ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const double targetWidth = 1200;
            final double contentWidth =
                constraints.maxWidth > targetWidth ? constraints.maxWidth : targetWidth;

            return Scrollbar(
              controller: _hCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _hCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: _buildOrdersDisplayMP(filtered),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _scheduleJump() {
    if (_didJump) return;
    final targetId = widget.initialOrderId;
    if (targetId == null || targetId.isEmpty) return;
    final key = _orderKeys[targetId];
    if (key == null) return;
    _didJump = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = key?.currentContext;
      if (current == null) {
        _didJump = false;
        return;
      }
      Scrollable.ensureVisible(
        current,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _updateDeliveryStatus(
    String orderId,
    String status,
  ) async {
    final normalized = status.toLowerCase() == 'delivered' ? 'Delivered' : 'Undelivered';
    final deliveryDate = normalized == 'Delivered'
        ? DateTime.now().millisecondsSinceEpoch
        : 0;
    await FirebaseDatabase.instance
        .ref('Orders/${widget.customerCode}/$orderId')
        .update({'deliveryStatus': normalized, 'deliveryDate': deliveryDate});
  }

  Widget _buildOrdersDisplayMP(List<OrderEntry> src) {
    String _name(String id) {
      if (id.isEmpty) return '';
      final map = widget.userNameById;
      if (map == null || map.isEmpty) return id;
      return map[id] ?? id;
    }
    String _fmtDate(int ms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d-$m-${dt.year}';
    }
    String _fmtDeliveryDate(int ms) {
      if (ms <= 0) return '';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d-$m-${dt.year}';
    }

    String _distName(String id) => _distributors
        .firstWhere(
          (d) => d.distributorID == id,
          orElse: () => DistributorRow(distributorID: '', firmName: 'ƒ?"'),
        )
        .firmName;

    Text _head(String t) => Text(
          t,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        );

    Widget _miniHeader() => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(
            children: const [
              Expanded(
                flex: 15,
                child: Text(
                  'Product Code',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 35,
                child: Text(
                  'Product Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'MRP',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'Billing Quantity',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    'Billing Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'Free Quantity',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Rate',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  'Product Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'AM Approver',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'GM Approver',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'CEO Approver',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    Widget _miniRow(OrderDisplayLine l) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 15, child: Text(l.productCode)),
              Expanded(flex: 35, child: Text(l.productName)),
              Expanded(
                flex: 10,
                child: Text(
                  l.productMRP.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  l.billQuantity.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    l.billingType,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  l.freeQuantity.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  l.rate.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  l.totalAmount.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                ),
              ),
              const Expanded(flex: 12, child: SizedBox.shrink()),
              const Expanded(flex: 12, child: SizedBox.shrink()),
              const Expanded(flex: 12, child: SizedBox.shrink()),
            ],
          ),
        );

    final children = <Widget>[];
    for (final h in src) {
      final total = widget.ordersRepo.grandTotalFromEntryMP(h);
      final key = _orderKeys.putIfAbsent(h.orderID, () => GlobalKey());
      children.add(
        Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // --- header labels ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(flex: 16, child: _head('Order ID')),
                    Expanded(flex: 14, child: _head('Confirmation')),
                    Expanded(flex: 12, child: _head('AM Approver')),
                    Expanded(flex: 12, child: _head('GM Approver')),
                    Expanded(flex: 12, child: _head('CEO Approver')),
                    Expanded(flex: 14, child: _head('Order Type')),
                    Expanded(flex: 22, child: _head('Distributor')),
                    Expanded(flex: 14, child: _head('Order Date')),
                    Expanded(flex: 12, child: _head('Delivery Status')),
                    Expanded(flex: 12, child: _head('Delivery Date')),
                    Expanded(flex: 10, child: _head('Grand Total')),
                  ],
                ),
              ),
              // --- header values ---
              Row(
                children: [
                  Expanded(
                    flex: 16,
                    child: Text(
                      h.orderID,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: _canEditStatus
                        ? _InlineStatusEditor(
                            initial: h.orderConfirmation,
                            onSave: (v) async {
                              final total =
                                  widget.ordersRepo.grandTotalFromEntryMP(h);
                              if (!_canApproveStage(
                                v,
                                total,
                                h.orderConfirmation,
                              )) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You do not have approval rights for this stage/amount or previous stage is pending.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final approverId =
                                  v == 'Cancelled' ? '' : _currentUserId;
                              await widget.ordersRepo.updateConfirmation(
                                widget.customerCode,
                                h.orderID,
                                v,
                                approverId: approverId,
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Status updated to $v'),
                                ),
                              );
                            },
                          )
                        : Text(h.orderConfirmation),
                  ),
                  Expanded(flex: 12, child: Text(_name(h.amApproverID))),
                  Expanded(
                    flex: 12,
                    child: Text(_gmLabel(_name(h.gmApproverID), total)),
                  ),
                  Expanded(
                    flex: 12,
                    child: Text(_ceoLabel(_name(h.ceoApproverID), total)),
                  ),
                  Expanded(flex: 14, child: Text(h.orderType)),
                  Expanded(
                    flex: 22,
                    child: Text(_distName(h.distributorID)),
                  ),
                  Expanded(flex: 14, child: Text(_fmtDate(h.orderDate))),
                  Expanded(
                    flex: 12,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (h.deliveryStatus == 'Delivered')
                            ? 'Delivered'
                            : 'Undelivered',
                        items: const [
                          DropdownMenuItem(
                            value: 'Undelivered',
                            child: Text('Undelivered'),
                          ),
                          DropdownMenuItem(
                            value: 'Delivered',
                            child: Text('Delivered'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          _updateDeliveryStatus(h.orderID, v);
                        },
                      ),
                    ),
                  ),
                  Expanded(flex: 12, child: Text(_fmtDeliveryDate(h.deliveryDate))),
                  Expanded(
                    flex: 10,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        total.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // --- products mini table ---
              _miniHeader(),
              const Divider(height: 1),
              ...widget.ordersRepo.linesFromEntryMP(h).map(_miniRow),
            ],
          ),
        ),
      );
    }

    _scheduleJump();

    return Column(
      children: [
        ...children,
      ],
    );
  }
}

class _InlineStatusEditor extends StatefulWidget {
  final Future<void> Function(String) onSave;
  final String initial;
  const _InlineStatusEditor({
    required this.onSave,
    this.initial = 'Confirmed',
    Key? key,
  }) : super(key: key);
  @override
  State<_InlineStatusEditor> createState() => _InlineStatusEditorState();
}

class _InlineStatusEditorState extends State<_InlineStatusEditor> {
  String? _v;
  static const List<String> _options = [
    'New',
    'Cancelled',
    'Confirmed', // legacy
    'AM Confirmed',
    'GM Confirmed',
    'CEO Confirmed',
  ];

  @override
  void initState() {
    super.initState();
    _v = _options.contains(widget.initial) ? widget.initial : 'New';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: _v,
          isDense: true,
          items: _options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _v = v),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, size: 18),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: (_v == null || _v == 'New')
                  ? null
                  : () async {
                      final target = _v == 'Confirmed' ? 'AM Confirmed' : _v!;
                      await widget.onSave(target);
                    },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _v = ''),
            ),
          ],
        ),
      ],
    );
  }
}
