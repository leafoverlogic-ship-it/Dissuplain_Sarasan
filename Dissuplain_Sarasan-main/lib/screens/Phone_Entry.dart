import 'package:flutter/material.dart';
import 'PhoneOTP.dart';

class Phone_Entry extends StatefulWidget {
  @override
  _PhoneEntryState createState() => _PhoneEntryState();
}

class _PhoneEntryState extends State<Phone_Entry> {
  final TextEditingController _phoneController = TextEditingController();

  void _generateOTP() {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    if (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      _showError('Please enter a valid 10-digit number');
      return;
    }

    final fullPhone = '+91$phone';

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PhoneOTP(phone: fullPhone)),
    );

    print('Generating OTP for: $fullPhone');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/Dissuplain_Image.png', // <-- Update this path later
                    height: 250,
                    width: 250,
                  ),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'OTP Verification',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter your phone number to generate One Time Password',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone_android),
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(fontSize: 16, color: Colors.black),
                      hintText: 'Enter 10-digit mobile number',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Generate OTP',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
