import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrderStatusPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onOrderDeleted;
  const OrderStatusPage({Key? key, required this.order, this.onOrderDeleted}) : super(key: key);

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTimer;
  Timer? _pollingTimer;
  int _currentStep = 0;
  String _estimatedTime = '25-30 min';
  bool _isAnimating = false;
  bool _isConfirmed = false;
  bool _isPreparing = false;
  bool _isCooked = false;
  bool _isFulfilled = false;
  static String get serverUrl => 'https://burger-backend-rxwl.onrender.com';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Set initial status based on order data
    _isConfirmed = widget.order['confirmed'] == true;
    _isPreparing = widget.order['preparing'] == true;
    _isCooked = widget.order['cooked'] == true;
    _isFulfilled = widget.order['fulfilled'] == true;
    
    // Store confirmedAt timestamp if not already present
    if (_isConfirmed && widget.order['confirmedAt'] == null) {
      widget.order['confirmedAt'] = DateTime.now().toIso8601String();
    }
    
    _currentStep = _getOrderStep();
    _updateEstimatedTime();
    
    // Fetch initial status from server immediately
    _checkOrderStatus();
    
    // Start polling for order status updates
    _startPolling();
  }

  int _getOrderStep() {
    // Check order status from dashboard
    if (_isFulfilled) return 4;  // Delivered
    if (_isCooked) return 3;     // Out for Delivery
    
    // Check if 1 minute has passed since confirmed - if yes, treat as preparing
    if (_isConfirmed && !_isPreparing && !_isCooked) {
      try {
        if (widget.order['confirmedAt'] != null) {
          final confirmedTime = DateTime.parse(widget.order['confirmedAt']);
          final now = DateTime.now();
          final difference = now.difference(confirmedTime).inMinutes;
          
          if (difference >= 1) {
            // Auto-set preparing after 1 minute
            Future.microtask(() {
              if (mounted && !_isPreparing) {
                setState(() {
                  _isPreparing = true;
                  _currentStep = 2;
                  _updateEstimatedTime();
                });
              }
            });
            
            return 2;
          }
        }
      } catch (e) {
        // Silently handle error
      }
    }
    
    if (_isPreparing) return 2;  // Preparing
    if (_isConfirmed) return 1;  // Confirmed
    return 0; // Just placed
  }

  void _startPolling() {
    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _checkOrderStatus();
      }
    });
  }

  Future<void> _checkOrderStatus() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/orders'));
      if (response.statusCode == 200) {
        final List<dynamic> orders = json.decode(response.body);
        
        // Always find order by timestamp (don't use cached index)
        final orderTimestamp = widget.order['timestamp'];
        int currentIndex = -1;
        
        for (int i = 0; i < orders.length; i++) {
          if (orders[i]['timestamp'] == orderTimestamp) {
            currentIndex = i;
            break;
          }
        }
        
        if (currentIndex < 0) {
          print('Order not found - timestamp: $orderTimestamp');
          return;
        }
        
        final order = orders[currentIndex];
        final wasConfirmed = _isConfirmed;
        final wasPreparing = _isPreparing;
        final wasCooked = _isCooked;
        final wasFulfilled = _isFulfilled;
        
        print('Checking order $currentIndex - confirmed: ${order['confirmed']}, preparing: ${order['preparing']}, cooked: ${order['cooked']}, fulfilled: ${order['fulfilled']}');
        
        setState(() {
          _isConfirmed = order['confirmed'] == true;
          _isPreparing = order['preparing'] == true;
          _isCooked = order['cooked'] == true;
          _isFulfilled = order['fulfilled'] == true;
          
          // Store confirmedAt from server if it exists and we don't have it locally
          if (order['confirmedAt'] != null && widget.order['confirmedAt'] == null) {
            widget.order['confirmedAt'] = order['confirmedAt'];
            print('Stored confirmedAt from server: ${order['confirmedAt']}');
          }
          
          print('Current confirmedAt: ${widget.order['confirmedAt']}');
          
          // Always recalculate step to check if 1 minute has passed
          final newStep = _getOrderStep();
          final stepChanged = newStep != _currentStep;
          
          // Update step if status changed OR if step calculation changed (e.g., 1 min passed)
          if (_isConfirmed != wasConfirmed || _isPreparing != wasPreparing || _isCooked != wasCooked || _isFulfilled != wasFulfilled || stepChanged) {
            if (stepChanged) {
              print('Step changed from $_currentStep to $newStep');
            }
            print('Status changed! confirmed: $_isConfirmed, preparing: $_isPreparing, cooked: $_isCooked, fulfilled: $_isFulfilled');
            _isAnimating = true;
            _currentStep = newStep;
            _updateEstimatedTime();
            
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _isAnimating = false);
            });
          }
        });
      }
    } catch (e) {
      // Silently handle error
    }
  }

  void _updateEstimatedTime() {
    switch (_currentStep) {
      case 1:
        _estimatedTime = '20-25 min';
        break;
      case 2:
        _estimatedTime = '12-15 min';
        break;
      case 3:
        _estimatedTime = '5-8 min';
        break;
      case 4:
        _estimatedTime = 'Arriving now!';
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.orange,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Order Status'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Icon(
                      _currentStep == 4 ? Icons.check_circle : Icons.local_shipping,
                      size: 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildStatusTimeline(),
                  const SizedBox(height: 20),
                  _buildDriverCard(),
                  const SizedBox(height: 20),
                  _buildOrderDetailsCard(),
                  const SizedBox(height: 20),
                  _buildItemsCard(),
                  if (!_isConfirmed) ...[
                    const SizedBox(height: 20),
                    _buildDeleteOrderButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildStatusTimeline() {
    // Calculate times for each status
    String getStatusTime(int stepIndex) {
      try {
        DateTime? statusTime;
        
        switch (stepIndex) {
          case 0:
            statusTime = DateTime.parse(widget.order['timestamp'] ?? DateTime.now().toIso8601String());
            break;
          case 1:
            if (widget.order['confirmedAt'] != null) {
              statusTime = DateTime.parse(widget.order['confirmedAt']);
            }
            break;
          case 2:
            if (widget.order['preparingAt'] != null) {
              statusTime = DateTime.parse(widget.order['preparingAt']);
            }
            break;
          case 3:
            if (widget.order['cookedAt'] != null) {
              statusTime = DateTime.parse(widget.order['cookedAt']);
            }
            break;
          case 4:
            if (widget.order['fulfilledAt'] != null) {
              statusTime = DateTime.parse(widget.order['fulfilledAt']);
            }
            break;
        }
        
        if (statusTime == null) return 'Pending';
        
        final now = DateTime.now();
        final difference = now.difference(statusTime);
        
        if (difference.inSeconds < 60) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} min ago';
        } else if (difference.inHours < 24) {
          return '${difference.inHours} hour ago';
        } else {
          return '${difference.inDays} day ago';
        }
      } catch (e) {
        return 'Pending';
      }
    }

    final steps = [
      {'label': 'Order Placed', 'icon': Icons.receipt_long},
      {'label': 'Confirmed', 'icon': Icons.check_circle_outline},
      {'label': 'Preparing', 'icon': Icons.restaurant},
      {'label': 'Out for Delivery', 'icon': Icons.delivery_dining},
      {'label': 'Delivered', 'icon': Icons.home},
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(steps.length, (index) {
            final step = steps[index];
            final isActive = index <= _currentStep;
            final isCurrent = index == _currentStep;
            final isLast = index == steps.length - 1;

            return Column(
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isActive
                            ? LinearGradient(
                                colors: [Colors.orange[400]!, Colors.orange[600]!],
                              )
                            : null,
                        color: isActive ? null : Colors.grey[300],
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        color: isActive ? Colors.white : Colors.grey[600],
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['label'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            getStatusTime(index),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent && index < 4)
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'In Progress',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isLast)
                  Container(
                    margin: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
                    height: 40,
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [Colors.orange[400]!, Colors.orange[200]!]
                            : [Colors.grey[300]!, Colors.grey[300]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDriverCard() {
    if (_currentStep < 3) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange[100],
              child: const Icon(Icons.person, size: 32, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Delivery Driver',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Andreas M.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('4.8', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      Text('• 250+ deliveries', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling driver...'), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.location_on, 'Address', widget.order['deliveryAddress'] ?? 'Selected location'),
            _buildDetailRow(Icons.payment, 'Payment', widget.order['paymentMethod'] ?? 'Cash on Delivery'),
            _buildDetailRow(Icons.access_time, 'Order Time', widget.order['orderTime'] ?? DateTime.now().toString().substring(11, 16)),
            _buildDetailRow(Icons.person, 'Customer', widget.order['customerName'] ?? widget.order['userName'] ?? 'Guest'),
            if (widget.order['userName'] != null && widget.order['userName'].toString().isNotEmpty)
              _buildDetailRow(Icons.badge, 'Name', widget.order['userName']),
            if (widget.order['userEmail'] != null && widget.order['userEmail'].toString().isNotEmpty)
              _buildDetailRow(Icons.email, 'Email', widget.order['userEmail']),
            if (widget.order['userPhone'] != null && widget.order['userPhone'].toString().isNotEmpty)
              _buildDetailRow(Icons.phone, 'Phone', widget.order['userPhone']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final burgerOrders = (widget.order['burgerOrders'] as List?) ?? [];
    final friesCount = widget.order['friesCount'] ?? 0;
    final colaCount = widget.order['colaCount'] ?? 0;
    final colaZeroCount = widget.order['colaZeroCount'] ?? 0;
    final pepsiCount = widget.order['pepsiCount'] ?? 0;
    final pepsiZeroCount = widget.order['pepsiZeroCount'] ?? 0;
    final fantaCount = widget.order['fantaCount'] ?? 0;
    final spriteCount = widget.order['spriteCount'] ?? 0;
    final spriteZeroCount = widget.order['spriteZeroCount'] ?? 0;
    final waterCount = widget.order['waterCount'] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...burgerOrders.asMap().entries.map((entry) {
              final index = entry.key;
              final burger = entry.value;
              return _buildBurgerItem(index + 1, burger);
            }).toList(),
            if (friesCount > 0) _buildItemRow('🍟', 'French Fries', friesCount),
            if (colaCount > 0) _buildItemRow('🥤', 'Coca Cola', colaCount),
            if (colaZeroCount > 0) _buildItemRow('🥤', 'Coca Cola Zero', colaZeroCount),
            if (pepsiCount > 0) _buildItemRow('🥤', 'Pepsi', pepsiCount),
            if (pepsiZeroCount > 0) _buildItemRow('🥤', 'Pepsi Zero', pepsiZeroCount),
            if (fantaCount > 0) _buildItemRow('🧃', 'Fanta', fantaCount),
            if (spriteCount > 0) _buildItemRow('🥤', 'Sprite', spriteCount),
            if (spriteZeroCount > 0) _buildItemRow('🥤', 'Sprite Zero', spriteZeroCount),
            if (waterCount > 0) _buildItemRow('💧', 'Water', waterCount),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '€${widget.order['totalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(String emoji, String name, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'x$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurgerItem(int number, Map<String, dynamic> burger) {
    final ingredients = burger['ingredients'] as Map<String, dynamic>? ?? {};
    
    // Determine if it's a classic or custom burger
    final isClassic = burger['type'] == 'classic';
    final burgerName = isClassic ? 'Classic Burger' : 'Custom Burger';
    
    // Extract active ingredients based on burger type
    List<String> activeIngredients = [];
    if (isClassic) {
      // Classic burger: ingredients are stored as {'Mayo': true, 'Lettuce': true}
      activeIngredients = ingredients.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
    } else {
      // Custom burger: ingredients are stored as {'Mayo': {'included': true, 'type': 'checkbox'}, 'Cheese': {'quantity': 2, 'type': 'quantity'}}
      activeIngredients = ingredients.entries
          .where((e) {
            if (e.value is Map<String, dynamic>) {
              final ingredientData = e.value as Map<String, dynamic>;
              if (ingredientData['type'] == 'checkbox') {
                return ingredientData['included'] == true;
              } else if (ingredientData['type'] == 'quantity') {
                return (ingredientData['quantity'] ?? 0) > 0;
              }
            }
            return false;
          })
          .map((e) {
            // For quantity items, show the quantity
            if (e.value is Map<String, dynamic>) {
              final ingredientData = e.value as Map<String, dynamic>;
              if (ingredientData['type'] == 'quantity' && (ingredientData['quantity'] ?? 0) > 1) {
                return '${e.key} (${ingredientData['quantity']})';
              }
            }
            return e.key;
          })
          .toList();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍔', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(
                '$burgerName #$number',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          if (activeIngredients.isNotEmpty) const SizedBox(height: 12),
          if (activeIngredients.isNotEmpty) const Text(
            'Ingredients:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (activeIngredients.isNotEmpty) const SizedBox(height: 8),
          if (activeIngredients.isNotEmpty) Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeIngredients.map((ingredient) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!, width: 1),
                ),
                child: Text(
                  ingredient,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[800],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteOrderButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.delete_outline, size: 40, color: Colors.red[400]),
          const SizedBox(height: 10),
          const Text(
            'Need to cancel?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can cancel this order before it is confirmed',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _deleteOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/api/orders/cancel/${widget.order['timestamp']}'),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // Call the callback to notify parent
          if (widget.onOrderDeleted != null) {
            widget.onOrderDeleted!();
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          
          // Wait for the deletion to be processed
          await Future.delayed(const Duration(milliseconds: 800));
          
          if (mounted) {
            // Pop back - the sync in multi_order_status_page will handle the removal
            Navigator.of(context).pop(true);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error cancelling order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
