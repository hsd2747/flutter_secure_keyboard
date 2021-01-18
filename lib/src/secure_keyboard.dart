import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_keyboard/src/secure_keyboard_key_action.dart';
import 'package:flutter_secure_keyboard/src/secure_keyboard_key_generator.dart';
import 'package:flutter_secure_keyboard/src/secure_keyboard_key_type.dart';
import 'package:flutter_secure_keyboard/src/secure_keyboard_type.dart';
import 'package:flutter_secure_keyboard/src/secure_keyboard_key.dart';

/// Height of widget showing input text.
const double keyInputMonitorHeight = 50.0;

/// Keyboard default height.
const double keyboardDefaultHeight = 280.0;

/// Speed ​​of erasing input text when holding backspace.
const int backspaceEventDelay = 100;

/// Widget that implements a secure keyboard.
class SecureKeyboard extends StatefulWidget {
  /// Specifies the secure keyboard type.
  final SecureKeyboardType type;

  /// Called when the key is pressed.
  final ValueChanged<SecureKeyboardKey> onKeyPressed;

  /// Called when the character codes changed.
  final ValueChanged<List<int>> onCharCodesChanged;

  /// Called when the confirm key is pressed.
  final ValueChanged<List<int>> onConfirmKeyPressed;

  /// Called when the close key is pressed.
  final VoidCallback onCloseKeyPressed;

  /// Set the initial value of the input text.
  final String initText;

  /// The hint text to display when the input text is empty.
  final String hintText;

  /// Set the symbol to use when displaying the input text length.
  final String inputTextLengthSymbol;

  /// Set the confirm key text.
  final String confirmKeyText;

  /// Set the clear key text.
  final String clearKeyText;

  /// Set the secure character to hide the input text.
  final String obscuringCharacter;

  /// Set the maximum length of text that can be entered.
  final int maxLength;

  /// Whether to always display uppercase characters.
  final bool alwaysCaps;

  /// Whether to hide input text as secure characters.
  final bool obscureText;

  /// Parameter to set the keyboard height.
  final double height;

  /// Parameter to set the keyboard background color.
  final Color backgroundColor;

  /// Parameter to set keyboard string key(alphanumeric, numeric..) color.
  final Color stringKeyColor;

  /// Parameter to set keyboard action key(shift, backspace, clear..) color.
  final Color actionKeyColor;

  /// Parameter to set keyboard confirm key color.
  final Color confirmKeyColor;

  /// Parameter to set keyboard key text style.
  final TextStyle keyTextStyle;

  /// Parameter to set keyboard input text style.
  final TextStyle inputTextStyle;

  /// Security Alert title, only works on ios.
  final String screenCaptureDetectedAlertTitle;

  /// Security Alert message, only works on ios.
  final String screenCaptureDetectedAlertMessage;

  /// Security Alert actionTitle, only works on ios.
  final String screenCaptureDetectedAlertActionTitle;

  SecureKeyboard({
    Key key,
    @required this.type,
    @required this.onKeyPressed,
    @required this.onCharCodesChanged,
    @required this.onConfirmKeyPressed,
    @required this.onCloseKeyPressed,
    this.initText = '',
    this.hintText = '',
    this.inputTextLengthSymbol,
    this.confirmKeyText,
    this.clearKeyText,
    this.obscuringCharacter = '•',
    this.maxLength,
    this.alwaysCaps = false,
    this.obscureText = true,
    this.height = keyboardDefaultHeight,
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.stringKeyColor = const Color(0xFF313131),
    this.actionKeyColor = const Color(0xFF222222),
    this.confirmKeyColor = const Color(0xFF1C7CDC),
    this.keyTextStyle = const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
    this.inputTextStyle = const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
    this.screenCaptureDetectedAlertTitle,
    this.screenCaptureDetectedAlertMessage,
    this.screenCaptureDetectedAlertActionTitle
  })  : assert(type != null),
        assert(onKeyPressed != null),
        assert(onCharCodesChanged != null),
        assert(onConfirmKeyPressed != null),
        assert(onCloseKeyPressed != null),
        assert(initText != null),
        assert(hintText != null),
        assert(obscuringCharacter != null && obscuringCharacter.isNotEmpty),
        assert(alwaysCaps != null),
        assert(obscureText != null),
        assert(height != null),
        assert(backgroundColor != null),
        assert(stringKeyColor != null),
        assert(actionKeyColor != null),
        assert(confirmKeyColor != null),
        assert(keyTextStyle != null),
        assert(inputTextStyle != null),
        super(key: key);

  @override
  _SecureKeyboardState createState() => _SecureKeyboardState();
}

class _SecureKeyboardState extends State<SecureKeyboard> {
  final _methodChannel = const MethodChannel('flutter_secure_keyboard');

