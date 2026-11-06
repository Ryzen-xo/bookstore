import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../features/auth/auth_page.dart';
import '../features/book/book_page.dart';

/// The single source of truth for session, cart, wishlist, theme and navigation.
/// Widgets read it through [AppStateScope]; it is the only object that calls the
/// repository for cross-cutting actions.
class AppState extends ChangeNotifier {
  AppState();

  Repo? _repo;
  Repo get repo => _repo!;
  Database? _db;

  AppUser? user;
  ThemeMode themeMode = ThemeMode.light;
  int cartCount = 0;
  Set<int> wishIds = {};
  bool demoTools = false;
  bool onboardingSeen = false;
  bool initialized = false;
  String? initError;
  int shellIndex = 0;
  String? chatPrefill;
  List<Book> recentlyViewed = [];

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  SharedPreferences? _prefs;

  bool get loggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _db = await AppDatabase.open();
      _repo = Repo(_db!);
      themeMode = _prefs?.getString('themeMode') == 'dark' ? ThemeMode.dark : ThemeMode.light;
      onboardingSeen = _prefs?.getBool('onboardingSeen') ?? false;
      demoTools = _prefs?.getBool('demoTools') ?? false;
      final sessionId = _prefs?.getInt('sessionUserId');
      if (sessionId != null) {
        user = await _repo!.userById(sessionId);
        if (user != null && !user!.isActive) user = null;
      }
      await refreshCart();
      await _refreshWishlist();
      initialized = true;
      notifyListeners();
    } catch (e) {
      initError = 'Could not open the store database: $e';
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> _refreshWishlist() async {
    if (user == null) {
      wishIds = {};
      return;
    }
    wishIds = await repo.wishlistIds(user!.id);
  }

  Future<void> refreshCart() async {
    cartCount = user == null ? 0 : await repo.cartCount(user!.id);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (user != null) user = await repo.userById(user!.id);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await repo.login(email, password);
    await _prefs?.setInt('sessionUserId', user!.id);
    await refreshCart();
    await _refreshWishlist();
    notifyListeners();
  }

  Future<void> register({required String name, required String email, required String password}) async {
    user = await repo.register(name: name, email: email, password: password);
    await _prefs?.setInt('sessionUserId', user!.id);
    await refreshCart();
    notifyListeners();
  }

  Future<void> socialLogin(String provider) async {
    user = await repo.socialLogin(provider);
    await _prefs?.setInt('sessionUserId', user!.id);
    await refreshCart();
    await _refreshWishlist();
    notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    cartCount = 0;
    wishIds = {};
    await _prefs?.remove('sessionUserId');
    shellIndex = 0;
    notifyListeners();
  }

  Future<void> addToCart(int bookId, {int qty = 1}) async {
    if (user == null) {
      openLogin();
      throw const AppError('Please sign in to add books to your cart.');
    }
    await repo.addToCart(user!.id, bookId, qty: qty);
    await refreshCart();
  }

  Future<void> toggleWishlist(int bookId) async {
    if (user == null) {
      openLogin();
      return;
    }
    final added = await repo.toggleWishlist(user!.id, bookId);
    if (added) {
      wishIds.add(bookId);
    } else {
      wishIds.remove(bookId);
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await _prefs?.setString('themeMode', mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setDemoTools(bool value) async {
    demoTools = value;
    await _prefs?.setBool('demoTools', value);
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    await _prefs?.setBool('onboardingSeen', true);
    notifyListeners();
  }

  void setShellIndex(int i) {
    shellIndex = i;
    notifyListeners();
  }

  void openLibrarian({String? prefill}) {
    chatPrefill = prefill;
    shellIndex = 2;
    notifyListeners();
  }

  String? consumeChatPrefill() {
    final p = chatPrefill;
    chatPrefill = null;
    return p;
  }

  void rememberViewed(Book book) {
    recentlyViewed.removeWhere((b) => b.id == book.id);
    recentlyViewed.insert(0, book);
    if (recentlyViewed.length > 12) recentlyViewed = recentlyViewed.sublist(0, 12);
  }

  void openBook(BuildContext context, Book book) {
    rememberViewed(book);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookPage(bookId: book.id)));
  }

  void openLogin() {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const AuthPage()));
  }
}

/// Read the state from the Provider above. `of` listens; `read` does not.
class AppStateScope {
  AppStateScope._();
  static AppState of(BuildContext context) => Provider.of<AppState>(context);
  static AppState read(BuildContext context) => Provider.of<AppState>(context, listen: false);
}
