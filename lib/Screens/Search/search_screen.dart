import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Generate a session token per search session (good practice for billing/analytics)
  final String _sessionToken = const Uuid().v4();

  void _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final url = Uri.parse(
      "https://api.mapbox.com/search/searchbox/v1/suggest"
      "?q=$query"
      "&session_token=$_sessionToken"
      "&country=ph"
      "&access_token=$accessToken"
      "&limit=5"
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _results = data["suggestions"] ?? [];
      });
    } else {
      debugPrint("Error: ${response.body}");
    }
  }

  Future<void> _getPlaceDetails(String mapboxId) async {
    final url = Uri.parse(
      "https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId"
      "?session_token=$_sessionToken"
      "&access_token=$accessToken",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final feature = data["features"]?[0];
      if (feature != null) {
        Navigator.pop(context, {
          "name": feature["properties"]["name"] ?? feature["name"] ?? "Unknown",
          "lng": feature["geometry"]["coordinates"][0],
          "lat": feature["geometry"]["coordinates"][1],
        });
      }
    } else {
      debugPrint("Retrieve error: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: TextField(
          controller: _controller,
          onChanged: _searchPlaces,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search location...",
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final place = _results[index];
          final name = place["name"] ?? "Unnamed place";
          final address = place["place_formatted"] ?? "";
          final id = place["mapbox_id"];

          return ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(name),
            subtitle: Text(address),
            onTap: () => _getPlaceDetails(id),
          );
        },
      ),
    );
  }
}
