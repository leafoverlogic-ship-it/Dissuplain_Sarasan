import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('ProductCategory');

void insertsProductCategoryData() async {
databaseRef.child('1').set({'categoryCode': 'C', 'productCode': 'UDS10', 'discountNET': '0.44', 'discountScheme': '0.3825', 'freeQtyPer10Scheme': '1'});
databaseRef.child('2').set({'categoryCode': 'C', 'productCode': 'UDS05', 'discountNET': '0.44', 'discountScheme': '0.44', 'freeQtyPer10Scheme': '0'});
databaseRef.child('3').set({'categoryCode': 'C', 'productCode': 'UDSC', 'discountNET': '0.44', 'discountScheme': '0.44', 'freeQtyPer10Scheme': '0'});
databaseRef.child('4').set({'categoryCode': 'C', 'productCode': 'NEO50', 'discountNET': '0.44', 'discountScheme': '0.33', 'freeQtyPer10Scheme': '2'});
databaseRef.child('5').set({'categoryCode': 'C', 'productCode': 'NEO20', 'discountNET': '0.44', 'discountScheme': '0.44', 'freeQtyPer10Scheme': '0'});
databaseRef.child('6').set({'categoryCode': 'C', 'productCode': 'SAPP', 'discountNET': '0.37', 'discountScheme': '0.249', 'freeQtyPer10Scheme': '2'});
databaseRef.child('7').set({'categoryCode': 'C', 'productCode': 'SAPT', 'discountNET': '0.37', 'discountScheme': '0.249', 'freeQtyPer10Scheme': '2'});
databaseRef.child('8').set({'categoryCode': 'P', 'productCode': 'UDS10', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('9').set({'categoryCode': 'P', 'productCode': 'UDS05', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('10').set({'categoryCode': 'P', 'productCode': 'UDSC', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('11').set({'categoryCode': 'P', 'productCode': 'NEO50', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('12').set({'categoryCode': 'P', 'productCode': 'NEO20', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('13').set({'categoryCode': 'P', 'productCode': 'SAPP', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('14').set({'categoryCode': 'P', 'productCode': 'SAPT', 'discountNET': '0.2', 'discountScheme': '0.2', 'freeQtyPer10Scheme': '0'});
databaseRef.child('15').set({'categoryCode': 'S', 'productCode': 'UDS10', 'discountNET': '0.34', 'discountScheme': '0.279', 'freeQtyPer10Scheme': '1'});
databaseRef.child('16').set({'categoryCode': 'S', 'productCode': 'UDS05', 'discountNET': '0.34', 'discountScheme': '0.34', 'freeQtyPer10Scheme': '0'});
databaseRef.child('17').set({'categoryCode': 'S', 'productCode': 'UDSC', 'discountNET': '0.34', 'discountScheme': '0.34', 'freeQtyPer10Scheme': '0'});
databaseRef.child('18').set({'categoryCode': 'S', 'productCode': 'NEO50', 'discountNET': '0.34', 'discountScheme': '0.2135', 'freeQtyPer10Scheme': '2'});
databaseRef.child('19').set({'categoryCode': 'S', 'productCode': 'NEO20', 'discountNET': '0.34', 'discountScheme': '0.34', 'freeQtyPer10Scheme': '0'});
databaseRef.child('20').set({'categoryCode': 'S', 'productCode': 'SAPP', 'discountNET': '0.34', 'discountScheme': '0.2125', 'freeQtyPer10Scheme': '2'});
databaseRef.child('21').set({'categoryCode': 'S', 'productCode': 'SAPT', 'discountNET': '0.34', 'discountScheme': '0.2125', 'freeQtyPer10Scheme': '2'});
databaseRef.child('22').set({'categoryCode': 'W', 'productCode': 'UDS10', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('23').set({'categoryCode': 'W', 'productCode': 'UDS05', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('24').set({'categoryCode': 'W', 'productCode': 'UDSC', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('25').set({'categoryCode': 'W', 'productCode': 'NEO50', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('26').set({'categoryCode': 'W', 'productCode': 'NEO20', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('27').set({'categoryCode': 'W', 'productCode': 'SAPP', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('28').set({'categoryCode': 'W', 'productCode': 'SAPT', 'discountNET': '0.5', 'discountScheme': '0.5', 'freeQtyPer10Scheme': '0'});
databaseRef.child('29').set({'categoryCode': 'G', 'productCode': 'NEOGS ', 'discountNET': '0.44', 'discountScheme': '0.328', 'freeQtyPer10Scheme': '2'});
}
