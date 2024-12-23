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

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;
  bool positionStreamStarted = false;

  //--------------------------- GPS Stuff ---------------------------

  ///initialisation for the Widget.
  @override
  void initState() {
    super.initState();
    _toggleServiceStatusStream();
  }

  @override
  void dispose() {
    super.dispose();
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
  }

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

  void _toggleServiceStatusStream() {
    if (_serviceStatusStreamSubscription == null) {
      final serviceStatusStream = _geolocatorPlatform.getServiceStatusStream();
      _serviceStatusStreamSubscription =
          serviceStatusStream.handleError((error) {
            _serviceStatusStreamSubscription?.cancel();
            _serviceStatusStreamSubscription = null;
          }).listen((serviceStatus) {
            String serviceStatusValue;
            if (serviceStatus == ServiceStatus.enabled) {
              if (positionStreamStarted) {
                _toggleListening();
              }
            } else {
              if (_positionStreamSubscription != null) {
                setState(() {
                  _positionStreamSubscription?.cancel();
                  _positionStreamSubscription = null;
                });
              }
            }
          });
    }
  }

  void _toggleListening() {
    if (_positionStreamSubscription == null) {
      final positionStream = _geolocatorPlatform.getPositionStream();
      _positionStreamSubscription = positionStream.handleError((error) {
        _positionStreamSubscription?.cancel();
        _positionStreamSubscription = null;
      }).listen(_positionItems.add);
      _positionStreamSubscription?.pause();
    }
    setState(() {
      if (_positionStreamSubscription == null) {
        return;
      }
      if (_positionStreamSubscription!.isPaused) {
        _positionStreamSubscription!.resume();
      } else {
        _positionStreamSubscription!.pause();
      }
    });
  }

  //--------------------------- UI Stuff ---------------------------

  ///Builds the ui widget.
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text("Test"),
        Text(_geolocatorPlatform.getCurrentPosition(locationSettings: locationSettings) as String)
      ],
    );
  }

}

