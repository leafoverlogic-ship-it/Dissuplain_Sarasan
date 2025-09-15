import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Products');

void insertsProductData() async {
databaseRef.child('1').set({'productID': '1', 'productCode': 'NEO50', 'productName': 'Neerja The Oil - 50 ML'});
databaseRef.child('2').set({'productID': '2', 'productCode': 'NEO20', 'productName': 'Neerja The Oil - 20 ML'});
databaseRef.child('3').set({'productID': '3', 'productCode': 'UDS 10', 'productName': 'Udar Sanjeevani - 10 ML'});
databaseRef.child('4').set({'productID': '4', 'productCode': 'UDS 05', 'productName': 'Udar Sanjeevani - 5 ML'});
databaseRef.child('5').set({'productID': '5', 'productCode': 'UDSC', 'productName': 'Udar Sanjeevani Capsules'});
databaseRef.child('6').set({'productID': '6', 'productCode': 'SAPP', 'productName': 'Saral Plus Powder'});
databaseRef.child('7').set({'productID': '7', 'productCode': 'SAPT', 'productName': 'Saral Plus Tablets'});
databaseRef.child('8').set({'productID': '8', 'productCode': 'SAT', 'productName': 'Saral Tablets'});
databaseRef.child('9').set({'productID': '9', 'productCode': 'NEOGS ', 'productName': 'Neerja Gym / Sports'});
}
