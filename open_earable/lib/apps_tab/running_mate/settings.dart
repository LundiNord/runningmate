import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Settings extends StatelessWidget {
  final TextEditingController stepLengthController;
  final ValueChanged<double> onSensitivityChanged;
  final double sensitivity;
  const Settings({super.key, required this.stepLengthController, required this.onSensitivityChanged, required this.sensitivity});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Settings'),
      ),

      body: SafeArea(child: ListView(
        children: <Widget>[
          ListTile(
            title: Text("Step length"),
            leading: Icon(Icons.open_in_full),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: stepLengthController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter step length',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
              ),
            ),
          ),
          //GpsPosition(),
          ListTile(
            title: Text("Step Counter Sensitivity"),
            leading: Icon(Icons.edgesensor_high),
            trailing: SizedBox(
              width: 280,
              child: SensiSlider(onSensitivityChanged: onSensitivityChanged, sensitivity: sensitivity),
            ),
          ),
        ],
      ),
      ),
    );
  }

}




class SensiSlider extends StatefulWidget {
  final ValueChanged<double> onSensitivityChanged;
  final double sensitivity;
  const SensiSlider({super.key, required this.onSensitivityChanged, required this.sensitivity});
  @override
  State<SensiSlider> createState() => _SensiSliderState(sensitivity: sensitivity);
}
class _SensiSliderState extends State<SensiSlider> {
  _SensiSliderState({required this.sensitivity});
  double sensitivity;
  @override
  Widget build(BuildContext context) {
    return Slider(
        value: sensitivity,
        max: 1,
        min: 0,
        divisions: 10,
        label: sensitivity.toString(),
        onChanged: (double value) {
          setState(() {
            sensitivity = value;
          });
          widget.onSensitivityChanged(value);
        },
    );
  }
}
