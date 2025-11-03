// lib/Widgets/facilities_list.dart
import 'package:flutter/material.dart';

class FacilitiesList extends StatelessWidget {
  // ← NEW: Callback to fly map
  final void Function(double lat, double lng)? onFacilityTap;

  const FacilitiesList({super.key, this.onFacilityTap});

  // Real emergency facilities in Pampanga area
  static final List<Map<String, dynamic>> _facilities = [
    {
      'name': 'Pampanga Provincial Capitol Evacuation Center',
      'address': 'City of San Fernando',
      'lat': 15.0680,
      'lng': 120.6570,
      'type': 'Evacuation Center',
      'icon': Icons.location_city,
      'color': Colors.redAccent,
      'capacity': '500+ persons',
    },
    {
      'name': 'Jose B. Lingad Memorial Regional Hospital',
      'address': 'San Fernando, Pampanga',
      'lat': 15.0300,
      'lng': 120.6900,
      'type': 'Hospital',
      'icon': Icons.local_hospital,
      'color': Colors.blueAccent,
      'capacity': 'Emergency Care',
    },
    {
      'name': 'Angeles City Disaster Operations Center',
      'address': 'Holy Angel University Gym',
      'lat': 15.1357,
      'lng': 120.5898,
      'type': 'Command Center',
      'icon': Icons.security,
      'color': Colors.orangeAccent,
      'capacity': 'Coordination Hub',
    },
    {
      'name': 'Clark Freeport Relief Distribution Point',
      'address': 'Clark Parade Grounds',
      'lat': 15.1800,
      'lng': 120.5200,
      'type': 'Relief Goods',
      'icon': Icons.local_shipping,
      'color': Colors.green,
      'capacity': 'Food & Supplies',
    },
    {
      'name': 'Barangay Sindalan Flood Shelter',
      'address': 'Sindalan Elementary School',
      'lat': 15.0800,
      'lng': 120.6400,
      'type': 'Temporary Shelter',
      'icon': Icons.home,
      'color': Colors.purple,
      'capacity': '200 families',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 20),
                SizedBox(width: 6),
                Text(
                  'Emergency Facilities',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _facilities.length,
              itemBuilder: (context, index) {
                final f = _facilities[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    // ← TAP TO FLY
                    onTap: () {
                      final lat = f['lat'] as double;
                      final lng = f['lng'] as double;
                      onFacilityTap?.call(lat, lng);
                    },
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: (f['color'] as Color).withOpacity(0.2),
                      child: Icon(f['icon'], color: f['color'], size: 20),
                    ),
                    title: Text(
                      f['name'],
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['address'],
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${f['type']} • ${f['capacity']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
