import 'package:flutter/material.dart';
import '../../dataLayer/region_area_data.dart';
import '../../dataLayer/area_subarea_data.dart';
import '../../dataLayer/product_list.dart';
import '../../dataLayer/sales_hierarchy_data.dart';
import '../../dataLayer/subarea_daily_data.dart';
import '../../businessLogic/aggregation_logic.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';
import 'package:dropdown_search/dropdown_search.dart';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String selectedRegion = 'All';
  String selectedArea = 'All';
  String selectedSubArea = 'All';
  String selectedProduct = 'All';

  List<String> getAvailableAreas() {
    if (selectedRegion == 'All') {
      final allAreas = regionToAreas.values.expand((e) => e).toSet().toList();
      return ['All', ...allAreas];
    }
    return ['All', ...regionToAreas[selectedRegion] ?? []];
  }

  List<String> getAvailableSubAreas() {
    if (selectedArea == 'All') {
      if (selectedRegion == 'All') {
        final allSubAreas = areaToSubAreas.values.expand((e) => e).toSet().toList();
        return ['All', ...allSubAreas];
      } else {
        final areas = regionToAreas[selectedRegion] ?? [];
        final subAreas = areas.expand((a) => areaToSubAreas[a] ?? []).toSet().toList();
        return ['All', ...subAreas];
      }
    }
    return ['All', ...areaToSubAreas[selectedArea] ?? []];
  }
  
  @override
  Widget build(BuildContext context) {
   final metrics = calculateProductMetrics(
      region: selectedRegion,
      area: selectedArea,
      subArea: selectedSubArea,
      product: selectedProduct,
    );


    final regionManager = regionManagers[selectedRegion] ?? 'All';
    final areaManager = areaManagers[selectedArea] ?? 'All';
    final salesExecutive = selectedSubArea == 'All'
        ? 'All'
        : (salesExecutives[selectedSubArea] ?? 'All');

    return Scaffold(
      backgroundColor: Colors.white,
      body: 
      SafeArea(child:     
      SingleChildScrollView(
        child:   
        Column(
          children: [
            CommonHeader(pageTitle: 'Dashboard'), //header of the screen

            //This is the starting of the content within page
            _buildLabelDropdownRow(
              label: 'Region',
              value: selectedRegion,
              items: ['All', ...regionToAreas.keys.where((r) => r != 'All')],
              onChanged: (val) {
                setState(() {
                  selectedRegion = val!;
                  selectedArea = 'All';
                  selectedSubArea = 'All';
                });
              },
            ),

          _buildLabelDropdownRow(
              label: 'Area',
              value: selectedArea,
              items: getAvailableAreas(),
              onChanged: (val) {
                setState(() {
                  selectedArea = val!;
                  selectedSubArea = 'All';
                  regionToAreas.forEach((region, areas) {
                  if (areas.contains(selectedArea)) {
                    selectedRegion = region;
                  }
                });
                });
              },
            ),


            _buildLabelDropdownRow(
              label: 'Sub-Area',
              value: selectedSubArea,
              items: getAvailableSubAreas(),
              onChanged: (val) {
                setState(() {
                  selectedSubArea = val!;
                  areaToSubAreas.forEach((area, subareas) {
                  if (subareas.contains(selectedSubArea)) {
                    selectedArea = area;
                    regionToAreas.forEach((region, areas) {
                      if (areas.contains(selectedArea)) {
                        selectedRegion = region;
                      }
                    });
                  }
                });
                });
              },
            ),

            _buildLabelDropdownRow(
              label: 'Product',
              value: selectedProduct,
              items: productList,
              onChanged: (val) {
                setState(() {
                  selectedProduct = val!;
                  
                });
              },
            ),

            const Divider(),

            // Metric Cards Grid
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricCard("Today's Target", "Rs. ${metrics['dtd_target']}", Colors.black),
                  _buildMetricCard("Today's Achieved", "Rs. ${metrics['dtd_achieved']}", Colors.black),
                  _buildMetricCard("MTD Target", "Rs. ${metrics['mtd_target']}", Colors.black),
                  _buildMetricCard("MTD Achieved", "Rs. ${metrics['mtd_achieved']}", Colors.black),
                  _buildMetricCard("QTD Target", "Rs. ${metrics['qtd_target']}", Colors.black),
                  _buildMetricCard("QTD Achieved", "Rs. ${metrics['qtd_achieved']}", Colors.black),
                  _buildMetricCard("YTD Target", "Rs. ${metrics['ytd_target']}", Colors.black),
                  _buildMetricCard("YTD Achieved", "Rs. ${metrics['ytd_achieved']}", Colors.black),
                ],
              ),
            ),

            // Footer info
            const Divider(),
            
            _buildLabelRow("Region Manager", regionManager),
            _buildLabelRow("Area Manager", areaManager),
            _buildLabelRow("Sales Executive", salesExecutive),
          ],
        ),
      )),
      bottomNavigationBar: CommonFooter(),  //Footer of the screen
    );
  }
}

Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

 Widget _buildLabelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 16),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

Widget _buildLabelDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownSearch<String>(
              selectedItem: value,
              items: items,
              onChanged: onChanged,
              popupProps: PopupProps.menu(showSearchBox: true),
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  hintText: 'Select $label',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
