import 'package:flutter/material.dart';

///A widget to display numerical stats with an caption in retro style.
class StatViewer extends StatefulWidget {
  final String statName;
  final double statValue;

  const StatViewer({super.key, required this.statName, required this.statValue});

  @override
  State<StatViewer> createState() => _StatViewerState();
}

///A widget to display numerical stats with an caption in retro style.
class _StatViewerState extends State<StatViewer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: 150,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: Colors.green.shade800,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.statName,
            style: _retroText,
          ),
          Text(
            widget.statValue.toString(),
            style: _retroText,
          ),
        ],
      ),
    );
  }

  ///Retro text style.
  TextStyle get _retroText => TextStyle(
        fontSize: 20,
        color: Colors.green.shade400,
        shadows: [
          Shadow(
            color: Colors.green.shade400,
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      );
}
