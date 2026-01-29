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
import 'package:dev_toolbox/tools/sticky_note_tool.dart';
import 'package:dev_toolbox/theme/app_theme.dart';
import 'package:dev_toolbox/constants/app_colors.dart';
import 'package:dev_toolbox/widgets/neo_block.dart';

import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const DevToolboxApp());
}

class DevToolboxApp extends StatelessWidget {
  const DevToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev Toolbox', // Updated title
      theme: AppTheme.lightTheme, // Apply custom theme
      debugShowCheckedModeBanner: false,
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
    const StickyNoteTool(),
    const DiffTool(),
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
      // Background color is handled by Theme (scaffoldBackgroundColor)
      body: Row(
        children: [
          // Navigation Rail Block (Neo-Brutalism Style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: NeoBlock(
              color: AppColors.surface,
              // Make nav block slightly narrower if possible, but IntrinsicHeight handles it
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    minWidth: 72, // Compact
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.sticky_note_2_outlined),
                        selectedIcon: Icon(Icons.sticky_note_2),
                        label: Text('Notes'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.compare_arrows),
                        label: Text('Diff'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.format_list_bulleted),
                        label: Text('SQL IN'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.code),
                        label: Text('SQL Fmt'),
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
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.code),
                            tooltip: 'GitHub',
                            onPressed: _launchUrl,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'GitHub',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content Block (Neo-Brutalism Style)
          Expanded(
            child: NeoBlock(
              margin: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              color: AppColors.surface, // White background for the tool area
              child: IndexedStack(index: _selectedIndex, children: _tools),
            ),
          ),
        ],
      ),
    );
  }
}
