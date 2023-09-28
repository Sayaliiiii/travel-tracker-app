import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class TravelLogs extends StatefulWidget {
  

  @override
  State<TravelLogs> createState() => _TravelLogsState();
}

class _TravelLogsState extends State<TravelLogs> {
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

  Future<String> exportToCSVFromDatabase() async {
    try {
      const String csvFileName = "distances.csv";
      final String csvFilePath =
          "${(await getExternalStorageDirectory())!.path}/$csvFileName";

      final File file = File(csvFilePath);
      final csvFile = File(csvFilePath).openWrite();

      csvFile.writeln("Distance (meters)");

      final List<Map<String, dynamic>> logs =
          await _database!.query('travel_log');
      for (final log in logs) {
        final double distance = log['distance'];
        csvFile.writeln(distance.toStringAsFixed(2));
      }

      await csvFile.close();
      return csvFilePath;
    } catch (e) {
      print("Error exporting distance data to CSV: $e");
      return "";
    }
  }

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
                    shrinkWrap: true,
                    itemCount: travelLogs.length,
                    itemBuilder: (context, index) {
                      final log = travelLogs[index];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        elevation: 5,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.0),
                              color: Colors.blue[900],
                              border:
                                  Border.all(color: Colors.white, width: 4)),
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                        ),
                      );
                    },
                  ),
                ),
                InkWell(
                    onTap: () async {
                      final csvFilePath = await exportToCSVFromDatabase();

                      if (csvFilePath.isNotEmpty) {
                        final result = await OpenFile.open(csvFilePath);

                        if (result.type != ResultType.done) {
                          print("Error opening CSV file");
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error exporting CSV file"),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 60,
                      // width: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            width: 5,
                            color: const Color.fromARGB(255, 12, 53, 114),
                          )),
                      child: const Center(
                        child: Text(
                          'Export to CSV',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
