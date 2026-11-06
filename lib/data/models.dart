import 'package:flutter/material.dart';

/// A friendly, typed error the UI can show directly.
class AppError implements Exception {
  const AppError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parse `#RRGGBB` / `#AARRGGBB` into a [Color].
Color parseHexColor(String hex, {Color fallback = const Color(0xFFB5732E)}) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// `$12.99` money formatting (no intl dependency).
String money(num value) => '\$${value.toStringAsFixed(2)}';

String _two(int n) => n.toString().padLeft(2, '0');

/// `12 Mar 2026` from an ISO-ish date or datetime string.
String niceDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// `12 Mar 2026, 14:05`.
String niceDateTime(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${niceDate(raw)}, ${_two(d.hour)}:${_two(d.minute)}';
}

/// The normalised order lifecycle.
const List<String> kOrderFlow = ['Placed', 'Processing', 'Shipped', 'Out for delivery', 'Delivered'];
const List<String> kAllStatuses = [...kOrderFlow, 'Cancelled'];

@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.authorId,
    required this.genreId,
    required this.genre,
    required this.description,
    required this.price,
    required this.pages,
    required this.published,
    required this.stock,
    required this.sold,
    required this.coverColor,
    required this.tags,
    required this.createdAt,
    this.avgRating = 0,
    this.ratingCount = 0,
  });

  final int id;
  final String title;
  final String author;
  final int authorId;
  final int genreId;
  final String genre;
  final String description;
  final double price;
  final int pages;
  final String published;
  final int stock;
  final int sold;
  final String coverColor;
  final String tags;
  final String createdAt;
  final double avgRating;
  final int ratingCount;

  bool get inStock => stock > 0;
  bool get lowStock => stock > 0 && stock < 10;
  List<String> get tagList =>
      tags.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
  Color color() => parseHexColor(coverColor);

  /// Compact metadata sent to Gemini (no user data).
  Map<String, dynamic> toAiMap() => {
        'id': id,
        'title': title,
        'author': author,
        'genre': genre,
        'price': price,
        'pages': pages,
        'rating': avgRating,
        'inStock': inStock,
        'tags': tags,
        'blurb': description.length > 160 ? '${description.substring(0, 160)}…' : description,
      };

  factory Book.fromMap(Map<String, dynamic> m) => Book(
        id: (m['id'] as num).toInt(),
        title: m['title'] as String,
        author: (m['author'] ?? '') as String,
        authorId: (m['author_id'] as num?)?.toInt() ?? 0,
        genreId: (m['genre_id'] as num?)?.toInt() ?? 0,
        genre: (m['genre'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        price: (m['price'] as num).toDouble(),
        pages: (m['pages'] as num?)?.toInt() ?? 0,
        published: (m['published'] ?? '') as String,
        stock: (m['stock'] as num?)?.toInt() ?? 0,
        sold: (m['sold'] as num?)?.toInt() ?? 0,
        coverColor: (m['cover_color'] ?? '#B5732E') as String,
        tags: (m['tags'] ?? '') as String,
        createdAt: (m['created_at'] ?? '') as String,
        avgRating: (m['avg_rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
    required this.isAdmin,
    required this.isActive,
    this.phone = '',
    this.createdAt = '',
  });

  final int id;
  final String name;
  final String email;
  final String provider;
  final bool isAdmin;
  final bool isActive;
  final String phone;
  final String createdAt;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String,
        email: m['email'] as String,
        provider: (m['provider'] ?? 'email') as String,
        isAdmin: (m['is_admin'] as num?)?.toInt() == 1,
        isActive: (m['is_active'] as num?)?.toInt() != 0,
        phone: (m['phone'] ?? '') as String,
        createdAt: (m['created_at'] ?? '') as String,
      );
}

@immutable
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.fullName,
    required this.line1,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
    this.isDefault = false,
  });

  final int id;
  final int userId;
  final String label;
  final String fullName;
  final String line1;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;

  String get oneLine => '$line1, $city, $region $postalCode, $country';

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: (m['id'] as num).toInt(),
        userId: (m['user_id'] as num).toInt(),
        label: (m['label'] ?? 'Home') as String,
        fullName: (m['full_name'] ?? '') as String,
        line1: (m['line1'] ?? '') as String,
        city: (m['city'] ?? '') as String,
        region: (m['region'] ?? '') as String,
        postalCode: (m['postal_code'] ?? '') as String,
        country: (m['country'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        isDefault: (m['is_default'] as num?)?.toInt() == 1,
      );
}

@immutable
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.userId,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  final int id;
  final int userId;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  String get label => '$brand •••• $last4';
  String get expiry => '${_two(expMonth)}/${_two(expYear % 100)}';

  factory PaymentMethod.fromMap(Map<String, dynamic> m) => PaymentMethod(
        id: (m['id'] as num).toInt(),
        userId: (m['user_id'] as num).toInt(),
        brand: (m['brand'] ?? 'Card') as String,
        last4: (m['last4'] ?? '0000') as String,
        expMonth: (m['exp_month'] as num?)?.toInt() ?? 1,
        expYear: (m['exp_year'] as num?)?.toInt() ?? 2030,
        isDefault: (m['is_default'] as num?)?.toInt() == 1,
      );
}

