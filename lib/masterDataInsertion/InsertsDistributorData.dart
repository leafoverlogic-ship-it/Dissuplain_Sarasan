import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Distributors');

void insertsDistributorData() async {
databaseRef.child('1').set({'distributorID': '1', 'firmName': 'Anantveda Naturals', 'areaID': '1|2|3|4'});
databaseRef.child('2').set({'productID': '2', 'productCode': 'Gomati Medical Store', 'productName': '6'});
}
