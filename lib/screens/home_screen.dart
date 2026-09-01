import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/app_constants.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'barcode_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'product_gallery_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedTab == 0 ? 'PLU Assistent' : 'Schnellsuche'),
            actions: [
              _SyncButton(controller: controller),
              if (controller.isSyncConfigured)
                _AccountButton(controller: controller),
              const SizedBox(width: 4),
            ],
          ),
          body: IndexedStack(
            index: _selectedTab,
            children: [
              const ProductListPage(),
              SearchScreen(isActive: _selectedTab == 1),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProductFormScreen(),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Produkt'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) =>
                setState(() => _selectedTab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Produkte',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.manage_search),
                label: 'Suche',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.syncState == AppSyncState.syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    final isError = controller.syncState == AppSyncState.error;
    final localOnly = controller.syncState == AppSyncState.localOnly;
    final locked = controller.syncState == AppSyncState.locked;
    return Badge(
      isLabelVisible: controller.pendingChanges > 0,
      label: Text(
        controller.pendingChanges > 99 ? '99+' : '${controller.pendingChanges}',
      ),
      child: IconButton(
        tooltip: localOnly
            ? 'Nur lokal – Supabase nicht eingerichtet'
            : locked
            ? 'Cloud gesperrt – anmelden'
            : isError
            ? 'Sync-Fehler'
            : 'Jetzt synchronisieren',
        onPressed: () {
          if (localOnly) {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cloud-Sync nicht eingerichtet'),
                content: const Text(
                  'Die App speichert sicher offline. Für Supabase die URL und den '
                  'Anon-Key beim Start per --dart-define übergeben. Die genaue '
                  'Einrichtung steht in der README.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else if (locked) {
            _showCloudLogin(context, controller);
          } else if (isError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(controller.syncError ?? 'Sync fehlgeschlagen'),
              ),
            );
            controller.syncNow();
          } else {
            controller.syncNow();
          }
        },
        icon: Icon(
          localOnly
              ? Icons.cloud_off_outlined
              : locked
              ? Icons.lock_outline
              : isError
              ? Icons.cloud_off
              : Icons.cloud_done_outlined,
          color: isError ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: controller.isAuthenticated
          ? controller.currentUserEmail ?? 'Cloud-Konto'
          : 'Cloud anmelden',
      onPressed: () async {
        if (!controller.isAuthenticated) {
          await _showCloudLogin(context, controller);
          return;
        }
        final signOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cloud-Konto'),
            content: Text(
              'Angemeldet als\n${controller.currentUserEmail ?? 'Benutzer'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Schließen'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
              ),
            ],
          ),
        );
        if (signOut == true) await controller.signOut();
      },
      icon: Icon(
        controller.isAuthenticated ? Icons.account_circle : Icons.lock_outline,
      ),
    );
  }
}

Future<void> _showCloudLogin(BuildContext context, AppController controller) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CloudLoginDialog(controller: controller),
    );

class _CloudLoginDialog extends StatefulWidget {
  const _CloudLoginDialog({required this.controller});

  final AppController controller;

  @override
  State<_CloudLoginDialog> createState() => _CloudLoginDialogState();
}

class _CloudLoginDialogState extends State<_CloudLoginDialog> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('Geschützter Cloud-Zugang'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lokale Daten bleiben ohne Anmeldung nutzbar. Für die Online-'
              'Datenbank sind E-Mail und Zugangspasswort erforderlich.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              autofocus: false,
              obscureText: _obscurePassword,
              autocorrect: false,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Zugangspasswort',
                prefixIcon: const Icon(Icons.password),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Passwort anzeigen' : 'Verbergen',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Offline bleiben'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _login,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Anmelden'),
        ),
      ],
    );
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Bitte E-Mail und Passwort eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      setState(() {
        _loading = false;
        _error = text.contains('Invalid login credentials')
            ? 'E-Mail oder Passwort ist falsch.'
            : 'Anmeldung fehlgeschlagen: $text';
      });
    }
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with AutomaticKeepAliveClientMixin {
  String? _category;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = AppScope.of(context);
    final products = controller.products.where((product) {
      if (_category == 'Veraltet') return product.isObsolete;
      if (product.isObsolete) return false;
      return _category == null || product.category == _category;
    }).toList();
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: const Text('Alle'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final category in productCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: const Text('Veraltet'),
                  selected: _category == 'Veraltet',
                  onSelected: (_) => setState(() => _category = 'Veraltet'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? _EmptyProducts(
                  hasAnyProducts: controller.products.isNotEmpty,
                  showingObsolete: _category == 'Veraltet',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _productCard(context, controller, products[index]),
                ),
        ),
      ],
    );
  }

  Widget _productCard(
    BuildContext context,
    AppController controller,
    Product product,
  ) {
    return ProductCard(
      product: product,
      onTogglePinned: () => controller.togglePinned(product),
      onOpenDetails: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      ),
      onOpenImages: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProductGalleryScreen(title: product.name, images: product.images),
        ),
      ),
      onShowCode: () {
        final code = product.activeCode;
        if (code == null || !code.type.canShowBarcode) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BarcodeScreen(product: product, code: code),
          ),
        );
      },
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({
    required this.hasAnyProducts,
    required this.showingObsolete,
  });

  final bool hasAnyProducts;
  final bool showingObsolete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyProducts
                  ? Icons.filter_alt_off
                  : Icons.shopping_basket_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              hasAnyProducts
                  ? showingObsolete
                        ? 'Keine veralteten Produkte'
                        : 'Keine Produkte in dieser Kategorie'
                  : 'Noch keine Produkte gespeichert',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!hasAnyProducts) ...[
              const SizedBox(height: 6),
              const Text(
                'Über „Produkt“ legst du den ersten schnellen Kasseneintrag an.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
