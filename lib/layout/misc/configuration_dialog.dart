import 'dart:math';

import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/configuration.dart';

enum BitType { tag, indexT, offset }

class ConfigurationDialog extends StatefulWidget {
  const ConfigurationDialog({super.key});

  @override
  State<ConfigurationDialog> createState() => _ConfigurationDialogState();
}

class _ConfigurationDialogState extends State<ConfigurationDialog> {
  final Configuration config = Configuration.singleton;

  late final TextEditingController blockSizeController;
  late final TextEditingController pageSizeBlocksController;
  late final TextEditingController cacheSizeBlocksController;
  late final TextEditingController cacheSetsController;
  late final TextEditingController tlbSizeController;
  late final TextEditingController dynamicSizePagesController;
  late final TextEditingController vpnBitsController;

  @override
  void initState() {
    super.initState();

    blockSizeController = TextEditingController(
      text: config.blockSizeBytes.toString(),
    );

    pageSizeBlocksController = TextEditingController(
      text: config.pageSizeBlocks.toString(),
    );

    cacheSizeBlocksController = TextEditingController(
      text: config.cacheSizeBlocks.toString(),
    );

    cacheSetsController = TextEditingController(
      text: config.cacheSets.toString(),
    );

    tlbSizeController = TextEditingController(text: config.tlbSize.toString());

    dynamicSizePagesController = TextEditingController(
      text: config.dynamicSizePages.toString(),
    );

    vpnBitsController = TextEditingController(text: config.vpnBits.toString());

    for (final controller in [
      blockSizeController,
      pageSizeBlocksController,
      cacheSizeBlocksController,
      cacheSetsController,
      tlbSizeController,
      dynamicSizePagesController,
      vpnBitsController,
    ]) {
      controller.addListener(_onConfigurationChanged);
    }
  }

  @override
  void dispose() {
    blockSizeController.dispose();
    pageSizeBlocksController.dispose();
    cacheSizeBlocksController.dispose();
    cacheSetsController.dispose();
    tlbSizeController.dispose();
    dynamicSizePagesController.dispose();
    vpnBitsController.dispose();

    super.dispose();
  }

  void _onConfigurationChanged() {
    setState(() {});
  }

  int? _parse(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }

