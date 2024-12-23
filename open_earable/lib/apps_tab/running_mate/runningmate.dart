import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/running_mate/gpsposition.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

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
  var startTime =  DateTime.now();
  bool _earableConnected = false;
  StreamSubscription? _imuSubscription;
  bool _countingSteps = false;

  ///Initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      _earableConnected = true;
      _setupListeners();
    }
  }

  ///cancel the subscription to the sensor data stream when the app is closed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
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
      ),
     
      body: SafeArea(child: ListView(
        children: <Widget>[
          Text("Test"),
          GpsPosition(),],
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

}
