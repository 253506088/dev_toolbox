import 'package:flutter/material.dart';
import 'package:dev_toolbox/tools/sql_formatter_tool.dart';
import 'package:dev_toolbox/tools/json_formatter_tool.dart';
import 'package:dev_toolbox/tools/time_converter_tool.dart';
import 'package:dev_toolbox/tools/base64_tool.dart';
import 'package:dev_toolbox/tools/md5_tool.dart';
import 'package:dev_toolbox/tools/url_tool.dart';
import 'package:dev_toolbox/tools/qr_tool.dart';
import 'package:dev_toolbox/tools/cron_tool.dart';
import 'package:dev_toolbox/tools/xml_json_tool.dart';
import 'package:dev_toolbox/tools/diff_tool.dart';

void main() {
  runApp(const DevToolboxApp());
}

class DevToolboxApp extends StatelessWidget {
  const DevToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev Toolbox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainWindow(),
    );
  }
}

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _selectedIndex = 0;

  final List<Widget> _tools = [
    const SqlFormatterTool(),
    const JsonFormatterTool(),
    const TimeConverterTool(),
    const Base64Tool(),
    const Md5Tool(),
    const UrlTool(),
    const QrTool(),
    const CronTool(),
    const XmlJsonTool(),
    const DiffTool(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.format_quote),
                label: Text('SQL'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.data_object),
                label: Text('JSON'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.access_time),
                label: Text('Time'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code),
                label: Text('Base64'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security),
                label: Text('MD5'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.link),
                label: Text('URL'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.qr_code),
                label: Text('QR Code'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Cron'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.transform),
                label: Text('XML/JSON'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.compare_arrows),
                label: Text('Diff'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _tools[_selectedIndex]),
        ],
      ),
    );
  }
}
