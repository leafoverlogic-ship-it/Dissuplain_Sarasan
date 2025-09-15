// File: lib/screens/PhoneOTP.dart

import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class PhoneOTP extends StatefulWidget {
  final String phone;

  const PhoneOTP({Key? key, required this.phone}) : super(key: key);

  @override
  _PhoneOTPState createState() => _PhoneOTPState();
}

class _PhoneOTPState extends State<PhoneOTP> {
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());

  void _confirmOTP() {
    final otp = _otpControllers.map((c) => c.text).join();
    print('Entered OTP: $otp');
    // TODO: Add OTP verification logic here
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextField(
        controller: _otpControllers[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < _otpControllers.length - 1) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background white
      body: SafeArea(
        child: Column(
          children: [
            CommonHeader(pageTitle: ''),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('< back to enter phone number'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter OTP',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We have sent an OTP on ${widget.phone}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) => _buildOtpBox(index)),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }
}
