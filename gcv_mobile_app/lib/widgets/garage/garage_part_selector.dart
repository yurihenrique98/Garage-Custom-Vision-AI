import 'package:flutter/material.dart';

class GaragePartSelector extends StatefulWidget {
  final List<dynamic> parts;
  final ValueChanged<List<dynamic>> onPartsChanged;
  final double canvasLeft;
  final double canvasTop;
  final double canvasWidth;
  final double canvasHeight;

  const GaragePartSelector({
    super.key,
    required this.parts,
    required this.onPartsChanged,
    required this.canvasLeft,
    required this.canvasTop,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  State<GaragePartSelector> createState() => _GaragePartSelectorState();
}

class _GaragePartSelectorState extends State<GaragePartSelector> {
  String _selectedCategory = 'body';
  String _selectedPartType = 'body';
  int? _selectedIndex;

  static const double _imageWidth = 1024;
  static const double _imageHeight = 768;

  final List<Map<String, dynamic>> _categories = const [
    {
      'id': 'body',
      'label': 'BODY',
      'icon': Icons.directions_car,
      'parts': ['body'],
    },
    {
      'id': 'windows',
      'label': 'WINDOWS',
      'icon': Icons.crop_16_9,
      'parts': ['windows'],
    },
    {
      'id': 'lights',
      'label': 'LIGHTS',
      'icon': Icons.lightbulb_outline,
      'parts': ['left_light', 'right_light'],
    },
    {
      'id': 'wheels',
      'label': 'WHEELS',
      'icon': Icons.adjust,
      'parts': ['front_wheel', 'rear_wheel'],
    },
    {
      'id': 'bodykit',
      'label': 'BODY KIT',
      'icon': Icons.air,
      'parts': ['front_splitter', 'side_skirt', 'spoiler', 'diffuser'],
    },
  ];

  List<String> get _currentParts {
    final category = _categories.firstWhere(
      (item) => item['id'] == _selectedCategory,
      orElse: () => _categories.first,
    );
    return List<String>.from(category['parts']);
  }

  List<String> get _statusParts {
    return const [
      'body',
      'windows',
      'left_light',
      'right_light',
      'front_wheel',
      'rear_wheel',
      'front_splitter',
      'side_skirt',
      'spoiler',
      'diffuser',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = _containScale(
          widget.canvasWidth,
          widget.canvasHeight,
          _imageWidth,
          _imageHeight,
        );

        final double displayedWidth = _imageWidth * scale;
        final double displayedHeight = _imageHeight * scale;

        final double offsetX =
            widget.canvasLeft + (widget.canvasWidth - displayedWidth) / 2;
        final double offsetY =
            widget.canvasTop + (widget.canvasHeight - displayedHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...widget.parts.asMap().entries.map((entry) {
              final int index = entry.key;
              final item = entry.value;

              if (item is! Map || item['box'] == null) {
                return const SizedBox.shrink();
              }

              final List box = item['box'];
              if (box.length < 4) return const SizedBox.shrink();

              final bool selected = _selectedIndex == index;
              final String partName =
                  _shortName(item['part']?.toString() ?? 'part');

              final double x1 = offsetX + (box[0] as num).toDouble() * scale;
              final double y1 = offsetY + (box[1] as num).toDouble() * scale;
              final double x2 = offsetX + (box[2] as num).toDouble() * scale;
              final double y2 = offsetY + (box[3] as num).toDouble() * scale;

              final double boxWidth =
                  (x2 - x1).clamp(24, displayedWidth).toDouble();
              final double boxHeight =
                  (y2 - y1).clamp(24, displayedHeight).toDouble();

              return Positioned(
                left: x1,
                top: y1,
                width: boxWidth,
                height: boxHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _selectedPartType =
                          item['part']?.toString() ?? _selectedPartType;
                    });
                  },
                  onPanUpdate: (details) {
                    _moveBox(
                      index,
                      details.delta.dx / scale,
                      details.delta.dy / scale,
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.cyanAccent.withAlpha(35)
                              : Colors.blueAccent.withAlpha(20),
                          border: Border.all(
                            color: selected
                                ? Colors.cyanAccent
                                : Colors.blueAccent,
                            width: selected ? 3 : 2,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: boxWidth),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.cyanAccent
                                  : Colors.blueAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              partName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: selected ? Colors.black : Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            _resizeBox(
                              index,
                              details.delta.dx / scale,
                              details.delta.dy / scale,
                            );
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.open_in_full,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            Positioned(
              top: widget.canvasTop - 195,
              left: widget.canvasLeft,
              right: widget.canvasLeft,
              child: _buildTopBar(),
            ),

            Positioned(
              top: widget.canvasTop - 55,
              right: widget.canvasLeft,
              child: _buildSideActions(),
            ),

            Positioned(
              top: widget.canvasTop - 55,
              left: widget.canvasLeft,
              child: _buildStatusPanel(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blueAccent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _categories[index];
                final bool active = item['id'] == _selectedCategory;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final parts = List<String>.from(item['parts']);
                    setState(() {
                      _selectedCategory = item['id'];
                      _selectedPartType = parts.first;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 108,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.blueAccent
                          : Colors.black.withAlpha(165),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? Colors.blueAccent : Colors.white30,
                        width: 1.3,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          color: active ? Colors.white : Colors.white70,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item['label'],
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'PART:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentParts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final part = _currentParts[index];
                      final bool active = _selectedPartType == part;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedPartType = part;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.cyanAccent
                                : Colors.black.withAlpha(165),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  active ? Colors.cyanAccent : Colors.white38,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            _shortName(part),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active ? Colors.black : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideActions() {
    return Container(
      width: 82,
      height: 180,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(225),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.blueAccent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _actionButton(
            icon: Icons.add,
            label: 'ADD',
            color: Colors.greenAccent,
            onTap: _addBox,
          ),
          _actionButton(
            icon: Icons.copy,
            label: 'COPY',
            color: Colors.lightBlueAccent,
            onTap: _duplicateSelectedBox,
          ),
          _actionButton(
            icon: Icons.delete,
            label: 'DELETE',
            color: Colors.redAccent,
            onTap: _deleteSelectedBox,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(205),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _statusParts.map((part) {
          final int count = widget.parts.where((p) {
            return p is Map && p['part'] == part;
          }).length;

          if (count == 0 &&
              ![
                'body',
                'windows',
                'left_light',
                'right_light',
                'front_wheel',
                'rear_wheel',
              ].contains(part)) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  count > 0 ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: count > 0 ? Colors.greenAccent : Colors.white38,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    count > 1
                        ? '${_shortName(part)} x$count'
                        : _shortName(part),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _addBox() {
    final List<dynamic> updated = List<dynamic>.from(widget.parts);

    updated.add({
      'part': _selectedPartType,
      'box': _defaultBoxForPart(_selectedPartType),
      'mask_poly': [],
    });

    setState(() {
      _selectedIndex = updated.length - 1;
    });

    widget.onPartsChanged(updated);
  }

  void _duplicateSelectedBox() {
    if (_selectedIndex == null) return;
    if (_selectedIndex! < 0 || _selectedIndex! >= widget.parts.length) return;

    final item = widget.parts[_selectedIndex!];
    if (item is! Map || item['box'] == null) return;

    final List box = item['box'];
    final List<dynamic> updated = List<dynamic>.from(widget.parts);

    updated.add({
      'part': item['part'],
      'box': [
        ((box[0] as num).toDouble() + 25).clamp(0, _imageWidth),
        ((box[1] as num).toDouble() + 25).clamp(0, _imageHeight),
        ((box[2] as num).toDouble() + 25).clamp(0, _imageWidth),
        ((box[3] as num).toDouble() + 25).clamp(0, _imageHeight),
      ],
      'mask_poly': [],
    });

    setState(() {
      _selectedIndex = updated.length - 1;
    });

    widget.onPartsChanged(updated);
  }

  void _deleteSelectedBox() {
    if (_selectedIndex == null) return;
    if (_selectedIndex! < 0 || _selectedIndex! >= widget.parts.length) return;

    final List<dynamic> updated = List<dynamic>.from(widget.parts);
    updated.removeAt(_selectedIndex!);

    setState(() {
      _selectedIndex = null;
    });

    widget.onPartsChanged(updated);
  }

  void _moveBox(int index, double dx, double dy) {
    final List<dynamic> updated = List<dynamic>.from(widget.parts);
    final item = Map<String, dynamic>.from(updated[index]);
    final List box = item['box'];

    item['box'] = [
      ((box[0] as num).toDouble() + dx).clamp(0, _imageWidth),
      ((box[1] as num).toDouble() + dy).clamp(0, _imageHeight),
      ((box[2] as num).toDouble() + dx).clamp(0, _imageWidth),
      ((box[3] as num).toDouble() + dy).clamp(0, _imageHeight),
    ];

    updated[index] = item;

    setState(() {
      _selectedIndex = index;
      _selectedPartType = item['part']?.toString() ?? _selectedPartType;
    });

    widget.onPartsChanged(updated);
  }

  void _resizeBox(int index, double dx, double dy) {
    final List<dynamic> updated = List<dynamic>.from(widget.parts);
    final item = Map<String, dynamic>.from(updated[index]);
    final List box = item['box'];

    final double x1 = (box[0] as num).toDouble();
    final double y1 = (box[1] as num).toDouble();

    item['box'] = [
      x1,
      y1,
      ((box[2] as num).toDouble() + dx).clamp(x1 + 20, _imageWidth),
      ((box[3] as num).toDouble() + dy).clamp(y1 + 20, _imageHeight),
    ];

    updated[index] = item;

    setState(() {
      _selectedIndex = index;
    });

    widget.onPartsChanged(updated);
  }

  List<double> _defaultBoxForPart(String part) {
    switch (part) {
      case 'body':
        return [120, 320, 920, 620];
      case 'windows':
        return [250, 260, 720, 380];
      case 'left_light':
        return [720, 430, 900, 500];
      case 'right_light':
        return [100, 430, 260, 500];
      case 'front_wheel':
        return [650, 500, 820, 670];
      case 'rear_wheel':
        return [180, 500, 350, 670];
      case 'front_splitter':
        return [640, 560, 930, 640];
      case 'side_skirt':
        return [240, 570, 720, 650];
      case 'spoiler':
        return [130, 280, 360, 340];
      case 'diffuser':
        return [80, 560, 320, 640];
      default:
        return [400, 330, 560, 430];
    }
  }

  double _containScale(
    double containerWidth,
    double containerHeight,
    double imageWidth,
    double imageHeight,
  ) {
    final double scaleX = containerWidth / imageWidth;
    final double scaleY = containerHeight / imageHeight;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  String _shortName(String name) {
    switch (name) {
      case 'front_wheel':
        return 'FRONT WHEEL';
      case 'rear_wheel':
        return 'REAR WHEEL';
      case 'left_light':
        return 'LEFT LIGHT';
      case 'right_light':
        return 'RIGHT LIGHT';
      case 'windows':
        return 'WINDOWS';
      case 'body':
        return 'BODY';
      case 'front_splitter':
        return 'FRONT SPLITTER';
      case 'side_skirt':
        return 'SIDE SKIRT';
      case 'spoiler':
        return 'SPOILER';
      case 'diffuser':
        return 'DIFFUSER';
      case 'grille':
        return 'GRILLE';
      case 'car':
        return 'CAR AREA';
      default:
        return name.replaceAll('_', ' ').toUpperCase();
    }
  }
}