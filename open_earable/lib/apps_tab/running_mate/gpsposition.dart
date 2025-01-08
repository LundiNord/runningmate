import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

///
class GpsPosition extends StatefulWidget {
  const GpsPosition({super.key});
  @override
  State<GpsPosition> createState() => GpsPositionState();
}

//--------------------------------------------

class GpsPositionState extends State<GpsPosition> {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final List<Position> _positionItems = <Position>[];
  Timer? gpsTimer;
  var positionString = "Position: 0, 0";
  var speedString = "0.0";
  late StreamSubscription<Position> positionStream;
  var recording = false;

  //--------------------------- Widget State ---------------------------

  ///initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    gpsTimer = Timer.periodic(Duration(milliseconds: 1500), (Timer t) => updateView());
    positionStream = Geolocator.getPositionStream(locationSettings:  LocationSettings(
      accuracy: LocationAccuracy.high,),).listen((Position? position) {
      _positionItems.add(position!);
    });
  }

  @override
  void dispose() {
    super.dispose();
    positionStream.cancel();
    gpsTimer?.cancel();
  }

  void setRecording(bool value) {
    recording = value;
  }

  //--------------------------- GPS Stuff ---------------------------

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
  );

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      return;
    }
    final position = await _geolocatorPlatform.getCurrentPosition(locationSettings: locationSettings);
    _positionItems.add(position);
  }

  String getPositionString() {
    //_getCurrentPosition();
    if (_positionItems.isEmpty) {
      return "Position: 0, 0";
    }
    var position = _positionItems.last;
    return "Position: ${position.latitude}, ${position.longitude}";
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Test if location services are enabled.
    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return false;
    }
    // When we reach here, permissions are granted and we can continue accessing the position of the device.
    return true;
  }

  //--------------------------- Continuous Location ---------------------------

  void startRecording() {
    _positionItems.clear();
    //positionStream.resume();
    recording = true;
  }

  void stopRecording() {
    //positionStream.pause();
    recording = false;
  }

  //--------------------------- Stats ---------------------------

  double calculateDistance() {  //in meters
    double distance = 0;
    for (int i = 0; i < _positionItems.length - 1; i++) {
      distance += Geolocator.distanceBetween(
          _positionItems[i].latitude,
          _positionItems[i].longitude,
          _positionItems[i + 1].latitude,
          _positionItems[i + 1].longitude);
    }
    return distance;
  }

  double calculateTime() {    //in seconds
    if (_positionItems.isEmpty) {
      return 0;
    }
    return (_positionItems.last.timestamp.millisecondsSinceEpoch - _positionItems.first.timestamp.millisecondsSinceEpoch) / 1000;
  }

  double calculateMeanSpeed() {
    if (_positionItems.isEmpty) {
      return 0;
    }
    return calculateDistance() / calculateTime();
  }

  double getSpeed() { //in m/s
    if (_positionItems.isEmpty) {
      return 0;
    }
    return _positionItems.last.speed;
  }

  double calculateStepLength(int steps) {
    if (steps == 0 || _positionItems.isEmpty || !recording) {
      return 0;
    }
    var distance = calculateDistance();
    return distance / steps;
  }

  //--------------------------- UI ---------------------------

  void updateView() {
    setState(() {
      positionString = getPositionString();
      speedString = "Speed: ${getSpeed()}";
    });
    //print(positionString);


  }

  ///Builds the ui widget.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text("Test"),
        Text(positionString),
        Text(speedString),
      ],
    );
  }

}

