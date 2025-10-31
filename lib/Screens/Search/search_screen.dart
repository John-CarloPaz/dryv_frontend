import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];

  final String accessToken =
      "pk.eyJ1Ijoiam9obmNhcmxvMTIzIiwiYSI6ImNtZzZrc2ZlYTBkeWwyam9pazVyc3JidWsifQ.Ydw0vEApWWCIPiZ0S1FiRw";

  void _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final url =
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$accessToken&limit=5";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _results = data["features"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _searchPlaces,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search location...",
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final place = _results[index];
          final name = place["place_name"];
          final coordinates = place["geometry"]["coordinates"];
          return ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(name),
            onTap: () {
              Navigator.pop(context, {
                "name": name,
                "lng": coordinates[0],
                "lat": coordinates[1],
              });
            },
          );
        },
      ),
    );
  }
}
