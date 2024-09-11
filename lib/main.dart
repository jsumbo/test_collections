import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collection',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const CollectionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// A stateful widget representing the collection page.
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  _CollectionPageState createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _csrfToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '231';
    _fetchCsrfToken();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Fetches the CSRF token from the server.
  Future<void> _fetchCsrfToken() async {
    const String csrfUrl = 'https://teeket-payments-e225a1f9edcf.herokuapp.com/mtnmo/csrf-token/';
    try {
      final response = await http.get(Uri.parse(csrfUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _csrfToken = data['csrfToken'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSRF token fetched successfully!')),
        );
      } else {
        throw Exception('Failed to fetch CSRF token');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching CSRF token: $e')),
      );
    }
  }

  /// Initiates the collection process by sending a POST request to the server.
  Future<void> _initiateCollection() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      _showWaitingDialog();

      const String apiUrl = 'https://teeket-payments-e225a1f9edcf.herokuapp.com/mtnmo/collect/';
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': _csrfToken ?? '',
          },
          body: jsonEncode({
            'amount': _amountController.text,
            'phone': _phoneController.text,
          }),
        );

        if (response.statusCode == 200) {
          Navigator.of(context).pop(); // Close the waiting dialog
          _showSuccessDialog();
        } else {
          throw Exception('Failed to initiate collection');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Displays a waiting dialog when the submit button is clicked.
  void _showWaitingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Waiting for approval...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
              SizedBox(height: 16),
              Text(
                'To approve, make sure you have enough balance first. If you do not see a popup prompt on your cell phone, Dial *156*1# To approve payment!',
              ),
            ],
          ),
        );
      },
    );

    // Close the dialog after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      Navigator.of(context).pop();
    });
  }

  /// Displays a success dialog when the collection is initiated successfully.
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Your Payment was successful!'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teeket Collection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  if (value.length < 4) {
                    return 'Phone number must be at least 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchCsrfToken,
                child: const Text('Fetch CSRF Token'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _csrfToken == null || _isLoading
                    ? null
                    : _initiateCollection,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}