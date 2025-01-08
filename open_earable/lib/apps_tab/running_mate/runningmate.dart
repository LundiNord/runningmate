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
import 'package:circular_buffer/circular_buffer.dart';

///
class RunningMate extends StatefulWidget {
  final OpenEarable openEarable;
  const RunningMate(this.openEarable, {super.key});
  @override
  State<RunningMate> createState() => _RunningMateState();
}

//--------------------------------------------

///
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
  final _lastStepValues = CircularBuffer<int>(4); //last 2s
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
  final GlobalKey<GpsPositionState> _gpsPositionKey = GlobalKey<GpsPositionState>(); //key to access the state gps position widget

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
    addToBuffer(accZ);
  }

  ///Calculates number of steps taken based on values in the ring buffer.
  void calculateSteps() { //called every second
    //ToDo maybe with https://github.com/Oxford-step-counter/Java-Step-Counter/tree/master/src/main/java/uk/ac/ox/eng/stepcounter

    //compare last values and identify spikes over threshold
    //assumption: data does not change while this method runs
    int increaseThreshold = 50;
    int timeThreshold = 2; //in data points
    for (int i = 0; i < _ringBufferSize; i++) { //got through all data points and look fpr spikes in threshold interval
      if (getFromBuffer(i) == _emptyValue) {
        continue;
      }
      for (int j = 1; j <= timeThreshold; j++) {
        if (getFromBuffer(i) - getFromBuffer(i + j) > increaseThreshold) {
          _countedSteps.value++;
          print("Step taken: ${_countedSteps.value} | data[i]: ${getFromBuffer(i)} | data[i+j]: ${getFromBuffer(i + j)}");
          //remove already processed values
          for (int k = 0; k < j; k++) {
            addToBuffer(_emptyValue);
          }
          break;
        }
      }
    }
  }

  void updateView() { //called every 0,5 seconds
    if (_countingSteps) {
      int time = DateTime.now().difference(_startTime).inSeconds;
      int minutes = time ~/ 60;
      int seconds = time % 60;
      _time.value = double.parse("${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}");
      _calories.value = calculateCalories(_weight, time, _countedSteps.value.toInt(), _stepLength).toDouble();
      //Cadence: Running average, cadence is in steps per minute
      _lastStepValues.add(_countedSteps.value.toInt());
      _cadence.value = (_lastStepValues.last - _lastStepValues.first)/ 2 * 60;  //lastStepValues has 4 elements -> 2s
      _speed.value = _stepLength * _cadence.value / 1000 * 60; //in km/h
    }
  }

  //a ring buffer to store last acc values
  static final int _ringBufferSize = 30;
  static final double _emptyValue = -99;  //a placeholder for empty slots
  final List<double> _ringBuffer = List.filled(_ringBufferSize, _emptyValue);
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

  void calculateStepLength(){ //ToDo
    _stepLength = _gpsPositionKey.currentState!.calculateStepLength(_countedSteps.value as int);
  }

  //--------------------------- UI Stuff ---------------------------

  ///Builds the ui widgets.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Running Mate'),
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
                      _gpsPositionKey.currentState?.setRecording(_countingSteps); //tell gps widget to start/stop recording
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
            SizedBox(height: 10),
            Divider(
              color: Colors.green,
              thickness: 3,
              indent: 40,
              endIndent: 40,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 45),
                Text(
                  "GPS Stats",
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          GpsPosition(key: _gpsPositionKey),
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

  ///Simple Calorie Calculator without advanced variables like gradients. weight in kg, stepLength in m
  int calculateCalories(int weight, int seconds, int steps, double stepLength,) {
    //calculation based on METs (see https://runbundle.com/tools/running-calorie-calculator and https://en.wikipedia.org/wiki/Metabolic_equivalent_of_task)
    //does not take hills into account
    if (seconds == 0 || steps == 0) {return 0;}
    double speed = (steps * stepLength) / (seconds * 3600); //in m/h
    double mets = _lookupMets(speed);
    print("Mets:$mets");
    return (mets * weight * seconds * 3600).round();
  }

  ///Calculates the Metabolic Equivalent of Task (MET) based on the speed in m/h.
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
