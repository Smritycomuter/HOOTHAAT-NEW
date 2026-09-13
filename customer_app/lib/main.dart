import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Run `flutterfire configure` in this folder to generate firebase_options.dart.
// Then uncomment the import below and the Firebase.initializeApp options.
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(create: (_) => CartModel(), child: const HoothaatApp()),
  );
}

class HoothaatApp extends StatelessWidget {
  const HoothaatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hoothaat.com',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xfff7f7f7),
      ),
      home: const AuthGate(),
    );
  }
}

class CartItem {
  final String productId;
  final String name;
  final double price;
  final String image;
  int quantity;
  CartItem({required this.productId, required this.name, required this.price, required this.image, this.quantity = 1});
  Map<String, dynamic> toMap() => {
    'productId': productId, 'name': name, 'price': price, 'image': image, 'quantity': quantity,
  };
}

class CartModel extends ChangeNotifier {
  final List<CartItem> items = [];
  void add(CartItem item) {
    final i = items.indexWhere((x) => x.productId == item.productId);
    if (i >= 0) {
      items[i].quantity++;
    } else {
      items.add(item);
    }
    notifyListeners();
  }
  void changeQty(int i, int delta) {
    items[i].quantity += delta;
    if (items[i].quantity <= 0) items.removeAt(i);
    notifyListeners();
  }
  double get total => items.fold(0, (s, x) => s + x.price * x.quantity);
  int get count => items.fold(0, (s, x) => s + x.quantity);
  void clear() { items.clear(); notifyListeners(); }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginPage() : const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false, busy = false;

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      UserCredential c;
      if (register) {
        c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(), password: password.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).set({
          'email': email.text.trim(), 'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: password.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_bag, size: 64, color: Colors.deepOrange),
              const SizedBox(height: 10),
              const Text('Hoothaat.com', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Please wait...' : (register ? 'Create account' : 'Login')),
              ),
              TextButton(onPressed: () => setState(() => register = !register),
                child: Text(register ? 'Already have an account? Login' : 'Create a new account')),
            ]),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab = 0;
  String search = '';
  @override
  Widget build(BuildContext context) {
    final pages = [StorePage(search: search), const OrdersPage(), const AccountPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoothaat.com', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Badge(label: Text('${context.watch<CartModel>().count}'), child: const Icon(Icons.shopping_cart)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

class StorePage extends StatelessWidget {
  final String search;
  const StorePage({super.key, this.search = ''});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (_) {},
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search products', filled: true,
          fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      ),
    ),
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No products yet. Add products from Admin Panel.'));
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return ProductCard(id: docs[i].id, data: d);
            },
          );
        },
      ),
    )
  ]);
}

class ProductCard extends StatelessWidget {
  final String id; final Map<String, dynamic> data;
  const ProductCard({super.key, required this.id, required this.data});
  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Product';
    final price = (data['price'] ?? 0).toDouble();
    final image = data['image'] ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductPage(id: id, data: data))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: image.toString().isEmpty
            ? const Center(child: Icon(Icons.image, size: 60))
            : Image.network(image, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 60)))),
          Padding(padding: const EdgeInsets.all(10), child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Text('৳ ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  final String id; final Map<String, dynamic> data;
  const ProductPage({super.key, required this.id, required this.data});
  @override
  Widget build(BuildContext context) {
    final price = (data['price'] ?? 0).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if ((data['image'] ?? '').toString().isNotEmpty) Image.network(data['image'], height: 280, fit: BoxFit.contain),
        const SizedBox(height: 16),
        Text(data['name'] ?? '', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('৳ ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 16),
        Text(data['description'] ?? 'No description'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            context.read<CartModel>().add(CartItem(productId: id, name: data['name'] ?? '', price: price, image: data['image'] ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
          },
          icon: const Icon(Icons.add_shopping_cart), label: const Text('Add to Cart'),
        ),
      ]),
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.items.isEmpty ? const Center(child: Text('Cart is empty')) : Column(children: [
        Expanded(child: ListView.builder(itemCount: cart.items.length, itemBuilder: (_, i) {
          final x = cart.items[i];
          return ListTile(
            leading: x.image.isEmpty ? const Icon(Icons.image) : Image.network(x.image, width: 55, fit: BoxFit.cover),
            title: Text(x.name),
            subtitle: Text('৳ ${x.price.toStringAsFixed(0)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => cart.changeQty(i, -1), icon: const Icon(Icons.remove)),
              Text('${x.quantity}'),
              IconButton(onPressed: () => cart.changeQty(i, 1), icon: const Icon(Icons.add)),
            ]),
          );
        })),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Total: ৳ ${cart.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage())), child: const Text('Checkout')),
        ])),
      ]),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override State<CheckoutPage> createState() => _CheckoutPageState();
}
class _CheckoutPageState extends State<CheckoutPage> {
  final name=TextEditingController(), phone=TextEditingController(), address=TextEditingController();
  bool busy=false;
  Future<void> place() async {
    final cart=context.read<CartModel>();
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty || address.text.trim().isEmpty || cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields')));
      return;
    }
    setState(()=>busy=true);
    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'customerId': FirebaseAuth.instance.currentUser!.uid,
        'customerName': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'items': cart.items.map((x)=>x.toMap()).toList(),
        'total': cart.total,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      cart.clear();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully')));
        Navigator.popUntil(context, (r)=>r.isFirst);
      }
    } finally { if(mounted) setState(()=>busy=false); }
  }
  @override
  Widget build(context)=>Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller:name, decoration:const InputDecoration(labelText:'Customer name')),
      TextField(controller:phone, decoration:const InputDecoration(labelText:'Phone')),
      TextField(controller:address, maxLines:3, decoration:const InputDecoration(labelText:'Delivery address')),
      const SizedBox(height:20),
      FilledButton(onPressed:busy?null:place, child:Text(busy?'Placing...':'Place Order')),
    ]),
  );
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});
  @override
  Widget build(context)=>StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('orders')
      .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .snapshots(),
    builder:(_,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final docs=snap.data!.docs;
      if(docs.isEmpty)return const Center(child:Text('No orders yet'));
      return ListView.builder(itemCount:docs.length,itemBuilder:(_,i){
        final d=docs[i].data() as Map<String,dynamic>;
        return Card(child:ListTile(
          leading:const Icon(Icons.receipt_long),
          title:Text('Order #${docs[i].id.substring(0,6).toUpperCase()}'),
          subtitle:Text('৳ ${(d['total']??0).toStringAsFixed(0)} • ${d['status']??'Pending'}'),
        ));
      });
    },
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(context)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CircleAvatar(radius:40,child:Icon(Icons.person,size:40)),
    const SizedBox(height:12),
    Text(FirebaseAuth.instance.currentUser?.email??''),
    const SizedBox(height:20),
    OutlinedButton(onPressed:()=>FirebaseAuth.instance.signOut(),child:const Text('Logout')),
  ]));
}
