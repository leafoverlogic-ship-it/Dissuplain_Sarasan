import 'package:flutter/material.dart';

void main3() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'Dissuplain',
      home: Scaffold(
        appBar: AppBar(title:Text('Dissauplain Application', style: TextStyle(color:Colors.white),),
          backgroundColor: Colors.blue,
          ),
        body: 
        Container(
          padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Welcome User'),
            SizedBox(height: 10,),
            Icon(Icons.call),
            SizedBox(height: 10,),
            ElevatedButton(
              onPressed: (){},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                ), 
              child: Text('Submit OTP')),
            SizedBox(height: 10,),
            TextField(
              decoration: InputDecoration(
                hintText: 'enter your phone number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                )),),
            Image.asset('assets/images//Dissuplain_Image.png', width: 57, height: 57, ),
            Container(
              height: 100,
              color: Colors.amber,
            )
          ],
        )
        )

      )
    );
  }
}

