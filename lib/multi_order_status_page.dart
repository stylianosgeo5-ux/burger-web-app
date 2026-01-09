import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'order_status_page.dart';
import 'main.dart' show OrdersHistory;

class MultiOrderStatusPage extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  const MultiOrderStatusPage({Key? key, required this.orders}) : super(key: key);

  @override
  State<MultiOrderStatusPage> createState() => _MultiOrderStatusPageState();
}

class _MultiOrderStatusPageState extends State<MultiOrderStatusPage> {
  int _selectedOrderIndex = 0;
  Timer? _syncTimer;
  static String get serverUrl => 'https://burger-backend-rxwl.onrender.com';
  List<Map<String, dynamic>> _localOrders = [];

  @override
  void initState() {
    super.initState();
    _localOrders = List.from(widget.orders);
    // Always select the most recent order by default
    if (_localOrders.isNotEmpty) {
      _selectedOrderIndex = _localOrders.length - 1;
    }
    _startSyncing();
  }

  @override
  void didUpdateWidget(MultiOrderStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When new order added, add it to local list
    if (widget.orders.length > oldWidget.orders.length) {
      setState(() {
        _localOrders = List.from(widget.orders);
        _selectedOrderIndex = _localOrders.length - 1;
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncing() {
    // Check server every 5 seconds to see if orders still exist
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _syncWithServer();
      }
    });
  }

  Future<void> _syncWithServer() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/orders'));
      if (response.statusCode == 200) {
        final List<dynamic> serverOrders = json.decode(response.body);
        
        // Check which local orders are no longer on the server
        final serverTimestamps = serverOrders.map((o) => o['timestamp']).toSet();
        final ordersToRemove = <Map<String, dynamic>>[];
        
        for (var localOrder in _localOrders) {
          if (!serverTimestamps.contains(localOrder['timestamp'])) {
            ordersToRemove.add(localOrder);
          }
        }
        
        if (ordersToRemove.isNotEmpty && mounted) {
          setState(() {
            for (var order in ordersToRemove) {
              _localOrders.remove(order);
              // Also remove from global OrdersHistory
              OrdersHistory().allOrders.removeWhere((o) => o['timestamp'] == order['timestamp']);
            }
            
            // Adjust selected index if needed
            if (_selectedOrderIndex >= _localOrders.length && _localOrders.isNotEmpty) {
              _selectedOrderIndex = _localOrders.length - 1;
            }
          });
        }
      }
    } catch (e) {
      // Silently handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No orders yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Order tabs/buttons at the top
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: _localOrders.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedOrderIndex;
              final orderNumber = index + 1;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isSelected ? Colors.orange : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedOrderIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Order $orderNumber',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '\$${_localOrders[index]['totalPrice'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Order status page for selected order
        Expanded(
          child: OrderStatusPage(
            key: ValueKey(_localOrders[_selectedOrderIndex]['timestamp']),
            order: _localOrders[_selectedOrderIndex],
          ),
        ),
      ],
    );
  }
}