@immutable
class CartLine {
  const CartLine({required this.book, required this.qty});
  final Book book;
  final int qty;
  double get lineTotal => book.price * qty;
}

@immutable
class Review {
  const Review({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.body,
    required this.createdAt,
    this.likes = 0,
    this.likedByMe = false,
  });

  final int id;
  final int bookId;
  final int userId;
  final String userName;
  final int rating;
  final String body;
  final String createdAt;
  final int likes;
  final bool likedByMe;

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        id: (m['id'] as num).toInt(),
        bookId: (m['book_id'] as num).toInt(),
        userId: (m['user_id'] as num).toInt(),
        userName: (m['user_name'] ?? 'Reader') as String,
        rating: (m['rating'] as num).toInt(),
        body: (m['body'] ?? '') as String,
        createdAt: (m['created_at'] ?? '') as String,
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        likedByMe: (m['liked_by_me'] as num?)?.toInt() == 1,
      );
}

@immutable
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.userId,
    required this.status,
    required this.total,
    required this.trackingNo,
    required this.createdAt,
    this.itemCount = 0,
  });

  final int id;
  final int userId;
  final String status;
  final double total;
  final String trackingNo;
  final String createdAt;
  final int itemCount;

  factory OrderSummary.fromMap(Map<String, dynamic> m) => OrderSummary(
        id: (m['id'] as num).toInt(),
        userId: (m['user_id'] as num).toInt(),
        status: m['status'] as String,
        total: (m['total'] as num).toDouble(),
        trackingNo: (m['tracking_no'] ?? '') as String,
        createdAt: (m['created_at'] ?? '') as String,
        itemCount: (m['item_count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class OrderItem {
  const OrderItem({
    required this.id,
    required this.bookId,
    required this.title,
    required this.unitPrice,
    required this.qty,
  });

  final int id;
  final int bookId;
  final String title;
  final double unitPrice;
  final int qty;
  double get lineTotal => unitPrice * qty;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        id: (m['id'] as num).toInt(),
        bookId: (m['book_id'] as num).toInt(),
        title: m['title'] as String,
        unitPrice: (m['unit_price'] as num).toDouble(),
        qty: (m['qty'] as num).toInt(),
      );
}

@immutable
class OrderEvent {
  const OrderEvent({required this.id, required this.status, required this.note, required this.at});
  final int id;
  final String status;
  final String note;
  final String at;

  factory OrderEvent.fromMap(Map<String, dynamic> m) => OrderEvent(
        id: (m['id'] as num).toInt(),
        status: m['status'] as String,
        note: (m['note'] ?? '') as String,
        at: (m['at'] ?? '') as String,
      );
}

@immutable
class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.items,
    required this.events,
    required this.shipName,
    required this.shipLine1,
    required this.shipCity,
    required this.payment,
  });

  final OrderSummary order;
  final List<OrderItem> items;
  final List<OrderEvent> events;
  final String shipName;
  final String shipLine1;
  final String shipCity;
  final String payment;

  double get subtotal => items.fold(0.0, (s, i) => s + i.lineTotal);
  double get adjustment => order.total - subtotal;
}

@immutable
class AdminStats {
  const AdminStats({
    required this.books,
    required this.users,
    required this.orders,
    required this.revenue,
    required this.lowStock,
    required this.pendingOrders,
    this.salesByDay = const [],
    this.topBooks = const [],
  });

  final int books;
  final int users;
  final int orders;
  final double revenue;
  final int lowStock;
  final int pendingOrders;
  final List<MapEntry<String, double>> salesByDay;
  final List<MapEntry<String, int>> topBooks;
}

@immutable
class GenreInfo {
  const GenreInfo({required this.id, required this.name, required this.count});
  final int id;
  final String name;
  final int count;
}

@immutable
class AuthorInfo {
  const AuthorInfo({required this.id, required this.name, required this.count});
  final int id;
  final String name;
  final int count;
}

/// Store pricing rules. STUDENT10 = 10% off; shipping 2.99 under $30, free ≥ $30,
/// and 0 when the cart is empty.
class Pricing {
  Pricing._();

  static double discount(double subtotal, String coupon) {
    if (subtotal <= 0) return 0;
    if (coupon.trim().toUpperCase() == 'STUDENT10') {
      return double.parse((subtotal * 0.10).toStringAsFixed(2));
    }
    return 0;
  }

  static double shipping(double subtotal) {
    if (subtotal <= 0) return 0;
    return subtotal >= 30 ? 0 : 2.99;
  }

  static double total(double subtotal, String coupon) {
    final d = discount(subtotal, coupon);
    final after = subtotal - d;
    final s = shipping(subtotal);
    return double.parse((after + s).toStringAsFixed(2));
  }
}
