import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/running_mate/gpsposition.dart';
import 'package:open_earable/apps_tab/running_mate/settings.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

///
class RunningMate extends StatefulWidget {
  final OpenEarable openEarable;
  const RunningMate(this.openEarable, {super.key});
  @override
  State<RunningMate> createState() => _RunningMateState();
}

//--------------------------------------------

class _RunningMateState extends State<RunningMate> {
  int _countedSteps = 0;
  double stepLength = 0.7;      //in meters
  double sensitivity = 0.5;
  var startTime =  DateTime.now();
  bool _earableConnected = false;
  StreamSubscription? _imuSubscription;
  bool _countingSteps = false;
  TextEditingController stepLengthController = TextEditingController();
  List<List<double>> speedMetTable = [
    [4.0, 6.0],
    [5.0, 8.3],
    [5.2, 9.0],
    [6.0, 9.8],
    [6.7, 10.5],
    [7.0, 11.0],
    [7.5, 11.8],
    [8.0, 11.8],
    [8.6, 12.3],
    [9.0, 12.8],
    [10.0, 14.5],
    [11.0, 16.0],
    [12.0, 19.0],
    [13.0, 19.8],
    [14.0, 23.0],
  ];

  ///Initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      _earableConnected = true;
      _setupListeners();
    }
    stepLengthController.text = stepLength.toString();
    stepLengthController.addListener(_updateStepLength);
  }

  ///cancel the subscription to the sensor data stream when the app is closed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
    stepLengthController.dispose();
  }

  void _updateStepLength() {
    setState(() {
      stepLength = double.tryParse(stepLengthController.text) ?? stepLength;
    });
  }

  //--------------------------- Step Counter ---------------------------

  ///Sets up listeners to receive sensor data from the OpenEarable device.
  void _setupListeners() {
    widget.openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen((data) {
      if (_countingSteps) {
          _processSensorData(data);
      }
    });
  }

  ///Processes the sensor data received from the OpenEarable device.
  void _processSensorData(Map<String, dynamic> data) {
    var accX = data["ACC"]["X"];
    var accY = data["ACC"]["Y"];
    var accZ = data["ACC"]["Z"];
    //ToDo
  }

  ///builds OpenEarable SensorConfig
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0,
    );
  }

  //--------------------------- UI Stuff ---------------------------

  ///Builds the ui widget.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('StepCounter'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Settings(stepLengthController: stepLengthController, sensitivity: sensitivity, onSensitivityChanged: (double value) {
                  setState(() {
                    sensitivity = value;
                  });
                },),),
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
     
      body: SafeArea(child: ListView(
        children: <Widget>[
          Text("Test"),
          //GpsPosition(),

        ],
      ),
      ),
    );
  }

  //--------------------------- Audio Stuff ---------------------------

  void _setAudio(String filename) {
    if (filename == "" || !filename.endsWith('.wav')) {
      return;
    }
    widget.openEarable.audioPlayer.wavFile(filename);
  }
  void _play() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.start);
  }
  void _pause() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.pause);
  }
  void _stop() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.stop);
  }

//--------------------------- Running stats ---------------------------

  int calculateCalories(int weight, double minutes, int steps, double stepLength) {
    //calculation based on METs (see https://runbundle.com/tools/running-calorie-calculator and https://en.wikipedia.org/wiki/Metabolic_equivalent_of_task)
    //does not take hills into account
    double speed = (steps * stepLength) / (minutes * 60); //in m/h
    double mets = _lookupMets(speed);
    return (mets * weight * minutes * 60.0).round();
  }

  double _lookupMets(double speed) {
    speed = speed * 0.000621371;  //convert m/h to mph
    List<double> speeds = speedMetTable.map((pair) => pair[0]).toList();
    List<double> mets = speedMetTable.map((pair) => pair[1]).toList();
    //ensure the speed is within the bounds of the table
    if (speed <= speeds.first) {
      return mets.first;
    } else if (speed >= speeds.last) {
      return mets.last;
    }
    //interpolation between values
    for (int i = 0; i < speeds.length - 1; i++) {
      if (speed >= speeds[i] && speed <= speeds[i + 1]) {
        double t = (speed - speeds[i]) / (speeds[i + 1] - speeds[i]);
        return mets[i] + t * (mets[i + 1] - mets[i]);
      }
    }
    return 0.0; //should never be reached
  }


}
