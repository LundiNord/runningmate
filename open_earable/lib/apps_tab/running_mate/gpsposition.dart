import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:open_earable/apps_tab/running_mate/stat_viewer.dart';

/// A Widget that can be used to display the current GPS position and some calculated stats.
class GpsPosition extends StatefulWidget {
  const GpsPosition({super.key});
  @override
  State<GpsPosition> createState() => GpsPositionState();
}

//--------------------------------------------

/// A Widget that can be used to display the current GPS position and some calculated stats.
class GpsPositionState extends State<GpsPosition> {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final List<Position> _positionItems = <Position>[];
  Timer? gpsTimer;
  var _positionString = "Position: 0, 0";
  final ValueNotifier<double> _speed = ValueNotifier<double>(0);
  final ValueNotifier<double> _distance = ValueNotifier<double>(0);
  final ValueNotifier<double> _stepLength = ValueNotifier<double>(0);
  int _steps = 0;
  late StreamSubscription<Position> _positionStream;
  var _recording = false;

  //--------------------------- Widget State ---------------------------

  ///initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    _handlePermission();
    gpsTimer = Timer.periodic(Duration(milliseconds: 1500), (Timer t) => _updateView());
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).listen((Position? position) {
      _positionItems.add(position!);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _positionStream.cancel();
    gpsTimer?.cancel();
  }

  ///Can be called from outside to change if data should be recorded and displayed.
  void setRecording(bool value) {
    _recording = value;
    if (_recording) {
      _positionItems.clear();
    }
  }

  //--------------------------- GPS Stuff ---------------------------

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
  );

  ///Returns a string with the current GPS position.
  String _getPositionString() {
    if (_positionItems.isEmpty) {
      return "Position: 0, 0";
    }
    var position = _positionItems.last;
    return "Position: ${_round(position.latitude, 6)}, ${_round(position.longitude, 6)}";
  }

  ///Get Location Permissions from the Android OS.
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

  //--------------------------- Stats ---------------------------

  ///Getter for the Distance since recording boolean was last changed.
  double calculateDistance() {
    //in meters
    double distance = 0;
    for (int i = 0; i < _positionItems.length - 1; i++) {
      distance += Geolocator.distanceBetween(
          _positionItems[i].latitude,
          _positionItems[i].longitude,
          _positionItems[i + 1].latitude,
          _positionItems[i + 1].longitude,);
    }
    //print(distance.toString());
    return distance;
  }

  ///Getter for the Time since recording boolean was last changed.
  double calculateTime() {
    //in seconds
    if (_positionItems.isEmpty) {
      return 0;
    }
    return (_positionItems.last.timestamp.millisecondsSinceEpoch -
            _positionItems.first.timestamp.millisecondsSinceEpoch) /
        1000;
  }

  ///Getter for the mean gps speed since recording boolean was last changed.
  double calculateMeanSpeed() {
    if (_positionItems.isEmpty) {
      return 0;
    }
    return calculateDistance() / calculateTime();
  }

  ///Getter for the speed at the latest position point.
  double getSpeed() {
    //in m/s
    if (_positionItems.isEmpty) {
      return 0;
    }
    return _positionItems.last.speed;
  }

  ///Can be used from outside to set steps for step length display on the widget.
  void setSteps(int steps) {
    _steps = steps;
  }

  ///Can be used from outside to get the step length from GPS Distance data.
  double calculateStepLength(int steps) {
    //in m
    if (steps == 0 || _positionItems.isEmpty || !_recording) {
      return 0;
    }
    var distance = calculateDistance();
    return distance / steps;
  }

  //--------------------------- UI ---------------------------

  ///gets called by a timer to update the view.
  void _updateView() {
    setState(() {
      _positionString = _getPositionString();
    });
    if (_recording) {
      _speed.value = _round(getSpeed(), 2);
      _distance.value = _round(calculateDistance(), 2);
      _stepLength.value = _round(calculateStepLength(_steps), 2);
    }
  }

  ///Rounds a double to a certain number of decimal places.
  double _round(double val, int places) {
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }

  ///Builds the ui widget.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(height: 10),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _speed,
                builder: (context, value, child) {
                  return StatViewer(
                    statName: "Speed (m/s)",
                    statValue: value,
                  );
                },
              ),
              SizedBox(width: 10),
              ValueListenableBuilder<double>(
                valueListenable: _distance,
                builder: (context, value, child) {
                  return StatViewer(
                    statName: "Distance(m)",
                    statValue: value,
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _stepLength,
              builder: (context, value, child) {
                return StatViewer(
                  statName: "Step Length",
                  statValue: value,
                );
              },
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 150,
              height: 70,
              child: Text(
                _positionString,
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
