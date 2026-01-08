import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'order_status_page.dart';
import 'multi_order_status_page.dart';

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
      if (showOrderStatus) _NavTab('Status', Icons.assignment_turned_in),
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

  void _onNavTap(int idx) {
    setState(() {
      _selectedIndex = idx;
    });
  }

  void _onOrderPlaced(Map<String, dynamic> order) {
    setState(() {
      _allOrders.add(order);
      _selectedIndex = 2; // Go to status
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (_selectedIndex == 0) {
      page = HomePage(
        onOrderTap: () => setState(() => _selectedIndex = 1),
        onUserInfoUpdate: (name, email, phone) {
          setState(() {
            _userName = name;
            _userEmail = email;
            _userPhone = phone;
          });
        },
      );
    } else if (_selectedIndex == 1) {
      page = BurgerOrderPage(
        onOrderPlaced: _onOrderPlaced,
        userName: _userName,
        userEmail: _userEmail,
        userPhone: _userPhone,
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
              showOrderStatus: _allOrders.isNotEmpty,
              onTap: (i) {
                if (i == 2 && _allOrders.isEmpty) return;
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
  int friesCount = 0;
  int colaCount = 0;
  int fantaCount = 0;
  int waterCount = 0;
  List<Map<String, dynamic>> burgerOrders = [];

  void reset() {
    burgerCount = 0;
    friesCount = 0;
    colaCount = 0;
    fantaCount = 0;
    waterCount = 0;
    burgerOrders = [];
  }
}

// Global orders history
class OrdersHistory {
  static final OrdersHistory _instance = OrdersHistory._internal();
  factory OrdersHistory() => _instance;
  OrdersHistory._internal();

  List<Map<String, dynamic>> allOrders = [];
  
  // For web: use localhost, for Android emulator: use 10.0.2.2
  static String get serverUrl => kIsWeb ? 'http://192.168.10.6:8000' : 'http://10.0.2.2:8000';

  Future<void> addOrder(Map<String, dynamic> order) async {
    allOrders.add(order);
    await _sendToServer(order);
  }

  void clearHistory() {
    allOrders.clear();
  }

  Future<void> _sendToServer(Map<String, dynamic> order) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(order),
      );
    } catch (e) {
      // Silently fail
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
      title: 'Burger Ordering App',
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
  final void Function(String name, String email, String phone)? onUserInfoUpdate;
  const HomePage({super.key, this.onOrderTap, this.onUserInfoUpdate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool hasUserInfo = false;
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name');
    final savedEmail = prefs.getString('user_email');
    final savedPhone = prefs.getString('user_phone');
    
    if (savedName != null && savedEmail != null && savedPhone != null) {
      setState(() {
        hasUserInfo = true;
        userName = savedName;
        userEmail = savedEmail;
        userPhone = savedPhone;
      });
      
      // Notify parent widget
      if (widget.onUserInfoUpdate != null) {
        widget.onUserInfoUpdate!(savedName, savedEmail, savedPhone);
      }
    } else {
      // Show dialog to collect user info
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUserInfoDialog();
      });
    }
  }
  
  Future<void> _saveUserInfo(String name, String email, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
  }
  
  void _showUserInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome! 👋'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide your contact information to get started:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Cyprus)',
                hintText: '97643172',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 8,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final email = _emailController.text.trim();
              final phone = _phoneController.text.trim();
              
              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (!email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (phone.length != 8 || !phone.startsWith('9')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid Cyprus phone number (8 digits, starting with 9)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              setState(() {
                hasUserInfo = true;
                userName = name;
                userEmail = email;
                userPhone = phone;
              });
              
              _saveUserInfo(name, email, phone);
              
              // Notify parent widget
              if (widget.onUserInfoUpdate != null) {
                widget.onUserInfoUpdate!(name, email, phone);
              }
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Information saved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }











  void _showEditAccountDialog() {
    final nameController = TextEditingController(text: userName);
    final emailController = TextEditingController(text: userEmail);
    final phoneController = TextEditingController(text: userPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: Colors.orange),
            SizedBox(width: 10),
            Text('Account Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.isEmpty || email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid name and email'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (phone.length != 8 || !phone.startsWith('9')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid Cyprus phone number (8 digits, starting with 9)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              setState(() {
                userName = name;
                userEmail = email;
                userPhone = phone;
              });
              
              _saveUserInfo(name, email, phone);
              
              // Notify parent widget
              if (widget.onUserInfoUpdate != null) {
                widget.onUserInfoUpdate!(name, email, phone);
              }
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Account updated!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        actions: [
          if (hasUserInfo)
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
              onPressed: _showEditAccountDialog,
              tooltip: 'Account',
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🍔',
                style: TextStyle(fontSize: 100),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Burger App',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Delicious burgers made fresh!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: widget.onOrderTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  'Order Here',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
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
  const BurgerOrderPage({
    super.key,
    this.onOrderPlaced,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<BurgerOrderPage> createState() => _BurgerOrderPageState();
}

class _BurgerOrderPageState extends State<BurgerOrderPage> {
  String selectedCategory = 'Burgers';
  final CartState _cart = CartState();

  // Item prices
  final double burgerPrice = 7.99;
  final double friesPrice = 3.99;
  final double colaPrice = 2.49;
  final double fantaPrice = 2.49;
  final double waterPrice = 1.99;

  double get totalPrice {
    return (_cart.burgerCount * burgerPrice) +
        (_cart.friesCount * friesPrice) +
        (_cart.colaCount * colaPrice) +
        (_cart.fantaCount * fantaPrice) +
        (_cart.waterCount * waterPrice);
  }

  int get totalItems {
    return _cart.burgerCount + _cart.friesCount + _cart.colaCount + _cart.fantaCount + _cart.waterCount;
  }

  void viewCart() {
    if (totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartPage(
          burgerOrders: _cart.burgerOrders,
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
              _cart.burgerCount++;
              _cart.burgerOrders.add({
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
                        '\$${burgerPrice.toStringAsFixed(2)}',
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
        title: const Text('🍔 Burger Ordering'),
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
                            '\$${totalPrice.toStringAsFixed(2)}',
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
                    '\$${price.toStringAsFixed(2)}',
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
  
  @override
  void dispose() {
    _discountCodeController.dispose();
    super.dispose();
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
    };
    OrdersHistory().addOrder(order);

    if (widget.onOrderPlaced != null) {
      widget.onOrderPlaced!(order);
    }
    
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
                  'The order will be paid at delivery location with cash or Revolut',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
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
                                  'Classic Burger #${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${widget.burgerPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
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
                        '\$${widget.totalPrice.toStringAsFixed(2)}',
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
                        '-\$${_discountAmount.toStringAsFixed(2)}',
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
                      '\$${(widget.totalPrice - _discountAmount).toStringAsFixed(2)}',
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
                    onPressed: () => _handlePlaceOrder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
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
                    '\$${price.toStringAsFixed(2)} each',
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
                  '\$${(price * count).toStringAsFixed(2)}',
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

  const BurgerCustomizationPage({
    super.key,
    required this.ingredients,
    required this.onAdd,
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

  Widget _buildBurgerVisual() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Full burger image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/burger.jpg',
                  width: 280,
                  height: 350,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 280,
                      height: 350,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fastfood, size: 48, color: Colors.grey[600]),
                          SizedBox(height: 8),
                          Text(
                            'Save burger.jpg to\nassets/images/',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Ingredient masks overlay with precise cropping
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 280,
                  height: 350,
                  child: Stack(
                    children: [
                      // Ketchup mask (top layer under bun)
                      if (!(_ingredients['Ketchup'] ?? true))
                        Positioned(
                          top: 58,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Lettuce mask
                      if (!(_ingredients['Lettuce'] ?? true))
                        Positioned(
                          top: 66,
                          left: 15,
                          right: 15,
                          child: Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Tomato mask
                      if (!(_ingredients['Tomato'] ?? true))
                        Positioned(
                          top: 101,
                          left: 18,
                          right: 18,
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Onion mask
                      if (!(_ingredients['Onion'] ?? true))
                        Positioned(
                          top: 129,
                          left: 16,
                          right: 16,
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Pickle mask
                      if (!(_ingredients['Pickle Cucumber'] ?? true))
                        Positioned(
                          top: 159,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Egg mask
                      if (!(_ingredients['Egg'] ?? true))
                        Positioned(
                          top: 181,
                          left: 18,
                          right: 18,
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Bacon mask
                      if (!(_ingredients['Bacon'] ?? true))
                        Positioned(
                          top: 226,
                          left: 22,
                          right: 22,
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Beef Patty mask
                      if (!(_ingredients['Beef Patty'] ?? true))
                        Positioned(
                          top: 258,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C).withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Extra Patty mask (shown when enabled)
                      if (_ingredients['Extra Patty'] ?? false)
                        Positioned(
                          top: 230,
                          left: 22,
                          right: 22,
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(0xFF8B4513),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Mayo mask (bottom - above bottom bun)
                      if (!(_ingredients['Mayo'] ?? true))
                        Positioned(
                          top: 300,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(0xFFD4996C),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeed() {
    return Container(
      width: 4,
      height: 6,
      decoration: BoxDecoration(
        color: Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 1,
            offset: Offset(0, 0.5),
          ),
        ],
      ),
    );
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
          // Visual Burger Representation
          Container(
            color: Colors.orange[50],
            child: _buildBurgerVisual(),
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
                    const SnackBar(
                      content: Text('✓ Customized burger added to cart!'),
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
                child: const Text(
                  'Add to Cart',
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


