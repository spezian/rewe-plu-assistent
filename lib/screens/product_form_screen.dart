import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../app_scope.dart';
import '../core/app_constants.dart';
import '../data/image_suggestion_service.dart';
import '../models/product.dart';
import 'barcode_scanner_screen.dart';
import 'internet_image_search_screen.dart';
import 'product_gallery_screen.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({this.product, super.key});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_CodeDraft> _codes = [];
  final List<ProductImageData> _images = [];

  late final String _productId;
  late String _category;
  bool _isOrganic = false;
  bool _isPromotion = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _productId = product?.id ?? _uuid.v4();
    _nameController.text = product?.name ?? '';
    _aliasesController.text = product?.aliases.join(', ') ?? '';
    _descriptionController.text = product?.description ?? '';
    _category = product?.category ?? productCategories.first;
    _isOrganic = product?.isOrganic ?? false;
    _isPromotion = product?.isPromotion ?? false;
    _images.addAll(product?.images ?? const []);
    if (product == null || product.codes.isEmpty) {
      _codes.add(_CodeDraft.newCode(isActive: true));
    } else {
      _codes.addAll(product.codes.map(_CodeDraft.fromCode));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasesController.dispose();
    _descriptionController.dispose();
    for (final code in _codes) {
      code.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Produkt bearbeiten' : 'Produkt hinzufügen'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Speichern'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !isEditing,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Produktname *',
                prefixIcon: Icon(Icons.shopping_basket_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Bitte einen eindeutigen Produktnamen eingeben.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _aliasesController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Alternative Namen',
                hintText: 'z. B. Drachenfrucht, Dragon Fruit',
                helperText: 'Mehrere Namen durch Kommas trennen',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 14),
            _ImagesEditor(
              images: _images,
              productName: _nameController.text.trim(),
              onAdd: _showImageOptions,
              onSuggest: _pickSuggestedImage,
              onRemove: (index) => setState(() => _images.removeAt(index)),
              onOpen: (index) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductGalleryScreen(
                    title: _nameController.text.trim().isEmpty
                        ? 'Produktbilder'
                        : _nameController.text.trim(),
                    images: _images,
                    initialIndex: index,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: productCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Kennzeichnungen',
                prefixIcon: Icon(Icons.label_outline),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  FilterChip(
                    selected: _isOrganic,
                    onSelected: (selected) =>
                        setState(() => _isOrganic = selected),
                    avatar: const Icon(Icons.eco_outlined),
                    label: const Text('Bio'),
                    selectedColor: const Color(0xFFCDECCF),
                  ),
                  FilterChip(
                    selected: _isPromotion,
                    onSelected: (selected) =>
                        setState(() => _isPromotion = selected),
                    avatar: const Icon(Icons.local_offer_outlined),
                    label: const Text('Aktion'),
                    selectedColor: const Color(0xFFFFD8CC),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Hinweis (optional)',
                hintText: 'z. B. Barcode fehlt häufig auf der Packung',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Codes und Preise',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${_codes.length}'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Höchstens ein Eintrag ist aktuell. Sind alle veraltet, wird das '
              'gesamte Produkt deaktiviert.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _codes.length; index++) ...[
              _CodeEditorCard(
                key: ValueKey(_codes[index].draftId),
                draft: _codes[index],
                canRemove: _codes[index].original == null && _codes.length > 1,
                onActiveChanged: (selected) => selected
                    ? _makeActive(index)
                    : setState(() => _codes[index].isActive = false),
                onRemove: () => _removeCode(index),
                onTypeChanged: (type) =>
                    setState(() => _codes[index].type = type),
                onScan: () => _scanBarcode(index),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _addCode,
              icon: const Icon(Icons.add),
              label: const Text('Neuen Code oder Preis hinzufügen'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            if (_codes.any((code) => code.isActive)) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  for (final code in _codes) {
                    code.isActive = false;
                  }
                }),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Gesamtes Produkt als veraltet markieren'),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                isEditing ? 'Änderungen speichern' : 'Produkt speichern',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCode() {
    setState(() {
      for (final code in _codes) {
        code.isActive = false;
      }
      _codes.add(_CodeDraft.newCode(isActive: true));
    });
  }

  void _makeActive(int index) {
    setState(() {
      for (var i = 0; i < _codes.length; i++) {
        _codes[i].isActive = i == index;
      }
    });
  }

  void _removeCode(int index) {
    if (_codes[index].original != null || _codes.length <= 1) return;
    setState(() {
      _codes.removeAt(index).dispose();
    });
  }

  Future<void> _scanBarcode(int index) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() => _codes[index].valueController.text = result);
  }

  Future<void> _showImageOptions() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Aus Galerie/Downloads wählen'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              enabled: _nameController.text.trim().isNotEmpty && unsplashAccessKey.isNotEmpty,
              leading: const Icon(Icons.image_search),
              title: const Text('Bilder im Internet vorschlagen'),
              subtitle: Text(
                _nameController.text.trim().isEmpty
                    ? 'Zuerst einen Produktnamen eingeben'
                    : unsplashAccessKey.isEmpty
                        ? 'Kein Unsplash-Zugriffsschlüssel konfiguriert!'
                        : 'Passende Bilder für „${_nameController.text.trim()}“',
              ),
              onTap: _nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, 'internet'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection == 'internet') {
      await _pickSuggestedImage();
      return;
    }
    final source = selection == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1400,
      );
      if (picked == null || !mounted) return;
      final storedPath = await AppScope.of(context).importPickedImage(picked);
      if (!mounted) return;
      _addImage(storedPath);
    } catch (error) {
      if (mounted) _showError('Bild konnte nicht übernommen werden: $error');
    }
  }

  Future<void> _pickSuggestedImage() async {
    final suggestion = await Navigator.of(context).push<RemoteImageSuggestion>(
      MaterialPageRoute<RemoteImageSuggestion>(
        builder: (_) => InternetImageSearchScreen(
          initialQuery: _nameController.text.trim(),
        ),
      ),
    );
    if (suggestion == null || !mounted) return;
    try {
      final storedPath = await AppScope.of(context)
          .importImageFromUrl(suggestion.imageUrl);
      if (!mounted) return;
      _addImage(storedPath, suggestion: suggestion);
    } catch (error) {
      if (mounted) {
        _showError('Ausgewähltes Bild konnte nicht geladen werden: $error');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_codes.where((code) => code.isActive).length > 1) {
      _showError('Es darf höchstens ein Code aktuell sein.');
      return;
    }
    final uniqueCodes = <String>{};
    for (final code in _codes) {
      final key =
          '${code.type.name}:${code.normalizedValue}:${code.displayCategoryValue}';
      if (!uniqueCodes.add(key)) {
        _showError('Derselbe Code ist mehrfach eingetragen.');
        return;
      }
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final productId = _productId;
    final builtCodes = <ProductCode>[];
    for (final draft in _codes) {
      final original = draft.original;
      final codeChanged =
          original != null &&
          (original.type != draft.type ||
              original.value != draft.normalizedValue ||
              (original.displayCategory ?? '') != draft.displayCategoryValue);
      if (original != null &&
          original.isActive &&
          draft.isActive &&
          codeChanged) {
        builtCodes.add(original.copyWith(isActive: false, retiredAt: now));
        builtCodes.add(
          draft.build(productId: productId, id: _uuid.v4(), now: now),
        );
      } else {
        builtCodes.add(
          draft.build(
            productId: productId,
            id: original?.id ?? _uuid.v4(),
            now: now,
          ),
        );
      }
    }

    final oldProduct = widget.product;
    final aliases = _aliasesController.text
        .split(RegExp(r'[,;\n]'))
        .map((alias) => alias.trim())
        .where((alias) => alias.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final images = <ProductImageData>[
      for (var index = 0; index < _images.length; index++)
        _images[index].copyWith(productId: productId, sortOrder: index),
    ];
    final product = Product(
      id: productId,
      name: _nameController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      aliases: aliases,
      images: images,
      isPinned: oldProduct?.isPinned ?? false,
      isOrganic: _isOrganic,
      isPromotion: _isPromotion,
      createdAt: oldProduct?.createdAt ?? now,
      updatedAt: now,
      codes: builtCodes,
    );

    try {
      await AppScope.of(context).saveProduct(product);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Produkt konnte nicht gespeichert werden: $error');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _addImage(String localPath, {RemoteImageSuggestion? suggestion}) {
    if (!mounted) return;
    setState(() {
      _images.add(
        ProductImageData(
          id: _uuid.v4(),
          productId: _productId,
          localPath: localPath,
          sourcePageUrl: suggestion?.sourcePageUrl,
          attribution: suggestion?.attribution,
          license: suggestion?.license,
          sortOrder: _images.length,
          createdAt: DateTime.now(),
        ),
      );
    });
  }
}

class _CodeDraft {
  _CodeDraft({
    required this.draftId,
    required this.type,
    required this.valueController,
    required this.displayCategoryController,
    required this.noteController,
    required this.isActive,
    this.original,
  });

  factory _CodeDraft.newCode({required bool isActive}) => _CodeDraft(
    draftId: const Uuid().v4(),
    type: ProductCodeType.plu,
    valueController: TextEditingController(),
    displayCategoryController: TextEditingController(),
    noteController: TextEditingController(),
    isActive: isActive,
  );

  factory _CodeDraft.fromCode(ProductCode code) => _CodeDraft(
    draftId: code.id,
    type: code.type,
    valueController: TextEditingController(text: code.value),
    displayCategoryController: TextEditingController(
      text: code.displayCategory ?? '',
    ),
    noteController: TextEditingController(text: code.note),
    isActive: code.isActive,
    original: code,
  );

  final String draftId;
  ProductCodeType type;
  final TextEditingController valueController;
  final TextEditingController displayCategoryController;
  final TextEditingController noteController;
  bool isActive;
  final ProductCode? original;

  String get normalizedValue {
    final raw = valueController.text.trim();
    if (type != ProductCodeType.price) return raw.replaceAll(' ', '');
    final price = double.tryParse(raw.replaceAll(',', '.'));
    return price == null ? raw.replaceAll(',', '.') : price.toStringAsFixed(2);
  }

  String get displayCategoryValue => type == ProductCodeType.cashierTile
      ? displayCategoryController.text.trim()
      : '';

  ProductCode build({
    required String productId,
    required String id,
    required DateTime now,
  }) => ProductCode(
    id: id,
    productId: productId,
    type: type,
    value: normalizedValue,
    isActive: isActive,
    note: noteController.text.trim(),
    displayCategory: displayCategoryValue.isEmpty ? null : displayCategoryValue,
    createdAt: original?.createdAt ?? now,
    retiredAt: isActive ? null : (original?.retiredAt ?? now),
  );

  void dispose() {
    valueController.dispose();
    displayCategoryController.dispose();
    noteController.dispose();
  }
}

class _CodeEditorCard extends StatelessWidget {
  const _CodeEditorCard({
    required this.draft,
    required this.canRemove,
    required this.onActiveChanged,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onScan,
    super.key,
  });

  final _CodeDraft draft;
  final bool canRemove;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onRemove;
  final ValueChanged<ProductCodeType> onTypeChanged;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: draft.isActive
          ? Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: .58)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                FilterChip(
                  selected: draft.isActive,
                  onSelected: onActiveChanged,
                  avatar: Icon(
                    draft.isActive ? Icons.check_circle : Icons.history,
                    size: 18,
                  ),
                  label: Text(draft.isActive ? 'Aktuell' : 'Veraltet'),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    tooltip: 'Eintrag entfernen',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ProductCodeType>(
              initialValue: draft.type,
              decoration: const InputDecoration(labelText: 'Art'),
              items: ProductCodeType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onTypeChanged(value);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.valueController,
              keyboardType: switch (draft.type) {
                ProductCodeType.price => const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                ProductCodeType.cashierTile => TextInputType.text,
                _ => TextInputType.number,
              },
              inputFormatters: switch (draft.type) {
                ProductCodeType.price => [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                ProductCodeType.cashierTile => null,
                _ => [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z-]')),
                ],
              },
              decoration: InputDecoration(
                labelText: draft.type == ProductCodeType.cashierTile
                    ? 'Kachel im Bedienerdisplay *'
                    : '${draft.type.label} *',
                hintText: draft.type.inputHint,
                suffixIcon: draft.type == ProductCodeType.barcode
                    ? IconButton(
                        tooltip: 'Mit Kamera scannen',
                        onPressed: onScan,
                        icon: const Icon(Icons.qr_code_scanner),
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte einen Wert eingeben.';
                }
                if (draft.type == ProductCodeType.price) {
                  final price = double.tryParse(value.replaceAll(',', '.'));
                  if (price == null || price < 0 || price > 9999) {
                    return 'Bitte einen gültigen Preis eingeben.';
                  }
                }
                return null;
              },
            ),
            if (draft.type == ProductCodeType.cashierTile) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: draft.displayCategoryController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Kategorie im Bedienerdisplay *',
                  hintText: 'z. B. Obst > Exoten',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Bitte die Kassen-Kategorie angeben.'
                    : null,
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Hinweis zum Code (optional)',
                hintText: 'z. B. Sonderaktion August',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagesEditor extends StatelessWidget {
  const _ImagesEditor({
    required this.images,
    required this.productName,
    required this.onAdd,
    required this.onSuggest,
    required this.onRemove,
    required this.onOpen,
  });

  final List<ProductImageData> images;
  final String productName;
  final VoidCallback onAdd;
  final VoidCallback onSuggest;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Produktbilder',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text('${images.length}'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == images.length) {
                return SizedBox(
                  width: 126,
                  child: OutlinedButton(
                    onPressed: onAdd,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 34),
                        SizedBox(height: 7),
                        Text('Bild hinzufügen', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }
              final image = images[index];
              return SizedBox(
                width: 126,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InkWell(
                        onTap: () => onOpen(index),
                        borderRadius: BorderRadius.circular(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _imageWidget(context, image),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        tooltip: 'Bild entfernen',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            child: Text(
                              'Titelbild',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Das erste Bild wird in der Produktliste verwendet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _imageWidget(BuildContext context, ProductImageData image) {
    if (image.localPath != null && File(image.localPath!).existsSync()) {
      return Image.file(File(image.localPath!), fit: BoxFit.cover);
    }
    if (image.remoteUrl != null && image.remoteUrl!.isNotEmpty) {
      return Image.network(image.remoteUrl!, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
