import 'package:flutter/material.dart';
void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculadora Flutter',
      // Diseño 
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[900],
        scaffoldBackgroundColor: Colors.black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BasicCalculator(),
    );
  }
}

// StatefulWidget
class BasicCalculator extends StatefulWidget {
  const BasicCalculator({super.key});

  @override
  State<BasicCalculator> createState() => _BasicCalculatorState();
}

class _BasicCalculatorState extends State<BasicCalculator> {
  // --- Variables de Estado ---
  String _expression = ''; 
  String _result = '0'; 
  double _firstOperand = 0.0;
  String _operator = '';
  bool _waitingForSecondOperand = false;
  bool _errorState = false; 

  // --- vainas de Diseño ---
  final Color _numberColor = Colors.grey[850]!;
  final Color _functionColor = Colors.grey[700]!;
  final Color _operatorColor = Colors.orange[700]!;

  final List<String> _buttons = [
    'C', '+/-', '%', '÷', 
    '7', '8', '9', 'x', 
    '4', '5', '6', '-', 
    '1', '2', '3', '+', 
    'DEL', '0', '.', '=',
  ];

  // --- logica ---

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (_errorState && buttonText != 'C') {
        return;
      }

      switch (buttonText) {
        case 'C':
          _clearAll();
          break;
        case 'DEL':
          _deleteLast();
          break;
        case '+/-':
          _toggleSign();
          break;
        case '%':
          _calculatePercentage();
          break;
        case '.':
          _appendDecimal();
          break;
        case '÷':
        case 'x':
        case '-':
        case '+':
          _handleOperator(buttonText);
          break;
        case '=':
          _calculateResult();
          break;
        default:
          _appendDigit(buttonText);
      }
    });
  }

  void _clearAll() {
    _expression = '';
    _result = '0';
    _firstOperand = 0.0;
    _operator = '';
    _waitingForSecondOperand = false;
    _errorState = false;
  }

  void _deleteLast() {
    if (_waitingForSecondOperand) return;
    if (_result.length > 1) {
      _result = _result.substring(0, _result.length - 1);
      if (_result == '-') _result = '0';
    } else {
      _result = '0';
    }
  }
  
  void _toggleSign() {
    if (_result != '0' && _result != 'Error') {
      _result = _result.startsWith('-') ? _result.substring(1) : '-$_result';
    }
  }

  void _calculatePercentage() {
    try {
      double currentValue = double.parse(_result);
      _result = _formatNumber(currentValue / 100);
    } catch (e) {
      _showError();
    }
  }

  void _appendDecimal() {
    if (_waitingForSecondOperand) {
      _result = '0.';
      _waitingForSecondOperand = false;
      return;
    }
    if (!_result.contains('.')) {
      _result += '.';
    }
  }

  void _appendDigit(String digit) {
    if (_waitingForSecondOperand) {
      _result = digit;
      _waitingForSecondOperand = false;
    } else {
      if (_result == '0' && digit == '0') return;
      _result = _result == '0' ? digit : _result + digit;
    }
  }

  void _handleOperator(String op) {
    try {
      double currentValue = double.parse(_result);

      if (_operator.isNotEmpty && !_waitingForSecondOperand) {
        _calculateResult(isChained: true);
        currentValue = double.parse(_result);
      }

      _firstOperand = currentValue;
      _operator = op;
      _waitingForSecondOperand = true;
      _expression = '${_formatNumber(_firstOperand)} $_operator';
    } catch (e) {
      _showError();
    }
  }

  void _calculateResult({bool isChained = false}) {
    if (_operator.isEmpty || _waitingForSecondOperand) return;

    try {
      double secondOperand = double.parse(_result);
      double calculationResult = 0.0;
      String currentExpression =
          '${_formatNumber(_firstOperand)} $_operator ${_formatNumber(secondOperand)}';

      switch (_operator) {
        case '+': calculationResult = _firstOperand + secondOperand; break;
        case '-': calculationResult = _firstOperand - secondOperand; break;
        case 'x': calculationResult = _firstOperand * secondOperand; break;
        case '÷':
          if (secondOperand == 0) {
            _showError();
            return;
          }
          calculationResult = _firstOperand / secondOperand;
          break;
      }

      _result = _formatNumber(calculationResult);
      _firstOperand = calculationResult; 

      if (!isChained) {
        _expression = '$currentExpression =';
        _operator = ''; 
        _waitingForSecondOperand = false; 
      } else {
        _expression = '${_formatNumber(_firstOperand)} $_operator';
      }
    } catch (e) {
      _showError();
    }
  }

  void _showError() {
    _result = 'Error';
    _expression = '';
    _errorState = true;
  }

  String _formatNumber(double num) {
    if (num.isNaN || num.isInfinite) {
      _errorState = true;
      return 'Error';
    }
    if (num % 1 == 0) {
      return num.toInt().toString();
    }
    return num.toString();
  }

  Color _getButtonColor(String buttonText) {
    if (['÷', 'x', '-', '+', '='].contains(buttonText)) {
      return _operatorColor;
    }
    if (['C', 'DEL', '+/-', '%'].contains(buttonText)) {
      return _functionColor;
    }
    return _numberColor;
  }

  // --- hago UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildDisplay(),
            const Divider(height: 1, color: Colors.white10),
            _buildKeyboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _expression,
                style: const TextStyle(fontSize: 24, color: Colors.white54),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _result,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, 
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _buttons.length,
          itemBuilder: (context, index) {
            final buttonText = _buttons[index];
            return _buildButton(buttonText);
          },
        ),
      ),
    );
  }

  //prtivate button builder

  Widget _buildButton(String buttonText) {
    return Material(
      color: _getButtonColor(buttonText),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onButtonPressed(buttonText),
        child: Center(
          child: Text(
            buttonText,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

