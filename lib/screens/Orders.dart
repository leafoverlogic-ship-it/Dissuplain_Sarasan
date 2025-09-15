import 'dart:io';
import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class Orders extends StatelessWidget {
  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: Colors.white,
      body: 
      Column(children: [
        CommonHeader(pageTitle: 'Orders'),
        //This is the starting of the content within page
        Column(     
            children: [ 
              Text('Orders Page Content'),
            ],
          ),
        //The page content ends here
        ]
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }
}