import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/running_mate/gpsposition.dart';
import 'package:open_earable/apps_tab/running_mate/settings.dart';
import 'package:open_earable/apps_tab/running_mate/stat_viewer.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:async';

///
class RunningMate extends StatefulWidget {
  final OpenEarable openEarable;
  const RunningMate(this.openEarable, {super.key});
  @override
  State<RunningMate> createState() => _RunningMateState();
}

//--------------------------------------------

class _RunningMateState extends State<RunningMate> {
  final ValueNotifier<double> _countedSteps = ValueNotifier<double>(0);
  final ValueNotifier<double> _cadence = ValueNotifier<double>(0);
  final ValueNotifier<double> _speed = ValueNotifier<double>(0);
  final ValueNotifier<double> _calories = ValueNotifier<double>(0);
  final ValueNotifier<double> _time = ValueNotifier<double>(0); //in minutes.seconds
  double _stepLength = 0.7; //in meters
  double _sensitivity = 0.5; //between 0 and 1
  int _goalCadence = 180;
  int _weight = 70; //in kg
  var _startTime = DateTime.now();
  bool _earableConnected = false;
  StreamSubscription? _imuSubscription;
  bool _countingSteps = false; //if sensor data is being processed
  TextEditingController stepLengthController = TextEditingController();
  TextEditingController goalCadenceController = TextEditingController();
  TextEditingController weightController = TextEditingController();
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
  Timer? viewTimer;
  Timer? stepsTimer;

  ///Initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      _earableConnected = true;
      _setupListeners();
    }
    stepLengthController.text = _stepLength.toString();
    stepLengthController.addListener(_updateStepLength);
    goalCadenceController.text = _goalCadence.toString();
    goalCadenceController.addListener(_updateGoalCadence);
    weightController.text = _weight.toString();
    weightController.addListener(_updateWeight);
    viewTimer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => updateView());
    stepsTimer = Timer.periodic(Duration(milliseconds: 1000), (Timer t) => calculateSteps());
  }

  ///cancel the subscription to the sensor data stream when the app is closed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
    stepLengthController.dispose();
    goalCadenceController.dispose();
    weightController.dispose();
    viewTimer?.cancel();
    stepsTimer?.cancel();
  }

  void _updateStepLength() {
    setState(() {
      _stepLength = double.tryParse(stepLengthController.text) ?? _stepLength;
    });
  }

  void _updateGoalCadence() {
    setState(() {
      _goalCadence = int.tryParse(goalCadenceController.text) ?? _goalCadence;
    });
  }

  void _updateWeight() {
    setState(() {
      _weight = int.tryParse(weightController.text) ?? _goalCadence;
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
    //30Hz
    var accX = data["ACC"]["X"];
    var accY = data["ACC"]["Y"];
    var accZ = data["ACC"]["Z"];
    //ToDo
    addToBuffer(accZ);
  }
  
  void calculateSteps() { //called every second
    //compare values of last second and identify steps
    //ToDo

    
  }

  void updateView() { //called every 0,5 seconds
    if (_countingSteps) {
      int time = DateTime.now().difference(_startTime).inSeconds;
      int minutes = time ~/ 60;
      int seconds = time % 60;
      _time.value = double.parse("${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}");
      _calories.value = calculateCalories(_weight, _time.value.toDouble(), _countedSteps.value.toInt(), _stepLength).toDouble();
    }
  }

  //a ring buffer to store last acc values
  static final int _ringBufferSize = 30;
  final List<double> _ringBuffer = List.filled(_ringBufferSize, 0);
  int _pointer = 0; //point to next free slot in ring buffer
  void addToBuffer(double value) {
    _ringBuffer[_pointer] = value;
    _pointer++;
    if (_pointer == _ringBufferSize) {
      _pointer = 0;
    }
  }
  double getFromBuffer(int offset) {
    //index negative relative to pointer
    //get 1: item behind pointer -1, get 0: get last updated item
    if (offset >= 30) {
      return 0;
    }
    return _ringBuffer[(_pointer - offset) % _ringBufferSize];
  }

  ///builds OpenEarable SensorConfig
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30, //30Hz
      latency: 0,
    );
  }

  double _dp(double val, int places){
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
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
                MaterialPageRoute(
                  builder: (context) => Settings(
                    goalCadenceController: goalCadenceController,
                    stepLengthController: stepLengthController,
                    weightController: weightController,
                    sensitivity: _sensitivity,
                    onSensitivityChanged: (double value) {
                      setState(() {
                        _sensitivity = value;
                      });
                    },
                  ),
                ),
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            ValueListenableBuilder<double>(
              valueListenable: _cadence,
              builder: (context, value, child) {
                return StatViewer(
                  statName: "Cadence",
                  statValue: value,
                );
              },
            ),
            SizedBox(height: 20),
            Row(
              //crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _speed,
                  builder: (context, value, child) {
                    return StatViewer(
                      statName: "Speed",
                      statValue: value,
                    );
                  },
                ),
                SizedBox(width: 10),
                ValueListenableBuilder<double>(
                  valueListenable: _time,
                  builder: (context, value, child) {
                    return StatViewer(
                      statName: "Time",
                      statValue: value,
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              //crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _calories,
                  builder: (context, value, child) {
                    return StatViewer(
                      statName: "Calories",
                      statValue: value,
                    );
                  },
                ),
                SizedBox(width: 10),
                ValueListenableBuilder<double>(
                  valueListenable: _countedSteps,
                  builder: (context, value, child) {
                    return StatViewer(
                      statName: "Steps",
                      statValue: value,
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  splashRadius: 20,
                  icon: _countingSteps
                      ? Icon(Icons.pause)
                      : Icon(
                          Icons.play_arrow,
                        ),
                  onPressed: () {
                    setState(() {
                      _countingSteps = !_countingSteps; //changing the icon.
                      if (_countingSteps) { //Resetting the values.
                        _startTime = DateTime.now();
                        _time.value = 0;
                        _countedSteps.value = 0;
                        _calories.value = 0;
                      }
                    });
                  },
                ),
                SizedBox(width: 10),
                Text(
                  _countingSteps
                      ? "Pause Run"
                      : "Start Run",
                    style: TextStyle(fontSize: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //--------------------------- Audio Stuff ---------------------------

  void playRunningAudio(int bpm, OpenEarable openEarable, int goalBpm) {
    //app expects 30-100bpm files to be present
    String filename = "";
    int alternative = 1; //ToDo
    if (bpm < 30) {
      filename = "30";
    } else if (bpm > 200) {
      filename = "200";
    } else {
      double beats = bpm / 10;
      if (goalBpm < bpm) {
        filename = "${beats.floor() * 10}";
      } else {
        filename = "${beats.ceil() * 10}";
      }
    }
    filename = "${filename}_$alternative.wav";
    _setAudio(filename);
  }

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

  int calculateCalories(int weight, double minutes, int steps, double stepLength,) {
    //calculation based on METs (see https://runbundle.com/tools/running-calorie-calculator and https://en.wikipedia.org/wiki/Metabolic_equivalent_of_task)
    //does not take hills into account
    if (minutes == 0 || steps == 0) {return 0;}
    double speed = (steps * stepLength) / (minutes * 60); //in m/h
    double mets = _lookupMets(speed);
    return (mets * weight * minutes * 60.0).round();
  }

  double _lookupMets(double speed) {
    speed = speed * 0.000621371; //convert m/h to mph
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
