import 'package:flutter/material.dart';
import 'package:dev_toolbox/tools/sql_in_formatter_tool.dart';
import 'package:dev_toolbox/tools/sql_format_tool.dart';
import 'package:dev_toolbox/tools/json_formatter_tool.dart';
import 'package:dev_toolbox/tools/time_converter_tool.dart';
import 'package:dev_toolbox/tools/base64_tool.dart';
import 'package:dev_toolbox/tools/md5_tool.dart';
import 'package:dev_toolbox/tools/url_tool.dart';
import 'package:dev_toolbox/tools/qr_tool.dart';
import 'package:dev_toolbox/tools/cron_tool.dart';
import 'package:dev_toolbox/tools/xml_json_tool.dart';
import 'package:dev_toolbox/tools/diff_tool.dart';

import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const DevToolboxApp());
}

class DevToolboxApp extends StatelessWidget {
  const DevToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '开发者工具箱',
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
    const SqlInFormatterTool(),
    const SqlFormatTool(),
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

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('https://github.com/253506088/dev_toolbox');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                labelType: NavigationRailLabelType.all,
                minWidth: 80,
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: Icon(Icons.format_list_bulleted),
                    label: Text('SQL IN'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.code),
                    label: Text('SQL格式化'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.compare_arrows),
                    label: Text('Diff'),
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
                    icon: Icon(Icons.code_off),
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
                ],
                trailing: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.code),
                        tooltip: 'GitHub',
                        onPressed: _launchUrl,
                      ),
                      const Text('GitHub'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _tools[_selectedIndex]),
        ],
      ),
    );
  }
}
