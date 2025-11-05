import 'package:flutter/material.dart';

class LocationDetailsSheet extends StatelessWidget {
  final String name;
  final String? address;
  final VoidCallback? onNavigate;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  const LocationDetailsSheet({
    super.key,
    required this.name,
    this.address,
    this.onNavigate,
    this.onSave,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,                 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (address != null && address!.isNotEmpty) ...[
              Text(address!, style: const TextStyle(color: Colors.black54, height: 1.2)),
              const SizedBox(height: 8),
            ] else const SizedBox(height: 8),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onNavigate ?? () {},
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onSave ?? () {},
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
