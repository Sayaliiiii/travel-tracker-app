import 'dart:convert';
// import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:steps_tracker/features/screens/travel_log.dart';
import 'package:steps_tracker/features/screens/trip_log.dart';

// import 'package:url_launcher/url_launcher.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({Key? key}) : super(key: key);

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final MapController mapController = MapController();
  bool isdistance = false;
  bool isTripInProgress = false;
  List<latLng.LatLng> polylinePoints = [];
  DateTime? startTime;
  DateTime? stopTime;
  double distance = 0.0;
  List<Map<String, dynamic>> travelLogs = [];
  bool isStartingTrip = false;
  bool isStoppingTrip = false;
  String? startLocationAddress;
  String? stopLocationAddress;
  latLng.LatLng? startLocation;
  latLng.LatLng? stopLocation;

  late Database _database;
  // SQLite database instance
  final SnackBar _snackBar = const SnackBar(
    content: Text('Your Trip has Started'),
    duration: Duration(seconds: 3),
  );
  final SnackBar _snackBar1 = const SnackBar(
    content: Text('Your trip has ended'),
    duration: Duration(seconds: 3),
  );
  @override
  void initState() {
    super.initState();
    _initLocation();
    _initializeDatabase(); // Initialize the SQLite database
  }

  Future<void> _initLocation() async {
    try {
      final currentLocation = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );
      final currentLatLng = latLng.LatLng(
        currentLocation.latitude,
        currentLocation.longitude,
      );

      final address = await getAddressFromCoordinates(
        currentLocation.latitude,
        currentLocation.longitude,
      );
      // print('Address ; $address');
      polylinePoints.add(
        latLng.LatLng(
          currentLocation.latitude,
          currentLocation.longitude,
        ),
      );
      final stopaddress = await getAddressFromCoordinates(
          stopLocation!.latitude, stopLocation!.longitude);
      // print('stop loacation: ${stopaddress}');
      // print('startlocation $startLocation');
      setState(() {
        startLocation = currentLatLng;
        startLocationAddress = address;
        stopLocationAddress = stopaddress;
        // Add this line to store the address
        mapController.move(
          latLng.LatLng(
            currentLocation.latitude,
            currentLocation.longitude,
          ),
          13.0, // Adjust the zoom level as needed
        );
      });
    } catch (e) {
      print('Failed to get location: $e');
    }
  }

  // Initialize the SQLite database
  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbpath = path.join(databasesPath, 'travel_logs.db');

    _database = await openDatabase(dbpath, version: 1,
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

    // Load travel logs from the database when the screen is initialized
    loadTravelLogs();
  }

  Future<void> startTrip() async {
    try {
      setState(() {
        isStartingTrip = true;
      });
      final currentLocation = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );
      final currentLatLng = latLng.LatLng(
        currentLocation.latitude,
        currentLocation.longitude,
      );
      final address = await getAddressFromCoordinates(
        currentLatLng.latitude,
        currentLatLng.longitude,
      );

      startTime = DateTime.now();

      setState(() {
        startLocation = currentLatLng;
        startLocationAddress = address;
        print('location today $startLocationAddress');
        isTripInProgress = true;
      });
    } catch (e) {
      print('Failed to get location: $e');
    }
  }

  Future<void> stopTrip() async {
    try {
      setState(() {
        isTripInProgress = false;
      });
      final currentLocation = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );
      final currentLatLng = latLng.LatLng(
        currentLocation.latitude,
        currentLocation.longitude,
      );
      double tripDistance = calculateDistance(startLocation, currentLatLng);
      stopLocation = currentLatLng;

      polylinePoints.add(currentLatLng);

      final stopaddress = await getAddressFromCoordinates(
        currentLatLng.latitude,
        currentLatLng.longitude,
      );
      setState(() {
        stopLocationAddress = stopaddress;
        isdistance = true;
        distance = tripDistance;
        print('distanceee $distance');
      });
      stopTime = DateTime.now();
      distance = geolocator.Geolocator.distanceBetween(
        startLocation!.latitude,
        startLocation!.longitude,
        stopLocation!.latitude,
        stopLocation!.longitude,
      );
      await saveTravelLog();
    } catch (e) {
      // Handle any errors here
      print('Error stopping trip: $e');
    }
  }

  Future<String?> getAddressFromCoordinates(
      double latitude, double longitude) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final address = decoded['display_name'] as String?;
        return address;
      }
    } catch (e) {
      print('Error fetching address: $e');
    }

    return null;
  }

  double calculateDistance(latLng.LatLng? start, latLng.LatLng? stop) {
    var p = 0.017453292519943295;
    final double lat1 = start!.latitude;
    final double lat2 = start.latitude;
    final double lon1 = start.longitude;
    final double lon2 = start.longitude;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      stop!.latitude,
      stop.longitude,
    );
  }

  Future<void> saveTravelLog() async {
    final log = {
      'start_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime!),
      'stop_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(stopTime!),
      'start_latitude': startLocationAddress,
      'stop_latitude': stopLocationAddress,
      'distance': distance,
    };

    await _database.insert('travel_log', log);

    loadTravelLogs();
  }

  Future<void> loadTravelLogs() async {
    final logs = await _database.query('travel_log',
        limit: 1, orderBy: 'start_time DESC');
    setState(() {
      travelLogs = logs;
    });
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
            SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Container(
                      height: 300, // Set the desired map height
                      child: FlutterMap(
                        options: MapOptions(
                          center: startLocation != null
                              ? latLng.LatLng(
                                  startLocation!.latitude,
                                  startLocation!.longitude,
                                )
                              : const latLng.LatLng(0, 0),
                          zoom: 17.0,
                        ),
                        nonRotatedChildren: [
                          MarkerLayer(
                            markers: [
                              if (startLocation != null)
                                Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: startLocation!,
                                  builder: (ctx) => Column(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          child: const Icon(
                                            Icons.location_on,
                                            size: 40.0,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'Start',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              if (stopLocation != null)
                                Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: stopLocation!,
                                  builder: (ctx) => Column(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          child: const Icon(
                                            Icons.location_on,
                                            size: 40.0,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'Stop',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.teal),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          buildLayer(),
                          if (polylinePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: polylinePoints,
                                  color: Colors
                                      .blueAccent, // Customize the polyline color
                                  strokeWidth:
                                      10.0, // Customize the polyline width
                                ),
                              ],
                            ),
                        ],
                        mapController: mapController,
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                          ),
                        ],
                      ),
                    ),

                    // ...

                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () async {
                              if (isTripInProgress) {
                                stopTrip();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(_snackBar1);
                                await Future.delayed(
                                    const Duration(seconds: 3));
                                // ignore: use_build_context_synchronously
                                await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors.black,
                                        title: const Text(
                                          'Your Trip Details',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Container(
                                              height: 400,
                                              width: double.maxFinite,
                                              child: ListView.builder(
                                                itemCount: travelLogs.length,
                                                itemBuilder: (context, index) {
                                                  final log = travelLogs[index];
                                                  String formattedTime = log[
                                                              'start_time'] !=
                                                          null
                                                      ? DateFormat('dd/MM/yyyy')
                                                          .format(DateTime
                                                              .parse(log[
                                                                  'start_time']))
                                                      : 'N/A';
                                                  String formattedStartTime = log[
                                                              'start_time'] !=
                                                          null
                                                      ? DateFormat('hh:mm a')
                                                          .format(DateTime
                                                              .parse(log[
                                                                  'start_time']))
                                                      : 'N/A';

                                                  String formattedStopTime = log[
                                                              'stop_time'] !=
                                                          null
                                                      ? DateFormat('hh:mm a')
                                                          .format(DateTime
                                                              .parse(log[
                                                                  'stop_time']))
                                                      : 'N/A';

                                                  return Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Text(
                                                            'Date :',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                            '  $formattedTime',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
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
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                            '${log['start_latitude']},',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
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
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                            '$formattedStartTime',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
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
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                            '${log['stop_latitude']}',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
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
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                              ' $formattedStopTime',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Text(
                                                            'Distance Traveled: ',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                          Text(
                                                            ' ${log['distance'].toStringAsFixed(2)} meters',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  );
                                                },
                                              )),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .pop(); // Close the dialog
                                            },
                                            child: const Text(
                                              'Close',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                          ),
                                        ],
                                      );
                                    });
                              } else {
                                startTrip();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(_snackBar);
                              }
                            },
                            child: Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                  color: Colors.blue[900],
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(90)),
                              child: Center(
                                  child: Text(
                                isTripInProgress ? 'Stop Trip ' : 'Start Trip',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20),
                              )),
                              // ElevatedButton(
                              //   onPressed: () async {

                              //   },
                              //   child:
                              //       Text(isTripInProgress ? 'Stop Trip' : 'Start Trip'),
                              // ),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.4,
                                height: 150,
                                decoration: BoxDecoration(
                                    color: Colors.blue[900],
                                    border: Border.all(color: Colors.white),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(
                                    child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Text(
                                    'Distance:\n${distance.toStringAsFixed(2)}meters',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20),
                                  ),
                                )),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>  TripLog(),
                                      ));
                                },
                                child: Container(
                                  height: 150,
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  decoration: BoxDecoration(
                                      color: Colors.blue[900],
                                      border: Border.all(color: Colors.white),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Center(
                                      child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'See all Your\nTravel logs',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20),
                                    ),
                                  )),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 20,
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>  TravelLogs(),
                                  ));
                            },
                            child: Container(
                              height: 50,
                              // width: MediaQuery.of(context).size.width * 0.4,
                              decoration: BoxDecoration(
                                  color: Colors.blue[900],
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'List of Distance travelled',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20),
                                ),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget buildLayer() {
    if (!isTripInProgress) {
      return CurrentLocationLayer(
        followOnLocationUpdate: FollowOnLocationUpdate.always,
        turnOnHeadingUpdate: TurnOnHeadingUpdate.never,
        style: const LocationMarkerStyle(
          marker: DefaultLocationMarker(
            child: Icon(
              Icons.location_on,
              color: Colors.white,
            ),
          ),
          showAccuracyCircle: false,
          showHeadingSector: true,
          markerSize: Size(30, 30),
          markerDirection: MarkerDirection.heading,
        ),
      );
    } else {
      // Display a placeholder or nothing when the trip is not started.
      return const SizedBox.shrink();
    }
  }
}
