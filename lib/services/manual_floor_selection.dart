// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:learning/models/floor_detection_result.dart';

// class ManualFloorSelection {
//   static int _currentFloor = 0;
//   static String _currentBuilding = 'Unknown';
//   static final StreamController<FloorSelectionData> _floorController =
//       StreamController<FloorSelectionData>.broadcast();

//   /// Get current manually selected floor
//   static int getCurrentFloor() => _currentFloor;

//   /// Get current building
//   static String getCurrentBuilding() => _currentBuilding;

//   /// Set floor manually
//   static void setFloor(int floor, {String building = 'Unknown'}) {
//     _currentFloor = floor;
//     _currentBuilding = building;
//     _floorController.add(
//       FloorSelectionData(
//         floor: floor,
//         building: building,
//         timestamp: DateTime.now(),
//       ),
//     );
//   }

//   /// Stream of floor changes
//   static Stream<FloorSelectionData> get floorStream => _floorController.stream;

//   /// Show floor selection dialog
//   static Future<int?> showFloorSelectionDialog(
//     BuildContext context, {
//     int currentFloor = 0,
//     List<int> availableFloors = const [
//       -2,
//       -1,
//       0,
//       1,
//       2,
//       3,
//       4,
//       5,
//       6,
//       7,
//       8,
//       9,
//       10,
//     ],
//     String building = 'Unknown',
//   }) async {
//     return await showDialog<int>(
//       context: context,
//       builder: (BuildContext context) {
//         return FloorSelectionDialog(
//           currentFloor: currentFloor,
//           availableFloors: availableFloors,
//           building: building,
//         );
//       },
//     );
//   }

//   /// Show building selection dialog
//   static Future<String?> showBuildingSelectionDialog(
//     BuildContext context, {
//     String currentBuilding = 'Unknown',
//     List<String> availableBuildings = const [
//       'Building A',
//       'Building B',
//       'Building C',
//     ],
//   }) async {
//     return await showDialog<String>(
//       context: context,
//       builder: (BuildContext context) {
//         return BuildingSelectionDialog(
//           currentBuilding: currentBuilding,
//           availableBuildings: availableBuildings,
//         );
//       },
//     );
//   }

//   /// Get floor detection result from manual selection
//   static FloorDetectionResult getFloorDetectionResult() {
//     return FloorDetectionResult(
//       floor: _currentFloor,
//       altitude: _currentFloor * 3.5, // Assume 3.5m per floor
//       confidence: 1.0, // Manual selection is 100% confident
//       method: 'manual',
//       error: null,
//     );
//   }

//   /// Dispose resources
//   static void dispose() {
//     _floorController.close();
//   }
// }

// class FloorSelectionDialog extends StatefulWidget {
//   final int currentFloor;
//   final List<int> availableFloors;
//   final String building;

//   const FloorSelectionDialog({
//     super.key,
//     required this.currentFloor,
//     required this.availableFloors,
//     required this.building,
//   });

//   @override
//   State<FloorSelectionDialog> createState() => _FloorSelectionDialogState();
// }

// class _FloorSelectionDialogState extends State<FloorSelectionDialog> {
//   late int selectedFloor;

//   @override
//   void initState() {
//     super.initState();
//     selectedFloor = widget.currentFloor;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Select Floor - ${widget.building}'),
//       content: SizedBox(
//         width: double.maxFinite,
//         height: 300,
//         child: GridView.builder(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 3,
//             childAspectRatio: 1.5,
//             crossAxisSpacing: 8,
//             mainAxisSpacing: 8,
//           ),
//           itemCount: widget.availableFloors.length,
//           itemBuilder: (context, index) {
//             final floor = widget.availableFloors[index];

//             return GestureDetector(
//               onTap: () {
//                 setState(() {
//                   selectedFloor = floor;
//                 });
//               },
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: floor == selectedFloor
//                       ? Theme.of(context).primaryColor
//                       : Colors.grey[200],
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: floor == selectedFloor
//                         ? Theme.of(context).primaryColor
//                         : Colors.grey,
//                     width: 2,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     floor == 0 ? 'G' : floor.toString(),
//                     style: TextStyle(
//                       color: floor == selectedFloor
//                           ? Colors.white
//                           : Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 18,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () => Navigator.of(context).pop(selectedFloor),
//           child: const Text('Select'),
//         ),
//       ],
//     );
//   }
// }

// class BuildingSelectionDialog extends StatefulWidget {
//   final String currentBuilding;
//   final List<String> availableBuildings;

//   const BuildingSelectionDialog({
//     super.key,
//     required this.currentBuilding,
//     required this.availableBuildings,
//   });

//   @override
//   State<BuildingSelectionDialog> createState() =>
//       _BuildingSelectionDialogState();
// }

// class _BuildingSelectionDialogState extends State<BuildingSelectionDialog> {
//   late String selectedBuilding;

//   @override
//   void initState() {
//     super.initState();
//     selectedBuilding = widget.currentBuilding;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Select Building'),
//       content: SizedBox(
//         width: double.maxFinite,
//         height: 200,
//         child: ListView.builder(
//           itemCount: widget.availableBuildings.length,
//           itemBuilder: (context, index) {
//             final building = widget.availableBuildings[index];

//             return ListTile(
//               title: Text(building),
//               leading: Radio<String>(
//                 value: building,
//                 groupValue: selectedBuilding,
//                 onChanged: (value) {
//                   setState(() {
//                     selectedBuilding = value!;
//                   });
//                 },
//               ),
//               onTap: () {
//                 setState(() {
//                   selectedBuilding = building;
//                 });
//               },
//             );
//           },
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () => Navigator.of(context).pop(selectedBuilding),
//           child: const Text('Select'),
//         ),
//       ],
//     );
//   }
// }

// class FloorSelectionData {
//   final int floor;
//   final String building;
//   final DateTime timestamp;

//   FloorSelectionData({
//     required this.floor,
//     required this.building,
//     required this.timestamp,
//   });

//   @override
//   String toString() {
//     return 'Floor: $floor, Building: $building, Time: $timestamp';
//   }
// }
