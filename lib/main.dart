import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'order_status_page.dart';
import 'multi_order_status_page.dart';
import 'auth_page.dart';

// Navigation bar widget
class AppNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final bool showOrderStatus;
  final void Function(int) onTap;
  const AppNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onTap,
    this.showOrderStatus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<_NavTab> tabs = [
      _NavTab('Home', Icons.home),
      _NavTab('Order', Icons.fastfood),
      _NavTab('Status', Icons.assignment_turned_in),
    ];
    return Container(
      color: Colors.orange[50],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final bool selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.orange : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.orange.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 2))]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, color: selected ? Colors.white : Colors.orange, size: 22),
                    const SizedBox(height: 2),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  _NavTab(this.label, this.icon);
}

class MainNavigationController extends StatefulWidget {
  @override
  State<MainNavigationController> createState() => _MainNavigationControllerState();
}

class _MainNavigationControllerState extends State<MainNavigationController> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allOrders = [];
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String? _authToken;
  String? _userId;
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name');
    final userEmail = prefs.getString('user_email');
    final userPhone = prefs.getString('user_phone');
    
    setState(() {
      _authToken = token;
      _userId = userId;
      _userName = userName ?? '';
      _userEmail = userEmail ?? '';
      _userPhone = userPhone ?? '';
      _isAuthenticated = token != null;
      _isCheckingAuth = false;
    });
    
    if (_isAuthenticated) {
      await _loadOrdersFromServer();
    }
  }

  Future<void> _loadOrdersFromServer() async {
    try {
      // Use non-authenticated endpoint with user identifiers (works even if token is invalid)
      final queryParams = {
        if (_userId != null) 'userId': _userId!,
        if (_userEmail.isNotEmpty) 'email': _userEmail,
        if (_userPhone.isNotEmpty) 'phone': _userPhone,
      };
      
      if (queryParams.isNotEmpty) {
        final uri = Uri.parse('${OrdersHistory.serverUrl}/api/orders/by-user')
            .replace(queryParameters: queryParams);
        
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> orders = json.decode(response.body);
          setState(() {
            _allOrders = orders.cast<Map<String, dynamic>>();
          });
          print('✓ Loaded ${_allOrders.length} orders from server');
          return;
        } else {
          print('Failed to load orders: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error loading orders: $e');
    }
  }

  Future<void> _handleAuthSuccess(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', user['id']);
    await prefs.setString('user_name', user['name']);
    await prefs.setString('user_email', user['email']);
    await prefs.setString('user_phone', user['phone']);
    
    setState(() {
      _authToken = token;
      _userId = user['id'];
      _userName = user['name'];
      _userEmail = user['email'];
      _userPhone = user['phone'];
      _isAuthenticated = true;
    });
    
    await _loadOrdersFromServer();
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    
    setState(() {
      _authToken = null;
      _userId = null;
      _userName = '';
      _userEmail = '';
      _userPhone = '';
      _isAuthenticated = false;
      _allOrders = [];
    });
  }

  void _onNavTap(int idx) {
    setState(() {
      _selectedIndex = idx;
    });
    // Reload orders when navigating to status page
    if (idx == 2) {
      _loadOrdersFromServer();
    }
  }

  void _onOrderPlaced(Map<String, dynamic> order) {
    setState(() {
      _allOrders.add(order);
      _selectedIndex = 2; // Go to status
    });
    // Wait a bit before reloading to ensure server has processed the order
    Future.delayed(Duration(seconds: 1), () {
      _loadOrdersFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking authentication
    if (_isCheckingAuth) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }
    
    // Show auth page if not authenticated
    if (!_isAuthenticated) {
      return AuthPage(
        onAuthSuccess: _handleAuthSuccess,
      );
    }
    
    Widget page;
    if (_selectedIndex == 0) {
      page = HomePage(
        onOrderTap: () => setState(() => _selectedIndex = 1),
        userName: _userName,
        userEmail: _userEmail,
        onLogout: _handleLogout,
        onUserInfoUpdate: (name, email, phone) {
          // Not needed anymore since we use auth
        },
      );
    } else if (_selectedIndex == 1) {
      page = BurgerOrderPage(
        onOrderPlaced: _onOrderPlaced,
        userName: _userName,
        userEmail: _userEmail,
        userPhone: _userPhone,
        authToken: _authToken,
        userId: _userId,
      );
    } else {
      page = MultiOrderStatusPage(orders: _allOrders);
    }
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            AppNavigationBar(
              selectedIndex: _selectedIndex,
              showOrderStatus: true, // Always show status tab
              onTap: (i) {
                _onNavTap(i);
              },
            ),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }
}

// Global cart state
class CartState {
  static final CartState _instance = CartState._internal();
  factory CartState() => _instance;
  CartState._internal();

  int burgerCount = 0;
  int customBurgerCount = 0;
  int friesCount = 0;
  int colaCount = 0;
  int fantaCount = 0;
  int waterCount = 0;
  List<Map<String, dynamic>> burgerOrders = [];  // Classic burgers
  List<Map<String, dynamic>> customBurgerOrders = [];  // Custom burgers

  void reset() {
    burgerCount = 0;
    customBurgerCount = 0;
    friesCount = 0;
    colaCount = 0;
    fantaCount = 0;
    waterCount = 0;
    burgerOrders = [];
    customBurgerOrders = [];
  }
}

// Global orders history
class OrdersHistory {
  static final OrdersHistory _instance = OrdersHistory._internal();
  factory OrdersHistory() => _instance;
  OrdersHistory._internal();

  List<Map<String, dynamic>> allOrders = [];
  
  // Production backend URL
  static String get serverUrl => 'https://burger-backend-rxwl.onrender.com';

  Future<void> addOrder(Map<String, dynamic> order, {String? authToken}) async {
    allOrders.add(order);
    final success = await _sendToServer(order, authToken: authToken);
    if (!success) {
      print('Warning: Order saved locally but failed to sync to server');
    }
  }

  void clearHistory() {
    allOrders.clear();
  }

  Future<bool> _sendToServer(Map<String, dynamic> order, {String? authToken}) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/orders'),
        headers: headers,
        body: json.encode(order),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending order to server: $e');
      return false;
    }
  }
}

