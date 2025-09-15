import 'package:flutter/material.dart';

class CommonFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: 
          Row(children: [
            Text("© 2025 MyApp", textAlign: TextAlign.center),

          ],) 
      ),
    );
  }
}