import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SqlFormatTool extends StatefulWidget {
  const SqlFormatTool({super.key});

  @override
  State<SqlFormatTool> createState() => _SqlFormatToolState();
}

class _SqlFormatToolState extends State<SqlFormatTool> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static final Set<String> _keywords = {
    'SELECT',
    'FROM',
    'WHERE',
    'AND',
    'OR',
    'NOT',
    'IN',
    'IS',
    'NULL',
    'LEFT',
    'RIGHT',
    'INNER',
    'OUTER',
    'CROSS',
    'JOIN',
    'ON',
    'AS',
    'UNION',
    'ALL',
    'GROUP',
    'BY',
    'ORDER',
    'ASC',
    'DESC',
    'HAVING',
    'LIMIT',
    'OFFSET',
    'INSERT',
    'INTO',
    'VALUES',
    'UPDATE',
    'SET',
    'DELETE',
    'CREATE',
    'TABLE',
    'ALTER',
    'DROP',
    'INDEX',
    'ELSE',
    'CASE',
    'WHEN',
    'THEN',
    'END',
    'EXISTS',
    'BETWEEN',
    'LIKE',
    'DISTINCT',
  };

  static final Set<String> _functions = {
    'COUNT',
    'SUM',
    'AVG',
    'MAX',
    'MIN',
    'CONCAT',
    'IFNULL',
    'COALESCE',
    'CAST',
    'CONVERT',
    'CHAR_LENGTH',
    'LENGTH',
    'UPPER',
    'LOWER',
    'TRIM',
    'SUBSTRING',
    'REPLACE',
    'DATE',
    'NOW',
    'YEAR',
    'MONTH',
    'DAY',
    'IF',
  };

  void _format() {
    String sql = _controller.text;
    if (sql.trim().isEmpty) return;
    String formatted = _formatSql(sql);
    _controller.text = formatted;
    setState(() {});
  }

  void _compress() {
    String sql = _controller.text;
    if (sql.trim().isEmpty) return;
    String compressed = sql
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    _controller.text = compressed;
    setState(() {});
  }

  String _formatSql(String sql) {
    // 1. 压缩为单行
    sql = sql
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    // 2. 移除点号前后空格
    sql = sql.replaceAllMapped(RegExp(r'\s*\.\s*'), (m) => '.');

    List<String> tokens = _tokenize(sql);
    StringBuffer result = StringBuffer();
    int indentLevel = 0;

    int i = 0;
    bool inSelectColumns = false;
    int funcDepth = 0; // 函数括号深度
    int subqueryDepth = 0; // 子查询括号深度
    int parenDepth = 0; // 普通括号深度（WHERE 条件中的）

    while (i < tokens.length) {
      String token = tokens[i];
      String upper = token.toUpperCase();
      String? next = i + 1 < tokens.length ? tokens[i + 1] : null;
      String? prev = i > 0 ? tokens[i - 1] : null;
      String? nextUpper = next?.toUpperCase();
      String? prevUpper = prev?.toUpperCase();

      // ========== SELECT ==========
      if (upper == 'SELECT') {
        _writeNewlineIndent(result, indentLevel);
        result.write('SELECT\n');
        inSelectColumns = true;
        i++;
        continue;
      }

      // ========== FROM ==========
      if (upper == 'FROM') {
        inSelectColumns = false;
        _writeNewlineIndent(result, indentLevel);
        result.write('FROM ');
        i++;
        continue;
      }

      // ========== WHERE ==========
      if (upper == 'WHERE') {
        _writeNewlineIndent(result, indentLevel);
        result.write('WHERE ');
        i++;
        continue;
      }

      // ========== AND ==========
      if (upper == 'AND' && funcDepth == 0) {
        // 在 ON 子句中保持同行，在 WHERE 中换行
        String resultStr = result.toString();
        // 检查是否在 ON 子句中（ON 后面且没有遇到 WHERE）
        int lastOn = resultStr.lastIndexOf(' ON ');
        int lastWhere = resultStr.lastIndexOf('WHERE ');
        bool inOnClause = lastOn > lastWhere;
        if (inOnClause) {
          result.write(' AND ');
        } else {
          _writeNewlineIndent(result, indentLevel);
          result.write('AND ');
        }
        i++;
        continue;
      }

      // ========== OR ==========
      if (upper == 'OR' && funcDepth == 0) {
        // 在括号内的 OR 保持同行
        if (parenDepth > 0) {
          result.write(' OR ');
        } else {
          _writeNewlineIndent(result, indentLevel);
          result.write('OR ');
        }
        i++;
        continue;
      }

      // ========== LEFT/RIGHT/INNER/OUTER/CROSS ==========
      if ({'LEFT', 'RIGHT', 'INNER', 'OUTER', 'CROSS'}.contains(upper)) {
        _writeNewlineIndent(result, indentLevel);
        result.write('$token ');
        i++;
        continue;
      }

      // ========== JOIN ==========
      if (upper == 'JOIN') {
        if (prevUpper != null &&
            {'LEFT', 'RIGHT', 'INNER', 'OUTER', 'CROSS'}.contains(prevUpper)) {
          result.write('$token ');
        } else {
          _writeNewlineIndent(result, indentLevel);
          result.write('$token ');
        }
        i++;
        continue;
      }

      // ========== ON ==========
      if (upper == 'ON') {
        result.write(' ON ');
        i++;
        continue;
      }

      // ========== UNION ==========
      if (upper == 'UNION') {
        result.write('\n\n');
        _writeIndent(result, indentLevel);
        result.write('UNION ');
        i++;
        continue;
      }

      if (upper == 'ALL' && prevUpper == 'UNION') {
        result.write('ALL\n\n');
        i++;
        continue;
      }

      // ========== GROUP/ORDER/HAVING ==========
      if ({'GROUP', 'ORDER', 'HAVING'}.contains(upper)) {
        _writeNewlineIndent(result, indentLevel);
        result.write('$token ');
        i++;
        continue;
      }

      // ========== Opening Parenthesis ==========
      if (token == '(') {
        // 检查是否是函数调用
        if (prevUpper != null && _functions.contains(prevUpper)) {
          funcDepth++;
          result.write('(');
          i++;
          continue;
        }

        // 检查是否是子查询
        if (nextUpper == 'SELECT') {
          result.write('(');
          indentLevel++;
          subqueryDepth++;
          i++;
          continue;
        }

        // 普通括号 - 追踪深度
        parenDepth++;
        result.write('(');
        i++;
        continue;
      }

      // ========== Closing Parenthesis ==========
      if (token == ')') {
        if (funcDepth > 0) {
          funcDepth--;
          result.write(')');
          i++;
          continue;
        }

        // 检查是否关闭子查询
        if (subqueryDepth > 0 &&
            nextUpper != null &&
            (nextUpper == 'AS' ||
                (!_keywords.contains(nextUpper) &&
                    !{'(', ')', ',', '.'}.contains(next)))) {
          subqueryDepth--;
          indentLevel--;
          if (indentLevel < 0) indentLevel = 0;
          result.write('\n');
          _writeIndent(result, indentLevel);
          result.write(')');
        } else {
          // 普通括号
          if (parenDepth > 0) parenDepth--;
          result.write(')');
        }
        i++;
        continue;
      }

      // ========== Comma ==========
      if (token == ',') {
        result.write(',');
        // SELECT 字段逗号后换行（不在函数内）
        if (inSelectColumns && funcDepth == 0) {
          result.write('\n');
          _writeIndent(result, indentLevel);
        }
        i++;
        continue;
      }

      // ========== AS ==========
      if (upper == 'AS') {
        result.write(' AS ');
        i++;
        continue;
      }

      // ========== Default ==========
      String resultStr = result.toString();
      bool needsSpace =
          resultStr.isNotEmpty &&
          !resultStr.endsWith(' ') &&
          !resultStr.endsWith('\n') &&
          !resultStr.endsWith('(') &&
          !resultStr.endsWith('\t') &&
          !resultStr.endsWith('.') &&
          token != ',' &&
          token != ')' &&
          token != '.' &&
          !token.startsWith('.');

      if (needsSpace) {
        result.write(' ');
      }

      // SELECT 后第一个字段需要缩进
      if (inSelectColumns && resultStr.endsWith('\n')) {
        _writeIndent(result, indentLevel);
      }

      result.write(token);
      i++;
    }

    return result.toString().trim();
  }

  void _writeIndent(StringBuffer sb, int level) {
    for (int i = 0; i < level; i++) {
      sb.write('\t');
    }
  }

  void _writeNewlineIndent(StringBuffer sb, int level) {
    String s = sb.toString();
    if (s.isNotEmpty && !s.endsWith('\n')) {
      sb.write('\n');
    }
    _writeIndent(sb, level);
  }

  List<String> _tokenize(String sql) {
    List<String> tokens = [];
    StringBuffer current = StringBuffer();
    bool inString = false;
    String? stringChar;
    bool inBacktick = false;

    for (int i = 0; i < sql.length; i++) {
      String char = sql[i];

      if ((char == "'" || char == '"') && !inBacktick) {
        if (!inString) {
          if (current.isNotEmpty) {
            tokens.add(current.toString());
            current.clear();
          }
          inString = true;
          stringChar = char;
          current.write(char);
        } else if (char == stringChar) {
          current.write(char);
          tokens.add(current.toString());
          current.clear();
          inString = false;
          stringChar = null;
        } else {
          current.write(char);
        }
        continue;
      }

      if (char == '`') {
        if (!inBacktick && !inString) {
          if (current.isNotEmpty) {
            tokens.add(current.toString());
            current.clear();
          }
          inBacktick = true;
          current.write(char);
        } else if (inBacktick) {
          current.write(char);
          tokens.add(current.toString());
          current.clear();
          inBacktick = false;
        }
        continue;
      }

      if (inString || inBacktick) {
        current.write(char);
        continue;
      }

      if ('(),.'.contains(char)) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
        tokens.add(char);
        continue;
      }

      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
        continue;
      }

      current.write(char);
    }

    if (current.isNotEmpty) {
      tokens.add(current.toString());
    }
    return tokens;
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _clear() {
    _controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _format,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text("格式化"),
              ),
              ElevatedButton.icon(
                onPressed: _compress,
                icon: const Icon(Icons.compress),
                label: const Text("压缩"),
              ),
              ElevatedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                label: const Text("复制"),
              ),
              ElevatedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                label: const Text("清空"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
                hintText: '在此输入 SQL 语句...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
