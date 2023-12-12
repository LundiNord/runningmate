import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/meditation_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/meditation_view_model.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps/posture_tracker/model/meditation_state.dart';
import 'package:open_earable/apps/posture_tracker/view/meditation_settings_view.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class MeditationTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  MeditationTrackerView(this._tracker, this._openEarable);

  @override
  State<MeditationTrackerView> createState() => _MeditationTrackerViewState();
}

class _MeditationTrackerViewState extends State<MeditationTrackerView> {
  late final MeditationViewModel _viewModel;

  // Used to store references for the timers used for the meditation
  var mainNeckTimer;
  var leftNeckTimer;
  var rightNeckTimer;

  @override
  void initState() {
    super.initState();
    this._viewModel = MeditationViewModel(widget._tracker, NeckMeditation(widget._openEarable));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MeditationViewModel>.value(
        value: _viewModel,
        builder: (context, child) =>
            Consumer<MeditationViewModel>(
                builder: (context, neckStretchViewModel, child) =>
                    Scaffold(
                      appBar: AppBar(
                        title: const Text("Guided Neck Relaxation"),
                        actions: [
                          IconButton(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingsView(this._viewModel))),
                              icon: Icon(Icons.settings)
                          ),
                        ],
                      ),
                      body: Center(
                        child: this._buildContentView(neckStretchViewModel),
                      ),
                    )));
  }

  Widget _buildContentView(MeditationViewModel neckStretchViewModel) {
    var headViews = this._createHeadViews(neckStretchViewModel);
    var stretchString = this._viewModel.meditationSettings.state.display;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(5),
          child: Visibility(
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            visible: this._viewModel.meditationSettings.state != MeditationState.noStretch,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: "Currently Stretching: \n",
                  ),
                  TextSpan(
                    text: "$stretchString",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color.fromARGB(255, 0, 186, 255),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        ...headViews.map(
              (e) =>
              FractionallySizedBox(
                widthFactor: .6,
                child: e,
              ),
        ),
        // Used to place the Meditation-Button always at the bottom
        Expanded(
          child: Container(),
        ),
        this._buildMeditationButton(neckStretchViewModel),
      ],
    );
  }

  /// Builds the actual head views using the PostureRollView
  Widget _buildHeadView(String headAssetPath,
      String neckAssetPath,
      AlignmentGeometry headAlignment,
      double roll,
      double angleThreshold,
      MeditationState state) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: MeditationRollView(
        roll: roll,
        angleThreshold: angleThreshold * 3.14 / 180,
        headAssetPath: headAssetPath,
        neckAssetPath: neckAssetPath,
        headAlignment: headAlignment,
        meditationState: state,
      ),
    );
  }

  /// Creates the Head Views that display depending on the MeditationState.
  List<Widget> _createHeadViews(neckStretchViewModel) {
    return [
      // Visible Head-Displays when not stretching
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.noStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/posture_tracker/Neck_Front.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            0,
            MeditationState.mainNeckStretch),
      ),
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.noStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/posture_tracker/Neck_Side.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            0,
            MeditationState.mainNeckStretch),
      ),

      /// Visible Widgets for the main stretch
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/posture_tracker/Neck_Front.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            7.0,
            MeditationState.mainNeckStretch),
      ),
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/neck_stretch/Neck_Main_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            50.0,
            MeditationState.mainNeckStretch),
      ),

      /// Visible Widgets for the left stretch
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.leftNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/neck_stretch/Neck_Left_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            30.0,
            MeditationState.leftNeckStretch),
      ),
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.leftNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/posture_tracker/Neck_Side.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            15.0,
            MeditationState.leftNeckStretch),
      ),

      /// Visible Widgets for the right stretch
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.rightNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/neck_stretch/Neck_Right_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            30.0,
            MeditationState.rightNeckStretch),
      ),
      Visibility(
        visible: this._viewModel.meditationSettings.state == MeditationState.rightNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/posture_tracker/Neck_Side.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            15.0,
            MeditationState.rightNeckStretch),
      ),
    ];
  }

  /// Used to start the meditation via the button
  void _startMeditation() {
    this._viewModel.startTracking();
    this._viewModel.meditation.startMeditation();
  }

  /// Used to stop the meditation via the button
  void _stopMeditation() {
    this._viewModel.stopTracking();
    this._viewModel.meditation.stopMeditation();
  }

  // Creates the Button used to start the meditation
  Widget _buildMeditationButton(MeditationViewModel neckStretchViewModel) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: Column(children: [
        ElevatedButton(
          onPressed: neckStretchViewModel.isAvailable
              ? () {
            neckStretchViewModel.isTracking
                ? _stopMeditation()
                : _startMeditation();
          }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: !neckStretchViewModel.isTracking
                ? Color(0xff77F2A1)
                : Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
          child: neckStretchViewModel.isTracking
              ? const Text("Stop Meditation")
              : const Text("Start Meditation"),
        ),
        Visibility(
          visible: !neckStretchViewModel.isAvailable,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Text(
            "No Earable Connected",
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        )
      ]),
    );
  }
}
