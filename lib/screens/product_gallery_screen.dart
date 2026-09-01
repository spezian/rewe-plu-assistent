import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product.dart';

class ProductGalleryScreen extends StatefulWidget {
  const ProductGalleryScreen({
    required this.title,
    required this.images,
    this.initialIndex = 0,
    super.key,
  });

  final String title;
  final List<ProductImageData> images;
  final int initialIndex;

  @override
  State<ProductGalleryScreen> createState() => _ProductGalleryScreenState();
}

class _ProductGalleryScreenState extends State<ProductGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_currentIndex + 1}/${widget.images.length}'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: _fullImage(widget.images[index])),
            ),
          ),
          if (_hasSourceInformation(widget.images[_currentIndex]))
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Card(
                  color: Colors.black.withValues(alpha: .78),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sourceLabel(widget.images[_currentIndex]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (widget.images[_currentIndex].sourcePageUrl != null)
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                widget.images[_currentIndex].sourcePageUrl!,
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('Quelle'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fullImage(ProductImageData image) {
    final localPath = image.localPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.contain);
    }
    final remoteUrl = image.remoteUrl;
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const CircularProgressIndicator(color: Colors.white),
        errorBuilder: (_, _, _) => const _MissingImage(),
      );
    }
    return const _MissingImage();
  }

  bool _hasSourceInformation(ProductImageData image) =>
      image.sourcePageUrl != null ||
      image.attribution != null ||
      image.license != null;

  String _sourceLabel(ProductImageData image) {
    final parts = [
      if (image.attribution?.isNotEmpty == true) image.attribution!,
      if (image.license?.isNotEmpty == true) image.license!,
      'Unsplash',
    ];
    return parts.join(' · ');
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white, size: 52),
        SizedBox(height: 10),
        Text('Bild nicht verfügbar', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}
