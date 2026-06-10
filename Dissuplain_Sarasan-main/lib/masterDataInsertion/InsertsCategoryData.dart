import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Categories');

void insertsCategoryData() async {
databaseRef.child('1').set({'categoryID': '1', 'categoryName': 'Consumer', 'categoryCode': 'C'});
databaseRef.child('2').set({'categoryID': '2', 'categoryName': 'Prescriber', 'categoryCode': 'P'});
databaseRef.child('3').set({'categoryID': '3', 'categoryName': 'Stand Alone Medical Shops', 'categoryCode': 'S'});
databaseRef.child('4').set({'categoryID': '4', 'categoryName': 'Physiotherapy Centers', 'categoryCode': 'T'});
databaseRef.child('5').set({'categoryID': '5', 'categoryName': 'GYM/Sports', 'categoryCode': 'G'});
}
