import 'dart:io';
import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class Attendance extends StatelessWidget {
  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: Colors.white,
      body: 
      Column(children: [
        CommonHeader(pageTitle: 'Attendance'),
        //This is the starting of the content within page
        Column(     
            children: [ 
              Text('Attendance Page Content'),
            ],
          ),
        //The page content ends here
        ]
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }
}