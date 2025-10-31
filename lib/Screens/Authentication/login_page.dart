import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../Providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
	const LoginPage({super.key});
	@override
	ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
	final _formKey = GlobalKey<FormState>();
	final TextEditingController _usernameController = TextEditingController();
	final TextEditingController _passwordController = TextEditingController();
	bool _loading = false;
	bool _obscure = true;

	Future<void> _login() async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _loading = true);

		final String username = _usernameController.text.trim();
		final String password = _passwordController.text;

		// TODO: replace with your real API endpoint
		final Uri url = Uri.parse('https://example.com/api/login');

		try {
			final response = await http.post(
				url,
				headers: {'Content-Type': 'application/json'},
				body: jsonEncode({'username': username, 'password': password}),
			);

			if (response.statusCode == 200) {
				final Map<String, dynamic> body = jsonDecode(response.body);
				// adjust key names according to your API (e.g. 'token', 'access_token')
				final String? token = body['token'] ?? body['access_token'];

				if (token != null && token.isNotEmpty) {
					// Save token into Riverpod state (in-memory)
					ref.read(authProvider.notifier).setToken(token);

					// Navigate to home or replace with your route
					if (!mounted) return;
					Navigator.of(context).pushReplacementNamed('/home');
					return;
				} else {
					_showError('Login succeeded but no token returned.');
				}
			} else {
				// try to extract message from API error body
				String message = 'Login failed: ${response.statusCode}';
				try {
					final Map<String, dynamic> err = jsonDecode(response.body);
					if (err.containsKey('message')) message = err['message'];
					if (err.containsKey('error')) message = err['error'];
				} catch (_) {}
				_showError(message);
			}
		} catch (e) {
			_showError('Network error: $e');
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	void _showError(String message) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(message)),
		);
	}

	@override
	void dispose() {
		_usernameController.dispose();
		_passwordController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Login')),
			body: Center(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 24),
					child: Form(
						key: _formKey,
						child: Column(
							children: [
								const FlutterLogo(size: 96),
								const SizedBox(height: 24),
								TextFormField(
									controller: _usernameController,
									decoration: const InputDecoration(
										labelText: 'Username',
										prefixIcon: Icon(Icons.person),
										border: OutlineInputBorder(),
									),
									textInputAction: TextInputAction.next,
									validator: (v) =>
											(v == null || v.trim().isEmpty) ? 'Enter username' : null,
								),
								const SizedBox(height: 12),
								TextFormField(
									controller: _passwordController,
									decoration: InputDecoration(
										labelText: 'Password',
										prefixIcon: const Icon(Icons.lock),
										border: const OutlineInputBorder(),
										suffixIcon: IconButton(
											icon:
													Icon(_obscure ? Icons.visibility : Icons.visibility_off),
											onPressed: () => setState(() => _obscure = !_obscure),
										),
									),
									obscureText: _obscure,
									textInputAction: TextInputAction.done,
									onFieldSubmitted: (_) => _login(),
									validator: (v) =>
											(v == null || v.isEmpty) ? 'Enter password' : null,
								),
								const SizedBox(height: 20),
								SizedBox(
									width: double.infinity,
									child: ElevatedButton(
										onPressed: _loading ? null : _login,
										child: _loading
												? const SizedBox(
														height: 20,
														width: 20,
														child: CircularProgressIndicator(
															strokeWidth: 2,
															color: Colors.white,
														),
													)
												: const Text('Login'),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}