  final _definedKeyRows = List<List<SecureKeyboardKey>>();
  final _specialKeyRows = List<List<SecureKeyboardKey>>();
  final _charCodes = List<int>();
  
  Timer _backspaceEventGenerator;

  bool _isViewEnabled = false;
  bool _isShiftEnabled = false;
  bool _isSpecialCharsEnabled = false;
  
  void _initVariables() {
    _isViewEnabled = false;
    _isShiftEnabled = false;
    _isSpecialCharsEnabled = false;

    _definedKeyRows.clear();
    _specialKeyRows.clear();
    _charCodes.clear();
    _charCodes.addAll(widget.initText.codeUnits);

    if (widget.type == SecureKeyboardType.Numeric)
      _definedKeyRows.addAll(SecureKeyboardKeyGenerator.instance.getNumericKeyRows());
    else
      _definedKeyRows.addAll(SecureKeyboardKeyGenerator.instance.getAlphanumericKeyRows());

    _specialKeyRows.addAll(SecureKeyboardKeyGenerator.instance.getSpecialCharsKeyRows());
  }

  void _onKeyPressed(SecureKeyboardKey key) {
    if (key.type == SecureKeyboardKeyType.String) {
      // The length of `charCodes` cannot exceed `maxLength`.
      if (widget.maxLength != null && widget.maxLength <= _charCodes.length)
        return;

      final keyText = (_isShiftEnabled || widget.alwaysCaps)
          ? key.capsText
          : key.text;
      setState(() => _charCodes.add(keyText.codeUnits.first));
      widget.onCharCodesChanged(_charCodes);
    } else if (key.type == SecureKeyboardKeyType.Action) {
      switch (key.action) {
        // Backspace
        case SecureKeyboardKeyAction.Backspace:
          if (_charCodes.isNotEmpty) {
            setState(() => _charCodes.removeLast());
            widget.onCharCodesChanged(_charCodes);
          }
          break;
          
        // Confirm
        case SecureKeyboardKeyAction.Confirm:
          widget.onConfirmKeyPressed(_charCodes);
          break;
          
        // Clear
        case SecureKeyboardKeyAction.Clear:
          setState(() => _charCodes.clear());
          widget.onCharCodesChanged(_charCodes);
          break;
          
        // Shift
        case SecureKeyboardKeyAction.Shift:
          if (!widget.alwaysCaps)
            setState(() {
              _isShiftEnabled = !_isShiftEnabled;
            });
          break;
          
        // SpecialChars
        case SecureKeyboardKeyAction.SpecialChars:
          setState(() {
            _isSpecialCharsEnabled = !_isSpecialCharsEnabled;
          });
          break;

        default:
          return;
      }
    }

    widget.onKeyPressed(key);
  }

  @override
  void didUpdateWidget(covariant SecureKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initVariables();
  }

  @override
  void initState() {
    super.initState();
    _methodChannel.invokeMethod('secureModeOn', {
      'screenCaptureDetectedAlertTitle': widget.screenCaptureDetectedAlertTitle,
      'screenCaptureDetectedAlertMessage': widget.screenCaptureDetectedAlertMessage,
      'screenCaptureDetectedAlertActionTitle': widget.screenCaptureDetectedAlertActionTitle
    });
    _initVariables();
  }

