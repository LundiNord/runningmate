import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/open_earable_icon_icons.dart';
import 'controls_tab/controls_tab.dart';
import 'sensor_data_tab/sensor_data_tab.dart';
import 'ble.dart';
import 'apps_tab.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:app_settings/app_settings.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final ThemeData materialTheme = ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary:
              Color.fromARGB(255, 54, 53, 59), //Color.fromARGB(255, 22, 22, 24)
          onPrimary: Colors.white,
          secondary: Color.fromARGB(255, 119, 242, 161),
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.black,
          background:
              Color.fromARGB(255, 22, 22, 24), //Color.fromARGB(255, 54, 53, 59)
          onBackground: Colors.white,
          surface: Color.fromARGB(255, 22, 22, 24),
          onSurface: Colors.white),
      secondaryHeaderColor: Colors.black);

  final CupertinoThemeData cupertinoTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: Color.fromARGB(255, 119, 242, 161),
    primaryContrastingColor: Color.fromARGB(255, 54, 53, 59),
    barBackgroundColor: Color.fromARGB(255, 22, 22, 24),
    scaffoldBackgroundColor: Color.fromARGB(255, 22, 22, 24),
    textTheme: CupertinoTextThemeData(
      primaryColor: Colors.white,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoApp(
        title: '🦻 OpenEarable',
        theme: cupertinoTheme,
        home: MyHomePage(),
      );
    } else {
      return MaterialApp(
        title: '🦻 OpenEarable',
        theme: materialTheme,
        home: MyHomePage(),
      );
    }
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late OpenEarable _openEarable;
  final flutterReactiveBle = FlutterReactiveBle();
  late bool alertOpen;
  late List<Widget> _widgetOptions;
  StreamSubscription? blePermissionSubscription;
  @override
  void initState() {
    super.initState();
    alertOpen = false;
    _checkBLEPermission();
    _openEarable = OpenEarable();
    _widgetOptions = <Widget>[
      ControlTab(_openEarable),
      SensorDataTab(_openEarable),
      AppsTab(_openEarable),
    ];
  }

  @override
  dispose() {
    super.dispose();
    blePermissionSubscription?.cancel();
  }

  Future<void> _checkBLEPermission() async {
    PermissionStatus status = await Permission.bluetoothConnect.request();
    PermissionStatus status2 = await Permission.location.request();
    PermissionStatus status3 = await Permission.bluetoothScan.request();
    if (status.isGranted) {
      print("BLE is working");
    }
    blePermissionSubscription =
        flutterReactiveBle.statusStream.listen((status) {
      if (status != BleStatus.ready &&
          status != BleStatus.unknown &&
          alertOpen == false) {
        alertOpen = true;
        _showBluetoothAlert(context);
      }
    });
  }

  void _showBluetoothAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoModalPopup<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => CupertinoTheme(
                data: CupertinoThemeData(),
                child: CupertinoAlertDialog(
                  title: const Text('Bluetooth disabled'),
                  content: const Text(
                      "Please make sure your device's bluetooth and location services are turned on and this app has been granted permission to use them in the app's settings.\nThis alert can only be closed if these requirements are fulfilled."),
                  actions: <CupertinoDialogAction>[
                    CupertinoDialogAction(
                      isDefaultAction: false,
                      onPressed: () {
                        AppSettings.openAppSettings();
                      },
                      child: Text(
                        'Open App Settings',
                      ),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () {
                        if (flutterReactiveBle.status == BleStatus.ready) {
                          alertOpen = false;
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        'OK',
                      ),
                    ),
                  ],
                ),
              ));
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Bluetooth disabled"),
            content: Text(
                "Please make sure your device's bluetooth and location services are turned on and this app has been granted permission to use them in the app's settings.\nThis alert can only be closed if these requirements are fulfilled."),
            actions: <Widget>[
              TextButton(
                child: Text(
                  'Open App Settings',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground),
                ),
                onPressed: () {
                  AppSettings.openAppSettings();
                },
              ),
              TextButton(
                child: Text('OK',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground)),
                onPressed: () {
                  if (flutterReactiveBle.status == BleStatus.ready) {
                    alertOpen = false;
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear),
              label: 'Controls',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.heart),
              label: 'Sensor Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              label: 'Apps',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
        tabBuilder: (BuildContext context, int index) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/earable_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  SizedBox(width: 8),
                  Text('OpenEarable'),
                ],
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  CupertinoIcons.bluetooth,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                        builder: (context) => BLEPage(_openEarable)),
                  );
                },
              ),
            ),
            backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
            child: _widgetOptions.elementAt(index),
          );
        },
      );
    } else {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Center(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 50),
              Image.asset(
                'assets/earable_logo.png',
                width: 24,
                height: 24,
              ),
              SizedBox(width: 8),
              Text('OpenEarable'),
            ],
          )),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.bluetooth,
                  color: Theme.of(context).colorScheme.secondary),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => BLEPage(_openEarable)));
              },
            ),
          ],
        ),
        body: _widgetOptions.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 3.0),
                child: Icon(
                  OpenEarableIcon.icon,
                  size: 20.0,
                ),
              ),
              label: 'Controls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_heart_outlined),
              label: 'Sensor Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps),
              label: 'Apps',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }
  }
}
