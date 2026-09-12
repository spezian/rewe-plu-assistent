import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/app_constants.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'barcode_screen.dart';
import 'market_access_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'product_gallery_screen.dart';
import 'search_screen.dart';

class Destination {
  const Destination(this.index, this.title, this.navBarName, this.icon);
  final int index;
  final String navBarName;
  final String title;
  final IconData icon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<Destination> allDestinations = <Destination>[
    Destination(0, 'Kassenmeister', 'Produkte', Icons.list_alt_outlined),
    Destination(1, 'Suche', 'Suche', Icons.search),
    Destination(1, 'Kassenbelegung', 'Belegung', Icons.work_history_outlined),
  ];

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isSyncConfigured && !controller.hasMarketAccess) {
          return MarketAccessScreen(controller: controller);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(allDestinations[_selectedTab].title),
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            actions: [
              Container(
                decoration: BoxDecoration(
                  color: reweDarkRed,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    _SyncButton(controller: controller),
                    if (controller.isSyncConfigured)
                      _AccountButton(controller: controller),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedTab,
            children: [
              const ProductListPage(),
              SearchScreen(isActive: _selectedTab == 1),
              Container(color: Colors.white),
            ],
          ),
          floatingActionButton: controller.canEdit
              ? FloatingActionButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProductFormScreen(),
                    ),
                  ),
                  backgroundColor: reweDarkRed,
                  shape: CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTab = index),
              backgroundColor: Colors.white,
              indicatorColor: Colors.grey[200]!,
              labelTextStyle: WidgetStateProperty.fromMap({
                WidgetState.selected: Theme.of(context).textTheme.labelMedium!
                    .copyWith(color: reweDarkRed),
                WidgetState.any: Theme.of(context).textTheme.labelMedium!
                    .copyWith(color: Colors.black),
              }),
              destinations: allDestinations.map<NavigationDestination>((
                Destination destination,
              ) {
                return NavigationDestination(
                  icon: Icon(destination.icon, color: Colors.black),
                  selectedIcon: Icon(destination.icon, color: reweDarkRed),
                  label: destination.navBarName,
                );
              }).toList(),
            ),
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
        padding: EdgeInsets.only(left: 16, right: 10),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
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
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: IconButton(
          tooltip: localOnly
              ? 'Nur lokal – Supabase nicht eingerichtet'
              : locked
              ? 'Cloud gesperrt – anmelden'
              : isError
              ? 'Sync-Fehler'
              : 'Jetzt synchronisieren',
          color: Colors.white,
          onPressed: () {
            if (localOnly) {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cloud-Sync nicht eingerichtet'),
                  content: Text(
                    supabaseConfigurationError ??
                        'Die App speichert sicher offline. Für Supabase die URL '
                            'und den Publishable Key beim Start per '
                            '--dart-define übergeben. Die genaue Einrichtung '
                            'steht in der README.',
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
              // The market entry screen is shown whenever access is locked.
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
          ),
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
      tooltip: 'Marktzugang',
      color: Colors.white,
      onPressed: () async {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              controller.canEdit
                  ? Icons.edit_outlined
                  : Icons.visibility_outlined,
            ),
            title: const Text('Marktzugang'),
            content: Text(
              controller.canEdit
                  ? 'Bearbeitungszugang ist aktiv.'
                  : 'Der Markt ist schreibgeschützt geöffnet. Ansehen und '
                        'Suchen ist ohne PIN möglich.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
              if (!controller.canEdit)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'upgrade'),
                  child: const Row(mainAxisSize: MainAxisSize.min, spacing: 4.0, children: [Icon(Icons.lock_open_outlined), Text('Bearbeiten')],),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'leave'),
                child: const Row(mainAxisSize: MainAxisSize.min, spacing: 4.0, children: [Icon(Icons.logout), Text('Markt verlassen')],),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (action == 'upgrade') {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _EditorPinDialog(controller: controller),
          );
        } else if (action == 'leave') {
          await controller.leaveMarket();
        }
      },
      icon: Icon(
        controller.canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

class _EditorPinDialog extends StatefulWidget {
  const _EditorPinDialog({required this.controller});

  final AppController controller;

  @override
  State<_EditorPinDialog> createState() => _EditorPinDialogState();
}

class _EditorPinDialogState extends State<_EditorPinDialog> {
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.pin_outlined),
      title: const Text('Bearbeiten entsperren'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gib die PIN dieses Marktes ein.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '•',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _unlock(),
              decoration: const InputDecoration(
                labelText: 'Markt-PIN',
                prefixIcon: Icon(Icons.password),
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
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _unlock,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Entsperren'),
        ),
      ],
    );
  }

  Future<void> _unlock() async {
    if (_pinController.text.isEmpty) {
      setState(() => _error = 'Bitte PIN eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.upgradeToEditor(_pinController.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'PIN ist falsch.';
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
                  avatar: StatefulBuilder(
                    builder: (context, setState) {
                      return Icon(
                        Icons.history,
                        size: 18,
                        color: _category == 'Veraltet'
                            ? Colors.white
                            : Colors.black,
                      );
                    },
                  ),
                  label: const Text('Veraltet'),
                  selected: _category == 'Veraltet',
                  showCheckmark: false,
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
      onTogglePinned: controller.canEdit
          ? () => controller.togglePinned(product)
          : null,
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
