import 'package:flutter/material.dart';

import '../models/calculator_history_model.dart';
import '../services/calculator_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalculatorService _calculatorService = CalculatorService();
  final List<CalculatorHistoryModel> _history = [];
  String _expression = '';
  String _result = '0';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    _history
      ..clear()
      ..addAll(await _calculatorService.getHistory());
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _append(String value) {
    setState(() {
      if (_expression == '0' && value != '.') {
        _expression = value;
      } else {
        _expression += value;
      }
    });
  }

  Future<void> _calculate() async {
    final expression = _expression.trim();
    if (expression.isEmpty) return;

    try {
      final value = _evaluate(expression);
      setState(() => _result = value.toStringAsFixed(2));
      await _calculatorService.saveCalculation(
        CalculatorHistoryModel(
          expression: expression,
          result: _result,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await _loadHistory();
    } catch (_) {
      setState(() => _result = 'Error');
    }
  }

  double _evaluate(String expression) {
    final tokens = _tokenize(expression.replaceAll(' ', ''));
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn);
  }

  List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if ('0123456789.'.contains(ch)) {
        buffer.write(ch);
      } else {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(ch);
      }
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  int _precedence(String op) {
    switch (op) {
      case '+':
      case '-':
        return 1;
      case '×':
      case '*':
      case '÷':
      case '/':
        return 2;
      default:
        return 0;
    }
  }

  List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final operators = <String>[];

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isNotEmpty) operators.removeLast();
      } else {
        while (operators.isNotEmpty && _precedence(operators.last) >= _precedence(token)) {
          output.add(operators.removeLast());
        }
        operators.add(token);
      }
    }

    while (operators.isNotEmpty) {
      output.add(operators.removeLast());
    }

    return output;
  }

  double _evalRpn(List<String> rpn) {
    final stack = <double>[];
    for (final token in rpn) {
      final value = double.tryParse(token);
      if (value != null) {
        stack.add(value);
      } else {
        final right = stack.removeLast();
        final left = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(left + right);
            break;
          case '-':
            stack.add(left - right);
            break;
          case '*':
          case '×':
            stack.add(left * right);
            break;
          case '/':
          case '÷':
            stack.add(left / right);
            break;
        }
      }
    }
    return stack.isEmpty ? 0 : stack.last;
  }

  void _clear() {
    setState(() {
      _expression = '';
      _result = '0';
    });
  }

  Widget _button(String label, {Color? color, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: onTap ?? () {
              if (label == '=') {
                _calculate();
              } else if (label == 'C') {
                _clear();
              } else if (label == '⌫') {
                setState(() {
                  if (_expression.isNotEmpty) {
                    _expression = _expression.substring(0, _expression.length - 1);
                  }
                });
              } else {
                _append(label);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? Colors.white,
              foregroundColor: color == null ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Calculator')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _expression.isEmpty ? '0' : _expression,
                        style: const TextStyle(color: Colors.white70, fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(children: [_button('C', color: Colors.red), _button('⌫', color: Colors.orange), _button('(', color: Colors.blueGrey), _button(')', color: Colors.blueGrey)]),
                      Row(children: [_button('7'), _button('8'), _button('9'), _button('÷', color: Colors.blue)]),
                      Row(children: [_button('4'), _button('5'), _button('6'), _button('×', color: Colors.blue)]),
                      Row(children: [_button('1'), _button('2'), _button('3'), _button('-', color: Colors.blue)]),
                      Row(children: [_button('0'), _button('.'), _button('=', color: Colors.green), _button('+', color: Colors.blue)]),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () async {
                              await _calculatorService.clearHistory();
                              await _loadHistory();
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      ..._history.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.expression),
                          subtitle: Text(item.createdAt),
                          trailing: Text('= ${item.result}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}