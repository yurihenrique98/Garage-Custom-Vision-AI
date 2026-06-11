import 'package:flutter/material.dart';

class GarageModificationStatusPanel extends StatefulWidget {
  final Map<String, String> statuses;
  final Color gcvBlue;
  final double top;
  final double left;

  const GarageModificationStatusPanel({
    super.key,
    required this.statuses,
    required this.gcvBlue,
    required this.top,
    required this.left,
  });

  @override
  State<GarageModificationStatusPanel> createState() =>
      _GarageModificationStatusPanelState();
}

class _GarageModificationStatusPanelState
    extends State<GarageModificationStatusPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.statuses.entries.toList();

    return Positioned(
      top: widget.top,
      left: widget.left,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(125),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.gcvBlue.withAlpha(220),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((entry) {
              final name = entry.key;
              final status = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _statusChip(name, status),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String name, String status) {
    Color color;
    IconData icon;
    String label;

    if (status == 'good') {
      color = Colors.greenAccent;
      icon = Icons.check_circle;
      label = _expanded ? '$name: OKAY' : name;
    } else if (status == 'partial') {
      color = Colors.amberAccent;
      icon = Icons.warning_rounded;
      label = _expanded ? '$name: LIMITED' : name;
    } else if (status == 'bad') {
      color = Colors.redAccent;
      icon = Icons.cancel;
      label = _expanded ? '$name: LIMITED' : name;
    } else {
      color = Colors.white38;
      icon = Icons.radio_button_unchecked;
      label = _expanded ? '$name: PENDING' : name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(180)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}