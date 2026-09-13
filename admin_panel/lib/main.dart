import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Run `flutterfire configure` in this folder.
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'Hoothaat Admin',
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.deepOrange),
    home:const AdminGate(),
  );
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(context)=>StreamBuilder<User?>(
    stream:FirebaseAuth.instance.authStateChanges(),
    builder:(_,s){
      if(s.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator()));
      return s.data==null?const AdminLogin():const AdminHome();
    });
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});
  @override State<AdminLogin> createState()=>_AdminLoginState();
}
class _AdminLoginState extends State<AdminLogin>{
  final email=TextEditingController(),pass=TextEditingController();
  bool busy=false;
  Future<void> login()async{
    setState(()=>busy=true);
    try{
      final c=await FirebaseAuth.instance.signInWithEmailAndPassword(email:email.text.trim(),password:pass.text);
      final doc=await FirebaseFirestore.instance.collection('admins').doc(c.user!.uid).get();
      if(!doc.exists){
        await FirebaseAuth.instance.signOut();
        throw Exception('এই account-টি Admin হিসেবে অনুমোদিত নয়। Firebase Console-এ admins collection-এ UID যোগ করুন।');
      }
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(context)=>Scaffold(
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(
      margin:const EdgeInsets.all(24),child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.admin_panel_settings,size:70,color:Colors.deepOrange),
        const Text('Hoothaat Admin Panel',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
        const SizedBox(height:24),
        TextField(controller:email,decoration:const InputDecoration(labelText:'Admin email')),
        TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
        const SizedBox(height:20),
        FilledButton(onPressed:busy?null:login,child:Text(busy?'Checking...':'Admin Login')),
      ]))))));
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override State<AdminHome> createState()=>_AdminHomeState();
}
class _AdminHomeState extends State<AdminHome>{
  int index=0;
  final pages=const [Dashboard(),ProductsPage(),OrdersAdminPage()];
  @override Widget build(context)=>Scaffold(
    appBar:AppBar(title:const Text('Hoothaat.com — Control Panel'),actions:[
      IconButton(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout)),
    ]),
    body:Row(children:[
      NavigationRail(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),
        labelType:NavigationRailLabelType.all,
        destinations:const[
          NavigationRailDestination(icon:Icon(Icons.dashboard),label:Text('Dashboard')),
          NavigationRailDestination(icon:Icon(Icons.inventory_2),label:Text('Products')),
          NavigationRailDestination(icon:Icon(Icons.shopping_cart),label:Text('Orders')),
        ]),
      const VerticalDivider(width:1),
      Expanded(child:pages[index]),
    ]),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Widget box(String title,Stream<QuerySnapshot> stream,IconData icon)=>StreamBuilder<QuerySnapshot>(
    stream:stream,builder:(_,s)=>Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,size:35),const SizedBox(height:12),Text(title),const SizedBox(height:6),
      Text('${s.data?.docs.length??0}',style:const TextStyle(fontSize:30,fontWeight:FontWeight.bold)),
    ]))));
  @override Widget build(context)=>Padding(padding:const EdgeInsets.all(28),child:Wrap(spacing:18,runSpacing:18,children:[
    box('Products',FirebaseFirestore.instance.collection('products').snapshots(),Icons.inventory_2),
    box('Orders',FirebaseFirestore.instance.collection('orders').snapshots(),Icons.shopping_cart),
    box('Customers',FirebaseFirestore.instance.collection('users').snapshots(),Icons.people),
  ]));
}

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});
  Future<void> edit(BuildContext context,{DocumentSnapshot? doc})async{
    final data=doc?.data() as Map<String,dynamic>?;
    final name=TextEditingController(text:data?['name']??'');
    final price=TextEditingController(text:'${data?['price']??''}');
    final category=TextEditingController(text:data?['category']??'');
    final image=TextEditingController(text:data?['image']??'');
    final desc=TextEditingController(text:data?['description']??'');
    await showDialog(context:context,builder:(_)=>AlertDialog(
      title:Text(doc==null?'Add Product':'Edit Product'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Product name')),
        TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Price (৳)')),
        TextField(controller:category,decoration:const InputDecoration(labelText:'Category')),
        TextField(controller:image,decoration:const InputDecoration(labelText:'Image URL')),
        TextField(controller:desc,maxLines:4,decoration:const InputDecoration(labelText:'Description')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        FilledButton(onPressed:()async{
          final payload={'name':name.text.trim(),'price':double.tryParse(price.text)??0,'category':category.text.trim(),'image':image.text.trim(),'description':desc.text.trim(),'createdAt':doc?.get('createdAt')??FieldValue.serverTimestamp()};
          if(doc==null)await FirebaseFirestore.instance.collection('products').add(payload);
          else await doc.reference.update(payload);
          if(context.mounted)Navigator.pop(context);
        },child:const Text('Save')),
      ]));
  }
  @override Widget build(context)=>Column(children:[
    Padding(padding:const EdgeInsets.all(18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      const Text('Products',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
      FilledButton.icon(onPressed:()=>edit(context),icon:const Icon(Icons.add),label:const Text('Add Product')),
    ])),
    const Divider(height:1),
    Expanded(child:StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('products').orderBy('createdAt',descending:true).snapshots(),
      builder:(_,s){
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        return ListView.builder(itemCount:s.data!.docs.length,itemBuilder:(_,i){
          final d=s.data!.docs[i]; final m=d.data() as Map<String,dynamic>;
          return ListTile(
            leading:m['image'].toString().isEmpty?const Icon(Icons.image):Image.network(m['image'],width:55,errorBuilder:(_,__,___)=>const Icon(Icons.image)),
            title:Text(m['name']??''),
            subtitle:Text('৳ ${(m['price']??0).toString()} • ${m['category']??''}'),
            trailing:Wrap(children:[
              IconButton(onPressed:()=>edit(context,doc:d),icon:const Icon(Icons.edit)),
              IconButton(onPressed:()=>d.reference.delete(),icon:const Icon(Icons.delete_outline)),
            ]));
        });
      })),
  ]);
}

class OrdersAdminPage extends StatelessWidget {
  const OrdersAdminPage({super.key});
  @override Widget build(context)=>StreamBuilder<QuerySnapshot>(
    stream:FirebaseFirestore.instance.collection('orders').orderBy('createdAt',descending:true).snapshots(),
    builder:(_,s){
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      return ListView.builder(itemCount:s.data!.docs.length,itemBuilder:(_,i){
        final d=s.data!.docs[i]; final m=d.data() as Map<String,dynamic>;
        return Card(margin:const EdgeInsets.symmetric(horizontal:18,vertical:7),child:ListTile(
          title:Text('Order #${d.id.substring(0,8).toUpperCase()} — ${m['customerName']??''}'),
          subtitle:Text('৳ ${(m['total']??0).toString()} • ${m['phone']??''}\n${m['address']??''}'),
          isThreeLine:true,
          trailing:DropdownButton<String>(
            value:(m['status']??'Pending').toString(),
            items:['Pending','Confirmed','Processing','Shipped','Delivered','Cancelled'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
            onChanged:(v)=>v==null?null:d.reference.update({'status':v}),
          ),
        ));
      });
    });
}
