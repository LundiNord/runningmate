import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/running_mate/gpsposition.dart';
import 'package:open_earable/apps_tab/running_mate/settings.dart';
import 'package:open_earable/apps_tab/running_mate/stat_viewer.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'dart:math';
import 'package:circular_buffer/circular_buffer.dart';

///The RunningMate class is the main class for the RunningMate app.
///It is responsible for the UI and the logic of the app.
///The App shows various statistics like cadence, speed, time, calories and steps while the user is running.
class RunningMate extends StatefulWidget {
  final OpenEarable openEarable;
  const RunningMate(this.openEarable, {super.key});
  @override
  State<RunningMate> createState() => _RunningMateState();
}

//--------------------------------------------

///The RunningMate class is the main class for the RunningMate app.
///It is responsible for the UI and the logic of the app.
///The App shows various statistics like cadence, speed, time, calories and steps while the user is running.
class _RunningMateState extends State<RunningMate> {
  bool _earableConnected = false;
  final ValueNotifier<double> _countedSteps = ValueNotifier<double>(0);
  final ValueNotifier<double> _cadence = ValueNotifier<double>(0);
  final ValueNotifier<double> _speed = ValueNotifier<double>(0);
  final ValueNotifier<double> _calories = ValueNotifier<double>(0);
  final ValueNotifier<double> _time = ValueNotifier<double>(0); //in minutes.seconds
  double _stepLength = 0.7; //in meters
  double _sensitivity = 0.5; //between 0 and 1
  int _goalCadence = 180; //in steps per minute
  int _weight = 70; //in kg
  var _startTime = DateTime.now();
  final _lastStepValues = CircularBuffer<int>(4); //holds values from the last 2s
  int _numberOfAlternativeSongs = 1;
  StreamSubscription? _imuSubscription;
  bool _countingSteps = false; //if sensor data is being processed
  TextEditingController stepLengthController = TextEditingController();
  TextEditingController goalCadenceController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  TextEditingController numberSongsController = TextEditingController();
  final List<List<double>> _speedMetTable = [
    //data from https://sites.google.com/site/compendiumofphysicalactivities/Activity-Categories/running
    [0.0, 0.0], //mph, METs
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
  Timer? audioTimer;
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
    numberSongsController.text = _numberOfAlternativeSongs.toString();
    numberSongsController.addListener(_updateNumberOfAlternativeSongs);
    viewTimer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => _updateView());
    stepsTimer = Timer.periodic(Duration(milliseconds: 1000), (Timer t) => _calculateSteps(),);
    audioTimer = Timer.periodic(Duration(seconds: 3), (Timer t) => _updateAudio());
  }

  ///cancel the subscription to the sensor data stream and other controllers and timers when the app is closed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
    stepLengthController.dispose();
    goalCadenceController.dispose();
    weightController.dispose();
    numberSongsController.dispose();
    viewTimer?.cancel();
    stepsTimer?.cancel();
    audioTimer?.cancel();
    _stopAudio();
  }

  ///Updates the step length based on the value in the text field from the associated text controller.
  void _updateStepLength() {
    setState(() {
      _stepLength = double.tryParse(stepLengthController.text) ?? _stepLength;
    });
  }

  ///Updates the goal cadence based on the value in the text field from the associated text controller.
  void _updateGoalCadence() {
    setState(() {
      _goalCadence = int.tryParse(goalCadenceController.text) ?? _goalCadence;
    });
  }

  ///Updates the weight based on the value in the text field from the associated text controller.
  void _updateWeight() {
    setState(() {
      _weight = int.tryParse(weightController.text) ?? _goalCadence;
    });
  }

  ///Updates the number of alternative songs based on the value in the text field from the associated text controller.
  void _updateNumberOfAlternativeSongs() {
    setState(() {
      _numberOfAlternativeSongs =
          int.tryParse(numberSongsController.text) ?? _numberOfAlternativeSongs;
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
    _addToBuffer(accZ);
  }

  ///Calculates number of steps taken based on values in the ring buffer.
  void _calculateSteps() { //called every second
    //compare last values and identify spikes over threshold
    int increaseThreshold = 8; //ToDo use sensitivity
    int timeThreshold = 5; //in data points
    for (int i = 0; i < _ringBufferSize - timeThreshold; i++) {
      //got through all data points and look fpr spikes in threshold interval
      if (_getFromBuffer(i) == _emptyValue) {
        continue;
      }
      for (int j = 1; j <= timeThreshold; j++) {
        //print("Time: ${DateTime.now()} | ${getFromBuffer(i)} | ${getFromBuffer(i + j)} | ${getFromBuffer(i) - getFromBuffer(i + j)}");
        if (_getFromBuffer(i) != _emptyValue &&
            _getFromBuffer(i + j) != _emptyValue &&
            _getFromBuffer(i) - _getFromBuffer(i + j) > increaseThreshold) {
          _countedSteps.value++;
          print("Step taken: ${_countedSteps.value} Time: ${DateTime.now()}| data[i]: ${_getFromBuffer(i)} | data[i+j]: ${_getFromBuffer(i + j)} | ${_getFromBuffer(i) - _getFromBuffer(i + j)}");
          //remove already processed values
          for (int k = i; k <= i + j; k++) {
            _removeFromBuffer(k);
          }
          break; //ToDo maybe remove break
        }
      }
    }
  }

  ///Periodically updates the view of the app.
  void _updateView() {
    //called every 0,5 seconds
    if (!_earableConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Earable not connected!',
            style: TextStyle(fontSize: 20),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      if (widget.openEarable.bleManager.connected) {
        _earableConnected = true;
        _setupListeners();
      }
    }
    if (_countingSteps) {
      int time = DateTime.now().difference(_startTime).inSeconds;
      int minutes = time ~/ 60;
      int seconds = time % 60;
      _time.value = double.parse("${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}");
      _calories.value = calculateCalories(_weight, time, _countedSteps.value.toInt(), _stepLength).toDouble();
      //Cadence: Running average, cadence is in steps per minute
      _lastStepValues.add(_countedSteps.value.toInt());
      _cadence.value = _round((_lastStepValues.last - _lastStepValues.first) / 2 * 60, 4); //lastStepValues has 4 elements -> 2s
      _speed.value = _round(_stepLength * _cadence.value / 1000 * 60, 4); //in km/h
      _gpsPositionKey.currentState!.setSteps(_countedSteps.value.toInt());
    }
  }

  //a ring buffer to store last acc values
  static final int _ringBufferSize = 30;
  static final double _emptyValue = -99; //a placeholder for empty slots
  final List<double> _ringBuffer = List.filled(_ringBufferSize, _emptyValue);
  int _pointer = 0; //point to next free slot in ring buffer
 ///ring buffer for acceleration sensor data
  void _addToBuffer(double value) {
    _ringBuffer[_pointer] = value;
    _pointer++;
    if (_pointer == _ringBufferSize) {
      _pointer = 0;
    }
  }
  ///get last acceleration value from buffer
  double _getFromBuffer(int offset) {
    //index negative relative to pointer
    //get 1: item behind pointer -1, get 0: get last updated item
    if (offset >= _ringBufferSize) {
      return 0;
    }
    return _ringBuffer[(_pointer - offset) % _ringBufferSize];
  }
  ///remove acceleration data from buffer
  void _removeFromBuffer(int offset) {
    if (offset >= _ringBufferSize) {
      return;
    }
    _ringBuffer[(_pointer - offset) % _ringBufferSize] = _emptyValue;
  }

  ///builds OpenEarable SensorConfig
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30, //30Hz
      latency: 0,
    );
  }

  ///
  void _calculateStepLength() {
    //ToDo
    _stepLength = _gpsPositionKey.currentState!.calculateStepLength(_countedSteps.value as int);
  }

  ///Rounds a double to a certain number of decimal places.
  double _round(double val, int places) {
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
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
                    songCountController: numberSongsController,
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
                      _gpsPositionKey.currentState?.setRecording(
                          _countingSteps); //tell gps widget to start/stop recording
                      if (_countingSteps) {
                        //Resetting the values.
                        _startTime = DateTime.now();
                        _time.value = 0;
                        _countedSteps.value = 0;
                        _calories.value = 0;
                      } else {
                        _pauseAudio();
                      }
                    });
                  },
                ),
                SizedBox(width: 10),
                Text(
                  _countingSteps ? "Pause Run" : "Start Run",
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
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  //--------------------------- Audio Stuff ---------------------------

  ///Plays an audio file corresponding to the current cadence and goal cadence.
  void _updateAudio() {
    if (!widget.openEarable.bleManager.connected || !_countingSteps) {
      return;
    }
    int bpm = _cadence.value.toInt();
    int goalBpm = _goalCadence;
    //app expects 30-100bpm files to be present
    String filename = "";
    int alternative = Random().nextInt(_numberOfAlternativeSongs) + 1;
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
    _playAudio();
  }

  ///Sets the audio file to be played on the OpenEarable device.
  void _setAudio(String filename) {
    if (filename == "" || !filename.endsWith('.wav')) {
      return;
    }
    widget.openEarable.audioPlayer.wavFile(filename);
  }

  void _playAudio() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.start);
  }

  void _pauseAudio() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.pause);
  }

  void _stopAudio() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.stop);
  }

//--------------------------- Running stats ---------------------------

  ///Simple Calorie Calculator without advanced variables like gradients. weight in kg, stepLength in m
  int calculateCalories(int weight, int seconds, int steps, double stepLength,) {
    //calculation based on METs (see https://runbundle.com/tools/running-calorie-calculator and https://en.wikipedia.org/wiki/Metabolic_equivalent_of_task)
    //does not take hills into account
    if (seconds == 0 || steps == 0) {
      return 0;
    }
    double speed = (steps * stepLength) / (seconds * 3600); //in m/h
    double mets = _lookupMets(speed);
    return (mets * weight * (seconds / 3600)).round();
  }

  ///Calculates the Metabolic Equivalent of Task (MET) based on the speed in m/h.
  double _lookupMets(double speed) {
    speed = speed * 0.000621371; //convert m/h to mph
    List<double> speeds = _speedMetTable.map((pair) => pair[0]).toList();
    List<double> mets = _speedMetTable.map((pair) => pair[1]).toList();
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
