import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

///
class RunningMate extends StatefulWidget {
  final OpenEarable openEarable;

  const RunningMate(this.openEarable, {super.key});

  @override
  State<RunningMate> createState() => _RunningMateState();
  
}

class _RunningMateState extends State<RunningMate> {
  int _countedSteps = 0;


  /// Stellt die GUI zur Verfügung, Hier werden auch die Informationen von der Einstellungsseite abgerufen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('StepCounter'),
      ),
     
      body: SafeArea(child: Text("TestTestTest"),
        
      ),
    );
  }

}
