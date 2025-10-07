import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../masterDataInsertion/InsertsClientData.dart';
import '../masterDataInsertion/InsertsRegionData.dart';
import '../masterDataInsertion/InsertsAreaData.dart';
import '../masterDataInsertion/InsertsSubAreaData.dart';
import '../masterDataInsertion/InsertsUserData.dart';
import '../masterDataInsertion/InsertsCategoryData.dart';
import '../masterDataInsertion/InsertsProductData.dart';
import '../masterDataInsertion/InsertsDistributorData.dart';
import '../masterDataInsertion/InsertsProductCategoryData.dart';
import '../masterDataInsertion/DeleteData.dart';

class InsertData extends StatefulWidget {
  const InsertData({Key? key}) : super(key: key);

  @override
  State<InsertData> createState() => _InsertDataState();
}

class _InsertDataState extends State<InsertData> {
  final postController = TextEditingController();
  bool loading = false;
  final databaseRef = FirebaseDatabase.instance.ref('Clients');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inserting data')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                insertsClientData();
              },
              child: Text("Insert Clients"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsRegionData();
              },
              child: Text("Insert Regions"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsAreaData();
              },
              child: Text("Insert Areas"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsSubAreaData();
              },
              child: Text("Insert SubAreas"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsCategoryData();
              },
              child: Text("Insert Categories"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsUserData();
              },
              child: Text("Insert Users"),
            ),
            ElevatedButton(
              onPressed: () {
                insertsProductData();
              },
              child: Text("Insert Products"),
            ),

            ElevatedButton(
              onPressed: () {
                insertsDistributorData();
              },
              child: Text("Insert Distributors"),
            ),

            ElevatedButton(
              onPressed: () {
                insertsProductCategoryData();
              },
              child: Text("Insert ProductCategory"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllClients();
              },
              child: Text("Delete Clients"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllRegions();
              },
              child: Text("Delete Regions"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllAreas();
              },
              child: Text("Delete Areas"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllSubAreas();
              },
              child: Text("Delete SubAreas"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllUsers();
              },
              child: Text("Delete Users"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllCategories();
              },
              child: Text("Delete Categories"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllProducts();
              },
              child: Text("Delete Products"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllDistributors();
              },
              child: Text("Delete Distributors"),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllProductCategory();
              },
              child: Text("Delete ProductCategory"),
            ),
          ],
        ),
      ),
    );
  }
}