  @override
  Widget build(BuildContext context) {
    final keyRows = _isSpecialCharsEnabled
        ? _specialKeyRows
        : _definedKeyRows;
    final keyboardKey = _buildKeyboardKey(keyRows);
    keyboardKey.insert(0, _buildKeyInputMonitor());

    return Container(
      width: MediaQuery.of(context).size.width,
      height: widget.height + keyInputMonitorHeight,
      color: widget.backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: keyboardKey
      ),
    );
  }

  @override
  void dispose() {
    _methodChannel.invokeMethod('secureModeOff');
    super.dispose();
  }

  Widget _buildKeyInputMonitor() {
    String secureText;
    TextStyle secureTextStyle;

    if (_charCodes.isNotEmpty) {
      if (widget.obscureText && !_isViewEnabled) {
        secureText = '';
        for (var i=0; i<_charCodes.length; i++) {
          if (i == _charCodes.length - 1)
            secureText += String.fromCharCode(_charCodes[i]);
          else
            secureText += widget.obscuringCharacter;
        }
      } else {
        secureText = String.fromCharCodes(_charCodes);
      }

      secureTextStyle = widget.inputTextStyle;
    } else {
      secureText = widget.hintText;
      secureTextStyle = widget.inputTextStyle.copyWith(
          color: widget.inputTextStyle.color.withOpacity(0.5));
    }

    final lengthSymbol = widget.inputTextLengthSymbol ?? (Platform.localeName == 'ko_KR')
        ? '자'
        : 'digit';
    final lengthText = '${_charCodes.length}$lengthSymbol';

    Widget viewKey = SizedBox();
    if (widget.obscureText) {
      viewKey = Container(
        width: keyInputMonitorHeight / 1.4,
        height: keyInputMonitorHeight / 1.4,
        margin: const EdgeInsets.only(left: 1.5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24.0),
            onTap: () {

            },
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isViewEnabled = true),
              onTapUp: (_) => setState(() => _isViewEnabled = false),
              onPanEnd: (_) => setState(() => _isViewEnabled = false),
              child: Icon(Icons.remove_red_eye, color: widget.keyTextStyle.color)
            )
          ),
        ),
      );
    }

    return SizedBox(
      height: keyInputMonitorHeight,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                secureText,
                style: secureTextStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis
              )
            )
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Text(lengthText, style: widget.keyTextStyle)
          ),
          viewKey,
          Container(
            width: keyInputMonitorHeight / 1.4,
            height: keyInputMonitorHeight / 1.4,
            margin: const EdgeInsets.only(right: 1.5),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24.0),
                onTap: widget.onCloseKeyPressed,
                child: Icon(Icons.close, color: widget.keyTextStyle.color)
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildKeyboardKey(List<List<SecureKeyboardKey>> keyRows) {
    return List.generate(keyRows.length, (int rowNum) {
      return Material(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(keyRows[rowNum].length, (int keyNum) {
            final key = keyRows[rowNum][keyNum];
            
            switch (key.type) {
              case SecureKeyboardKeyType.String:
                return _buildStringKey(key, keyRows.length);
              case SecureKeyboardKeyType.Action:
                return _buildActionKey(key, keyRows.length);
              default:
                throw Exception('Unknown key type.');
            }
          })
        ),
      );
    });
  }
  
  Widget _buildStringKey(SecureKeyboardKey key, int keyRowsLength) {
    final keyText = (_isShiftEnabled || widget.alwaysCaps)
        ? key.capsText
        : key.text;

    return Expanded(
      child: Container(
        height: widget.height / keyRowsLength,
        padding: const EdgeInsets.all(1.5),
        child: Material(
          borderRadius: BorderRadius.circular(4.0),
          color: widget.stringKeyColor,
          child: InkWell(
            onTap: () => _onKeyPressed(key),
            child: Center(child: Text(keyText, style: widget.keyTextStyle))
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(SecureKeyboardKey key, int keyRowsLength) {
    Widget actionKey;

    switch (key.action) {
      case SecureKeyboardKeyAction.Backspace:
        actionKey = GestureDetector(
          onLongPress: () {
            final delay = Duration(milliseconds: backspaceEventDelay);
            _backspaceEventGenerator = Timer.periodic(delay, (_) => _onKeyPressed(key));
          },
          onLongPressUp: () {
            if (_backspaceEventGenerator != null) {
              _backspaceEventGenerator.cancel();
              _backspaceEventGenerator = null;
            }
          },
          child: Icon(Icons.backspace, color: widget.keyTextStyle.color)
        );
        break;
      case SecureKeyboardKeyAction.Shift:
        actionKey = Icon(Icons.arrow_upward, color: widget.keyTextStyle.color);
        break;
      case SecureKeyboardKeyAction.Clear:
        actionKey = Text(
          widget.clearKeyText ?? (Platform.localeName == 'ko_KR')
              ? '초기화'
              : 'Clear',
          style: widget.keyTextStyle
        );
        break;
      case SecureKeyboardKeyAction.Confirm:
        actionKey = Text(
          widget.confirmKeyText ?? (Platform.localeName == 'ko_KR')
              ? '입력완료'
              : 'Confirm',
          style: widget.keyTextStyle
        );
        break;
      case SecureKeyboardKeyAction.SpecialChars:
        actionKey = Text(
          _isSpecialCharsEnabled
              ? (_isShiftEnabled ? 'ABC' : 'abc')
              : '!@#',
          style: widget.keyTextStyle
        );
        break;
      case SecureKeyboardKeyAction.Blank:
        return Expanded(child: SizedBox());
    }

    return Expanded(
      child: Container(
        height: widget.height / keyRowsLength,
        padding: const EdgeInsets.all(1.5),
        child: Material(
          borderRadius: BorderRadius.circular(4.0),
          color: (key.action == SecureKeyboardKeyAction.Confirm)
              ? widget.confirmKeyColor
              : widget.actionKeyColor,
          child: InkWell(
            onTap: () => _onKeyPressed(key),
            child: Center(child: actionKey)
          ),
        ),
      ),
    );
  }
}