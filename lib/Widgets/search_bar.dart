import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const SearchBarWidget({
    super.key,
    this.onTap,
    this.controller,
    this.onChanged,
    this.readOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    readOnly: readOnly,
                    decoration: const InputDecoration(
                      hintText: 'Search here...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.mic_none, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
