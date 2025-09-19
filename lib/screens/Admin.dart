import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class Admin extends StatelessWidget {
  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: Colors.white,
      body: 
      Column(children: [
        CommonHeader(pageTitle: 'Admin'),
        //This is the starting of the content within page
        Column(     
            children: [ 
              Text('Admin Page Content'),
            ],
          ),
        //The page content ends here
        ]
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }
}