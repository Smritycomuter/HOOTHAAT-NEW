# Hoothaat.com — Full Flutter E-commerce Starter

এই প্যাকেজে ২টি Flutter app আছে:

1. `customer_app/` — Android customer app
2. `admin_panel/` — Web-based Admin Control Panel

দুটিই একই Firebase backend (Authentication + Firestore + Storage) ব্যবহার করার জন্য তৈরি।

## Customer App
Customer:
- Register/Login
- Product browse/search
- Category filter
- Add to cart
- Checkout with customer name, phone, address
- Place order
- My Orders
- Order status

## Admin Panel
Admin:
- Admin Login
- Dashboard
- Add/Edit/Delete products
- Product price, stock, category, discount
- View orders
- Update order status
- View customers/orders summary

## Firebase setup
নিজের Firebase project তৈরি করে প্রতিটি app-এর জন্য FlutterFire configure করুন:

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

Customer app:
```bash
cd customer_app
flutterfire configure
flutter pub get
flutter run
```

Admin panel:
```bash
cd admin_panel
flutterfire configure
flutter pub get
flutter run -d chrome
```

## Admin access
প্রথমে Customer/Admin panel-এর login screen দিয়ে একটি account তৈরি করুন।
তারপর Firebase Console > Firestore Database-এ:

Collection: `admins`
Document ID: সেই user's Firebase UID

Document:
```json
{
  "email": "your-admin-email@example.com",
  "role": "admin"
}
```

Firestore rules এই UID-কে admin হিসেবে যাচাই করবে।

## Firestore collections
- `products`
- `orders`
- `users`
- `admins`

Order structure:
```text
orders/{orderId}
  customerId
  customerName
  phone
  address
  items[]
  total
  status
  createdAt
```

## Important
এটি production-ready marketplace-এর ভিত্তি। Payment gateway, courier API, seller/vendor panel, coupon engine, push notification এবং advanced analytics পরে যোগ করা যাবে।