void main() {
  runApp(const BurgerApp());
}

class BurgerApp extends StatelessWidget {
  const BurgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'burgercy.com',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: MainNavigationController(),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback? onOrderTap;
  final String userName;
  final String userEmail;
  final VoidCallback? onLogout;
  final void Function(String name, String email, String phone)? onUserInfoUpdate;
  
  const HomePage({
    super.key, 
    this.onOrderTap, 
    this.onUserInfoUpdate,
    this.userName = '',
    this.userEmail = '',
    this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, String> _openingHours = {};
  bool _isLoadingHours = true;
  bool _isHoursExpanded = false;
  static const String serverUrl = 'https://burger-backend-rxwl.onrender.com';
  
  @override
  void initState() {
    super.initState();
    _fetchOpeningHours();
  }

  Future<void> _fetchOpeningHours() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/opening-hours'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> hours = json.decode(response.body);
        setState(() {
          _openingHours = hours.map((key, value) => MapEntry(key, value.toString()));
          _isLoadingHours = false;
        });
      } else {
        setState(() => _isLoadingHours = false);
      }
    } catch (e) {
      setState(() => _isLoadingHours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (widget.onLogout != null) {
                          widget.onLogout!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.userName}!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoadingHours)
              const Center(child: CircularProgressIndicator(color: Colors.orange))
            else if (_openingHours.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHoursExpanded = !_isHoursExpanded;
                  });
                },
                child: Row(
                  children: [
                    const Text(
                      'Opening Hours',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _isHoursExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isHoursExpanded) ...[
                const SizedBox(height: 15),
                ..._openingHours.entries.map((entry) {
                  final day = entry.key[0].toUpperCase() + entry.key.substring(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class BurgerOrderPage extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onOrderPlaced;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? authToken;
  final String? userId;
  
  const BurgerOrderPage({
    super.key,
    this.onOrderPlaced,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.authToken,
    this.userId,
  });

  @override
  State<BurgerOrderPage> createState() => _BurgerOrderPageState();
}

class _BurgerOrderPageState extends State<BurgerOrderPage> {
  String selectedCategory = 'Burgers';
  final CartState _cart = CartState();

  // Item prices
  final double burgerPrice = 14.99;
  final double customBurgerPrice = 7.99;
  final double friesPrice = 3.99;
  final double colaPrice = 2.49;
  final double fantaPrice = 2.49;
  final double waterPrice = 1.99;

  double get totalPrice {
    return (_cart.burgerCount * burgerPrice) +
        (_cart.customBurgerCount * customBurgerPrice) +
        (_cart.friesCount * friesPrice) +
        (_cart.colaCount * colaPrice) +
        (_cart.fantaCount * fantaPrice) +
        (_cart.waterCount * waterPrice);
  }

  int get totalItems {
    return _cart.burgerCount + _cart.customBurgerCount + _cart.friesCount + _cart.colaCount + _cart.fantaCount + _cart.waterCount;
  }

  void viewCart() {
    if (totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty!')),
      );
      return;
    }

    // Combine classic and custom burger orders for the cart
    final allBurgerOrders = [
      ..._cart.burgerOrders.map((b) => {...b, 'type': 'classic'}),
      ..._cart.customBurgerOrders.map((b) => {...b, 'type': 'custom'}),
    ];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartPage(
          burgerOrders: allBurgerOrders,
          friesCount: _cart.friesCount,
          colaCount: _cart.colaCount,
          fantaCount: _cart.fantaCount,
          waterCount: _cart.waterCount,
          burgerPrice: burgerPrice,
          friesPrice: friesPrice,
          colaPrice: colaPrice,
          fantaPrice: fantaPrice,
          waterPrice: waterPrice,
          totalPrice: totalPrice,
          userName: widget.userName,
          userEmail: widget.userEmail,
          userPhone: widget.userPhone,
          userId: widget.userId,
          authToken: widget.authToken,
          onOrderPlaced: (order) {
            setState(() {
              _cart.reset();
            });
            if (widget.onOrderPlaced != null) {
              widget.onOrderPlaced!(order);
            }
          },
        ),
      ),
    );
  }

  void _showBurgerCustomization() {
    Map<String, bool> ingredients = {
      'Mayo': true,
      'Ketchup': true,
      'Lettuce': true,
      'Tomato': true,
      'Pickle Cucumber': true,
      'Onion': true,
      'Bacon': true,
      'Egg': true,
      'Beef Patty': true,
      'Extra Patty': false,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BurgerCustomizationPage(
          ingredients: ingredients,
          onAdd: (customizedIngredients) {
            setState(() {
              _cart.customBurgerCount++;
              _cart.customBurgerOrders.add({
                'ingredients': Map<String, bool>.from(customizedIngredients),
              });
            });
          },
        ),
      ),
    );
  }

  Widget _buildBurgerCard() {
    final defaultIngredients = [
      'Mayo',
      'Ketchup',
      'Lettuce',
      'Tomato',
      'Pickle Cucumber',
      'Onion',
      'Bacon',
      'Egg',
      'Beef Patty'
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/burger.jpg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.fastfood,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classic Burger',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€${burgerPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Counter controls
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (_cart.burgerCount > 0) {
                            _cart.burgerCount--;
                            if (_cart.burgerOrders.isNotEmpty) {
                              _cart.burgerOrders.removeLast();
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      iconSize: 28,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_cart.burgerCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Add default burger
                        setState(() {
                          _cart.burgerCount++;
                          _cart.burgerOrders.add({
                            'ingredients': {
                              'Mayo': true,
                              'Ketchup': true,
                              'Lettuce': true,
                              'Tomato': true,
                              'Pickle Cucumber': true,
                              'Onion': true,
                              'Bacon': true,
                              'Egg': true,
                              'Beef Patty': true,
                            },
                          });
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      iconSize: 28,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingredients:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              defaultIngredients.join(', '),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBurgerCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.orange[100],
                    child: Icon(
                      Icons.edit_note,
                      size: 40,
                      color: Colors.orange[600],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Burger',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€${customBurgerPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Build your own burger',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Counter controls
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (_cart.customBurgerCount > 0) {
                            _cart.customBurgerCount--;
                            if (_cart.customBurgerOrders.isNotEmpty) {
                              _cart.customBurgerOrders.removeLast();
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      iconSize: 28,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_cart.customBurgerCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showBurgerCustomization,
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      iconSize: 28,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showBurgerCustomization,
                icon: const Icon(Icons.edit),
                label: const Text('Customize Burger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🍔 burgercy.com'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, size: 32),
                  onPressed: () {
                    viewCart();
                  },
                ),
                if (totalItems > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$totalItems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Navigation Menu
          Container(
            height: 60,
            color: Colors.orange[50],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                _buildNavButton('Burgers'),
                _buildNavButton('Sides'),
                _buildNavButton('Drinks'),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildItems(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '€${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: viewCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'See Order',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItems() {
    switch (selectedCategory) {
      case 'Burgers':
        return [
          _buildBurgerCard(),
          const SizedBox(height: 16),
          _buildCustomBurgerCard(),
        ];
      case 'Sides':
        return [
          _buildItemCard(
            'French Fries',
            friesPrice,
            _cart.friesCount,
            'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400',
            () => setState(() => _cart.friesCount++),
            () => setState(
                () => _cart.friesCount = _cart.friesCount > 0 ? _cart.friesCount - 1 : 0),
          ),
        ];
      case 'Drinks':
        return [
          _buildItemCard(
            'Coca Cola',
            colaPrice,
            _cart.colaCount,
            'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400',
            () => setState(() => _cart.colaCount++),
            () => setState(() => _cart.colaCount = _cart.colaCount > 0 ? _cart.colaCount - 1 : 0),
          ),
          const SizedBox(height: 16),
          _buildItemCard(
            'Fanta',
            fantaPrice,
            _cart.fantaCount,
            'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=400',
            () => setState(() => _cart.fantaCount++),
            () => setState(
                () => _cart.fantaCount = _cart.fantaCount > 0 ? _cart.fantaCount - 1 : 0),
          ),
          const SizedBox(height: 16),
          _buildItemCard(
            'Water',
            waterPrice,
            _cart.waterCount,
            'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400',
            () => setState(() => _cart.waterCount++),
            () => setState(
                () => _cart.waterCount = _cart.waterCount > 0 ? _cart.waterCount - 1 : 0),
          ),
        ];
      default:
        return [
          Center(
            child: Text(
              'No items available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildItemCard(
    String name,
    double price,
    int count,
    String imageUrl,
    VoidCallback onAdd,
    VoidCallback onRemove,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.fastfood,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Counter controls
            Row(
              children: [
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  iconSize: 28,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green,
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(String category) {
    final bool isSelected = selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedCategory = category;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.orange : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: isSelected ? 4 : 1,
        ),
        child: Text(
          category,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> burgerOrders;
  final int friesCount;
  final int colaCount;
  final int fantaCount;
  final int waterCount;
  final double burgerPrice;
  final double friesPrice;
  final double colaPrice;
  final double fantaPrice;
  final double waterPrice;
  final double totalPrice;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? userId;
  final String? authToken;
  final void Function(Map<String, dynamic>)? onOrderPlaced;

  const CartPage({
    super.key,
    required this.burgerOrders,
    required this.friesCount,
    required this.colaCount,
    required this.fantaCount,
    required this.waterCount,
    required this.burgerPrice,
    required this.friesPrice,
    required this.colaPrice,
    required this.fantaPrice,
    required this.waterPrice,
    required this.totalPrice,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.onOrderPlaced,
    this.userId,
    this.authToken,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Payment method
  String _selectedPaymentMethod = 'Cash on Delivery';
  
  // Discount code
  final TextEditingController _discountCodeController = TextEditingController();
  String _discountMessage = '';
  double _discountAmount = 0.0;
  bool _discountApplied = false;
  
  // Loading state to prevent duplicate orders
  bool _isPlacingOrder = false;
  
  @override
  void dispose() {
    _discountCodeController.dispose();
    super.dispose();
  }
  
  void _editCustomBurger(int index, Map<String, dynamic> order) {
    final currentIngredients = Map<String, bool>.from(order['ingredients'] as Map<String, bool>);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BurgerCustomizationPage(
          ingredients: currentIngredients,
          isEditing: true,
          onAdd: (updatedIngredients) {
            setState(() {
              // Update the burger in the list
              widget.burgerOrders[index]['ingredients'] = Map<String, bool>.from(updatedIngredients);
            });
          },
        ),
      ),
    );
  }
  
  Future<void> _applyDiscountCode() async {
    final code = _discountCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _discountMessage = 'Please enter a discount code';
        _discountAmount = 0.0;
        _discountApplied = false;
      });
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse('${OrdersHistory.serverUrl}/api/validate-discount'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _discountApplied = true;
            _discountAmount = (widget.totalPrice * data['discountPercent'] / 100);
            _discountMessage = '✓ ${data['discountPercent']}% discount applied!';
          });
        } else {
          setState(() {
            _discountApplied = false;
            _discountAmount = 0.0;
            _discountMessage = data['message'] ?? 'Invalid discount code';
          });
        }
      } else {
        setState(() {
          _discountApplied = false;
          _discountAmount = 0.0;
          _discountMessage = 'Invalid discount code';
        });
      }
    } catch (e) {
      setState(() {
        _discountApplied = false;
        _discountAmount = 0.0;
        _discountMessage = 'Error validating code';
      });
    }
  }
  
  void _removeDiscount() {
    setState(() {
      _discountCodeController.clear();
      _discountApplied = false;
      _discountAmount = 0.0;
      _discountMessage = '';
    });
  }

  Future<void> _handlePlaceOrder() async {
    // Prevent duplicate submissions
    if (_isPlacingOrder) return;
    
    setState(() {
      _isPlacingOrder = true;
    });
    
    // Check if store is open before placing order
    try {
      final response = await http.get(Uri.parse('${OrdersHistory.serverUrl}/api/is-open'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['isOpen'] == false) {
          // Show error dialog if store is closed
          setState(() {
            _isPlacingOrder = false;
          });
          
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 30),
                    SizedBox(width: 10),
                    Text('Store Closed'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['message'] ?? 'Store is currently closed',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Please place your order during opening hours.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      // If check fails, proceed anyway (don't block orders on network error)
      print('Failed to check store hours: $e');
    }
    
    _completeOrder();
  }

  void _completeOrder() {
    final finalPrice = widget.totalPrice - _discountAmount;
    final order = {
      'timestamp': DateTime.now().toString(),
      'burgerOrders': List.from(widget.burgerOrders),
      'friesCount': widget.friesCount,
      'colaCount': widget.colaCount,
      'fantaCount': widget.fantaCount,
      'waterCount': widget.waterCount,
      'totalPrice': finalPrice,
      'originalPrice': widget.totalPrice,
      'discountAmount': _discountAmount,
      'discountCode': _discountApplied ? _discountCodeController.text.trim().toUpperCase() : null,
      'paymentMethod': _selectedPaymentMethod,
      'userName': widget.userName,
      'userEmail': widget.userEmail,
      'userPhone': widget.userPhone,
      'userId': widget.userId,
    };
    OrdersHistory().addOrder(order, authToken: widget.authToken);

    if (widget.onOrderPlaced != null) {
      widget.onOrderPlaced!(order);
    }
    
    // Reset loading state
    setState(() {
      _isPlacingOrder = false;
    });
    
    // Navigate back and show success message
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Order placed!\n💳 Payment: $_selectedPaymentMethod'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🛒 Your Cart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Payment Method
                Row(
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.money,
                      color: Colors.green,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Η παραγγελία θα πληρώνεται στο σημείο παράδοσης με μετρητά ή μέσω Revolut.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Delivery Location
                Row(
                  children: [
                    const Text(
                      'Delivery Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/delivery_location.jpg',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Η τοποθεσία παραλαβής των παραγγελιών θα είναι αποκλειστικά μπροστά από τις Εστίες apolonia',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Order Header
                const Text(
                  'Order',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                // Discount Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_offer, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Discount Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCodeController,
                              decoration: InputDecoration(
                                hintText: 'Enter code',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              enabled: !_discountApplied,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_discountApplied)
                            ElevatedButton(
                              onPressed: _applyDiscountCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Apply'),
                            )
                          else
                            IconButton(
                              onPressed: _removeDiscount,
                              icon: const Icon(Icons.close),
                              color: Colors.red,
                            ),
                        ],
                      ),
                      if (_discountMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _discountMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: _discountApplied ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Burgers
                if (widget.burgerOrders.isNotEmpty) ...[
                  const Text(
                    '🍔 Burgers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.burgerOrders.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> order = entry.value;
                    Map<String, bool> ingredients =
                        order['ingredients'] as Map<String, bool>;
                    List<String> selectedIngredients = ingredients.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();

                    // Determine if it's a classic or custom burger
                    final isClassic = order['type'] == 'classic';
                    final burgerName = isClassic ? 'Classic Burger' : 'Custom Burger';
                    final burgerPriceValue = isClassic ? widget.burgerPrice : 7.99;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$burgerName #${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (!isClassic)
                                      IconButton(
                                        onPressed: () => _editCustomBurger(index, order),
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: Colors.red,
                                        tooltip: 'Edit burger',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '€${burgerPriceValue.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: selectedIngredients.map((ingredient) {
                                return Chip(
                                  label: Text(
                                    ingredient,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.orange[100],
                                  padding: const EdgeInsets.all(2),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                ],
                // Other items
                if (widget.friesCount > 0)
                  _buildCartItem('French Fries', widget.friesCount, widget.friesPrice),
                if (widget.colaCount > 0)
                  _buildCartItem('Coca Cola', widget.colaCount, widget.colaPrice),
                if (widget.fantaCount > 0)
                  _buildCartItem('Fanta', widget.fantaCount, widget.fantaPrice),
                if (widget.waterCount > 0)
                  _buildCartItem('Water', widget.waterCount, widget.waterPrice),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_discountApplied) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '€${widget.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Discount:',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '-€${_discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '€${(widget.totalPrice - _discountAmount).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isPlacingOrder ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      'Edit Order',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPlacingOrder ? null : () => _handlePlaceOrder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isPlacingOrder
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Placing Order...',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          )
                        : const Text(
                            'Place Order',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String name, int count, double price) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${price.toStringAsFixed(2)} each',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'x$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '€${(price * count).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
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
}

class BurgerCustomizationPage extends StatefulWidget {
  final Map<String, bool> ingredients;
  final Function(Map<String, bool>) onAdd;
  final bool isEditing;

  const BurgerCustomizationPage({
    super.key,
    required this.ingredients,
    required this.onAdd,
    this.isEditing = false,
  });

  @override
  State<BurgerCustomizationPage> createState() =>
      _BurgerCustomizationPageState();
}

class _BurgerCustomizationPageState extends State<BurgerCustomizationPage> {
  late Map<String, bool> _ingredients;

  @override
  void initState() {
    super.initState();
    _ingredients = Map<String, bool>.from(widget.ingredients);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🍔 Customize Your Burger'),
      ),
      body: Column(
        children: [
          // Remove Ingredients Header
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            child: const Text(
              'Remove Ingredients',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Select ingredients for your burger:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._ingredients.keys.map((ingredient) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      title: Text(
                        ingredient,
                        style: const TextStyle(fontSize: 16),
                      ),
                      value: _ingredients[ingredient],
                      onChanged: (value) {
                        setState(() {
                          _ingredients[ingredient] = value ?? false;
                        });
                      },
                      activeColor: Colors.orange,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onAdd(_ingredients);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.isEditing 
                        ? '✓ Burger updated!' 
                        : '✓ Customized burger added to cart!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.isEditing ? 'Save Changes' : 'Add to Cart',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


