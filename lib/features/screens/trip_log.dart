import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class TripLog extends StatefulWidget {
  

  @override
  State<TripLog> createState() => _TripLogState();
}

class _TripLogState extends State<TripLog> {
  LocationData? startLocation;
  LocationData? stopLocation;
  DateTime? startTime;
  DateTime? stopTime;
  double distance = 0.0;
  List<Map<String, dynamic>> travelLogs = [];
  bool isStartingTrip = false;
  // Location location = Location();
  bool isTripInProgress = false;
  bool isStoppingTrip = false;
  Database? _database;
  String? streetAdd;
  String? startLocationAddress;
  String? stopLocationAddress;
  // latLng.LatLng? startLocation;
  // latLng.LatLng? stopLocation;

// String formattedStopTime = stopTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(stopTime!) : 'N/A';

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'travel_logs.db');

    _database = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
        '''
        CREATE TABLE travel_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_time TEXT,
          stop_time TEXT,
          start_latitude REAL,
        
          stop_latitude REAL,
          distance REAL
        )
        ''',
      );
    });

    loadTravelLogs();
  }

  Future<void> saveTravelLog() async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(19.1531599, 72.9402342);
    final log = {
      'start_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime!),
      'stop_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(stopTime!),
      'start_latitude': startLocationAddress,
      'stop_latitude': stopLocationAddress,
      'distance': distance,
    };
    setState(() {
      streetAdd = placemarks.reversed.last.locality;
    });
    // Insert the log into the SQLite database
    await _database!.insert('travel_log', log);

    loadTravelLogs();
  }

  Future<void> loadTravelLogs() async {
    final logs = await _database!.query('travel_log');
    setState(() {
      travelLogs = logs;
    });
  }

  // Future<String> exportToCSVFromDatabase() async {
  //   try {
  //     const String csvFileName = "distances.csv";
  //     final String csvFilePath =
  //         "${(await getExternalStorageDirectory())!.path}/$csvFileName";

  //     final File file = File(csvFilePath);
  //     final csvFile = File(csvFilePath).openWrite();

  //     csvFile.writeln("Distance (meters)");

  //     final List<Map<String, dynamic>> logs =
  //         await _database!.query('travel_log');
  //     for (final log in logs) {
  //       final double distance = log['distance'];
  //       csvFile.writeln(distance.toStringAsFixed(2));
  //     }

  //     await csvFile.close();
  //     return csvFilePath;
  //   } catch (e) {
  //     print("Error exporting distance data to CSV: $e");
  //     return "";
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue[900],
        title: const Text('Travel Tracker App'),
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/background.png', // Replace with the path to your background image
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                    child: ListView.builder(
                  itemCount: travelLogs.length,
                  itemBuilder: (context, index) {
                    final log = travelLogs[index];
                    String formattedTime = log['start_time'] != null
                        ? DateFormat('dd/MM/yyyy')
                            .format(DateTime.parse(log['start_time']))
                        : 'N/A';
                    String formattedStartTime = log['start_time'] != null
                        ? DateFormat('hh:mm a')
                            .format(DateTime.parse(log['start_time']))
                        : 'N/A';

                    String formattedStopTime = log['stop_time'] != null
                        ? DateFormat('hh:mm a')
                            .format(DateTime.parse(log['stop_time']))
                        : 'N/A';

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      margin: EdgeInsets.all(10),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue[900],
                            borderRadius: BorderRadius.circular(20)),
                        height: 300,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Date :',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  '  $formattedTime',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Wrap(
                              children: [
                                const Text(
                                  'Start Location : ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  '${log['start_latitude']},',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Start Time:',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  '$formattedStartTime',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Wrap(
                              children: [
                                const Text(
                                  'Stop Location : ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  '${log['stop_latitude']}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            // Expanded(
                            //   child: Row(
                            //     children: [
                            //       Text('Stop Location:'),
                            //       Text(
                            //           ' ${log['stop_latitude']}'),
                            //     ],
                            //   ),
                            // ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Stop Time:',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(' $formattedStopTime',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Distance Traveled: ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  ' ${log['distance'].toStringAsFixed(2)} meters',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