  String? _validateBlockSize() {
    final value = _parse(blockSizeController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (value <= 0) {
      return 'Block size must be greater than 0.';
    }

    if (!_isPowerOfTwo(value)) {
      return 'Block size must be a power of 2.';
    }

    return null;
  }

  String? _validatePageSizeBlocks() {
    final value = _parse(pageSizeBlocksController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (value <= 0) {
      return 'Page size must be greater than 0.';
    }

    if (!_isPowerOfTwo(value)) {
      return 'Page size must be a power of 2.';
    }

    return null;
  }

  String? _validateCacheSize() {
    final value = _parse(cacheSizeBlocksController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (value <= 0) {
      return 'Cache size must be greater than 0.';
    }

    return null;
  }

  String? _validateCacheSets() {
    final sets = _parse(cacheSetsController);
    final cacheSize = _parse(cacheSizeBlocksController);

    if (sets == null) {
      return 'Enter a valid number.';
    }

    if (sets <= 0) {
      return 'Cache sets must be greater than 0.';
    }

    if (!_isPowerOfTwo(sets)) {
      return 'Cache sets must be a power of 2.';
    }

    if (cacheSize != null && cacheSize > 0 && cacheSize % sets != 0) {
      return 'Cache sets must divide the cache size.';
    }

    return null;
  }

  String? _validateTlbSize() {
    final value = _parse(tlbSizeController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (value <= 0) {
      return 'TLB size must be greater than 0.';
    }

    return null;
  }

  String? _validateDynamicSizePages() {
    final value = _parse(dynamicSizePagesController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (!_isPowerOfTwo(value)) {
      return 'Physical memory pages must be a power of 2.';
    }

    if (value <= 0) {
      return 'Physical memory pages must be greater than 0.';
    }

    return null;
  }

  String? _validateVpnBits() {
    final value = _parse(vpnBitsController);

    if (value == null) {
      return 'Enter a valid number.';
    }

    if (value <= 0) {
      return 'VPN bits must be greater than 0.';
    }

    return null;
  }

  bool get _isValid {
    return _validateBlockSize() == null &&
        _validatePageSizeBlocks() == null &&
        _validateCacheSize() == null &&
        _validateCacheSets() == null &&
        _validateTlbSize() == null &&
        _validateDynamicSizePages() == null &&
        _validateVpnBits() == null;
  }

  void _saveConfiguration() {
    if (!_isValid) return;

    config.blockSizeBytes = _parse(blockSizeController)!;
    config.pageSizeBlocks = _parse(pageSizeBlocksController)!;
    config.cacheSizeBlocks = _parse(cacheSizeBlocksController)!;
    config.cacheSets = _parse(cacheSetsController)!;
    config.tlbSize = _parse(tlbSizeController)!;
    config.dynamicSizePages = _parse(dynamicSizePagesController)!;
    config.vpnBits = _parse(vpnBitsController)!;

    config.saveConfig();

    Navigator.of(context).pop();
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String? errorText,
  }) {
    final hasError = errorText != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: 'Fredoka', fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Nunito'),
          errorText: errorText,
          errorStyle: const TextStyle(fontFamily: 'Nunito'),
          filled: true,
          fillColor: hasError
              ? Colors.red.withValues(alpha: 0.06)
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? Colors.red
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? Colors.red
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryOrganization() {
    final blockSize = _parse(blockSizeController);
    final pageBlocks = _parse(pageSizeBlocksController);

    if (blockSize == null ||
        pageBlocks == null ||
        _validateBlockSize() != null ||
        _validatePageSizeBlocks() != null) {
      return _buildInvalidVisualization(
        'Enter valid block and page sizes to view the memory layout.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Memory Organization',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // Block
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Block',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$blockSize bytes',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Page
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Page',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: List.generate(pageBlocks, (index) {
                    return Expanded(
                      child: Container(
                        height: 42,
                        margin: EdgeInsets.only(
                          right: index == pageBlocks - 1 ? 0 : 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'B${index + 1}',
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$pageBlocks blocks × $blockSize bytes = '
              '${pageBlocks * blockSize} bytes/page',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheAddressBreakdown() {
    final blockSize = _parse(blockSizeController);
    final cacheSets = _parse(cacheSetsController);
    final vpnBits = _parse(vpnBitsController);
    final dynamicSizePages = _parse(dynamicSizePagesController);
    final pageBlocks = _parse(pageSizeBlocksController);

    if (blockSize == null ||
        cacheSets == null ||
        vpnBits == null ||
        dynamicSizePages == null ||
        pageBlocks == null ||
        _validateBlockSize() != null ||
        _validateCacheSets() != null ||
        _validateVpnBits() != null ||
        _validatePageSizeBlocks() != null ||
        _validateDynamicSizePages() != null) {
      return _buildInvalidVisualization(
        'Enter valid values to view the cache address breakdown.',
      );
    }

    final offsetBits = (log(blockSize) / ln2).round();
    final indexBits = (log(cacheSets) / ln2).round();
    final tagBits = (log(dynamicSizePages) / ln2).round();

    final addressBits = indexBits + offsetBits + tagBits;

    if (tagBits <= 0) {
      return _buildInvalidVisualization(
        'The selected configuration does not leave enough bits for the tag.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "[Cache's View] Physical Address Segmentation",
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          _buildBitSeparationBar(
            tagBits: tagBits,
            indexBits: indexBits,
            offsetBits: offsetBits,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _buildLegendItem('Tag', BitType.tag),
              const SizedBox(width: 14),
              _buildLegendItem('Index', BitType.indexT),
              const SizedBox(width: 14),
              _buildLegendItem('Offset', BitType.offset),
            ],
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$addressBits-bit physical address',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBitSeparationBar({
    required int tagBits,
    required int indexBits,
    required int offsetBits,
  }) {
    return Column(
      children: [
        Row(
          children: [
            _buildBitGroupLabel('TAG', tagBits),
            _buildBitGroupLabel('INDEX', indexBits),
            _buildBitGroupLabel('OFFSET', offsetBits),
          ],
        ),

        const SizedBox(height: 5),

        Row(
          children: [
            ...List.generate(
              tagBits,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _buildBitBox(BitType.tag),
                ),
              ),
            ),
            ...List.generate(
              indexBits,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _buildBitBox(BitType.indexT),
                ),
              ),
            ),
            ...List.generate(
              offsetBits,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _buildBitBox(BitType.offset),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Row(
          children: [
            ...List.generate(
              tagBits,
              (index) => Expanded(
                child: Text(
                  '${tagBits - index - 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Fredoka', fontSize: 10),
                ),
              ),
            ),
            ...List.generate(
              indexBits,
              (index) => Expanded(
                child: Text(
                  '${indexBits - index - 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Fredoka', fontSize: 10),
                ),
              ),
            ),
            ...List.generate(
              offsetBits,
              (index) => Expanded(
                child: Text(
                  '${offsetBits - index - 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Fredoka', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBitGroupLabel(String label, int bits) {
    return Expanded(
      flex: bits,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBitBox(BitType type) {
    final color = _bitColor(type);

    return AspectRatio(
      aspectRatio: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Color _bitColor(BitType type) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (type) {
      case BitType.tag:
        return colorScheme.primary;

      case BitType.indexT:
        return Colors.purpleAccent;

      case BitType.offset:
        return Colors.orangeAccent;
    }
  }

  Widget _buildLegendItem(String label, BitType type) {
    final color = _bitColor(type);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInvalidVisualization(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Memory Configuration',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // General
                      _buildSectionTitle(
                        'General Memory',
                        Icons.memory_outlined,
                      ),

                      _buildNumberField(
                        label: 'Block Size [Bytes]',
                        controller: blockSizeController,
                        errorText: _validateBlockSize(),
                      ),

                      _buildNumberField(
                        label: 'Page Size [Blocks]',
                        controller: pageSizeBlocksController,
                        errorText: _validatePageSizeBlocks(),
                      ),

                      const SizedBox(height: 22),

                      // Cache
                      _buildSectionTitle('Cache', Icons.cached_outlined),

                      _buildNumberField(
                        label: 'Cache Size (blocks)',
                        controller: cacheSizeBlocksController,
                        errorText: _validateCacheSize(),
                      ),

                      _buildNumberField(
                        label: 'Cache Sets',
                        controller: cacheSetsController,
                        errorText: _validateCacheSets(),
                      ),

                      const SizedBox(height: 22),

                      // TLB
                      _buildSectionTitle('TLB', Icons.table_rows_outlined),

                      _buildNumberField(
                        label: 'TLB Entries',
                        controller: tlbSizeController,
                        errorText: _validateTlbSize(),
                      ),

                      const SizedBox(height: 10),

                      // Physical Memory
                      _buildSectionTitle(
                        'Physical Memory',
                        Icons.storage_outlined,
                      ),

                      _buildNumberField(
                        label: 'Physical Memory Pages',
                        controller: dynamicSizePagesController,
                        errorText: _validateDynamicSizePages(),
                      ),

                      const SizedBox(height: 10),

                      // Virtual Memory
                      _buildSectionTitle(
                        'Virtual Memory',
                        Icons.language_outlined,
                      ),

                      _buildNumberField(
                        label: 'VPN Bits',
                        controller: vpnBitsController,
                        errorText: _validateVpnBits(),
                      ),

                      const SizedBox(height: 20),

                      _buildSectionTitle("Summary", Icons.settings),

                      _buildCacheAddressBreakdown(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isValid ? _saveConfiguration : null,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
