import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => Counter(), child: const MyApp()));
}

enum ClickState { initial, firstClick, counting, done }

class Counter with ChangeNotifier {
  static const int _maxWait = 5000;

  int _lastClick = 0;
  Meter _meter = Meter.common;
  CountMethod _method = CountMethod.measure;
  ClickState _clickState = ClickState.initial;
  final List<int> _intervals = [];
  Timer? _timeout;

  Meter get meter => _meter;
  set meter(Meter value) {
    _meter = value;
    notifyListeners();
  }

  CountMethod get method => _method;
  set method(CountMethod value) {
    _method = value;
    notifyListeners();
  }

  ClickState get clickState => _clickState;

  void click() {
    int now = DateTime.now().millisecondsSinceEpoch;
    _timeout?.cancel();

    switch (_clickState) {
      case ClickState.initial:
      case ClickState.done:
        _intervals.clear();
        _lastClick = now;
        _clickState = ClickState.counting;
      case ClickState.firstClick:
      case ClickState.counting:
        _clickState = ClickState.counting;
        int delta = now - _lastClick;
        _lastClick = now;
        _intervals.add(delta);
        if (_intervals.length > 10) {
          _intervals.removeAt(0);
        }
    }

    _timeout = Timer(const Duration(milliseconds: _maxWait), onTimeout);

    notifyListeners();
  }

  void onTimeout() {
    switch (_clickState) {
      case ClickState.initial:
      case ClickState.firstClick:
        _clickState = ClickState.initial;
        _intervals.clear();
        _lastClick = 0;
      case ClickState.counting:
      case ClickState.done:
        _clickState = ClickState.done;
    }
    notifyListeners();
  }

  // Clicks per minute
  double get _cpm {
    if (_intervals.isEmpty) {
      return 0;
    }
    var avg = _intervals.reduce((a, b) => a + b) / _intervals.length;
    return (60 * 1000) / avg;
  }

  double get bpm {
    switch (_method) {
      case CountMethod.beat:
        return _cpm;
      case CountMethod.measure:
        return _cpm * _meter.index;
    }
  }

  double get mpm {
    switch (_method) {
      case CountMethod.beat:
        return _cpm / _meter.index;
      case CountMethod.measure:
        return _cpm;
    }
  }

  String get clickLabel {
    switch (_clickState) {
      case ClickState.initial:
      case ClickState.done:
        switch (_method) {
          case CountMethod.beat:
            return 'Click on each beat';
          default:
            return 'Click on downbeat of ${_meter.index}/4 measure';
        }
      case ClickState.firstClick:
      case ClickState.counting:
        return 'Again';
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beat Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Consumer<Counter>(
          builder: (context, state, child) =>
              MyHomePage(title: 'Beat Counter', state: state)),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title, required this.state});
  final String title;
  final Counter state;

  @override
  Widget build(BuildContext context) {
    log('${state.method}');
    var mpm = state.method == CountMethod.measure
        ? <Widget>[
            Text("${state.mpm.toStringAsFixed(1)} mpm ${state.meter.index}/4"),
            const Spacer(flex: 1),
          ]
        : [];

    var elements = <Widget>[
      const SizedBox(height: 20),
      SizedBox(
          width: double.infinity,
          height: 60,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  state.click();
                },
                child: Text(state.clickLabel),
              ))),
      const Spacer(flex: 1),
      ...mpm,
      Text("${state.bpm.toStringAsFixed(1)} bpm"),
      const Spacer(flex: 2),
      const MeterChooser(),
      const SizedBox(height: 10),
      const MethodChooser(),
      const Spacer(flex: 1),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(title)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: elements,
        ),
      ),
    );
  }
}

enum Meter { none, beat, double, waltz, common }

class MeterChooser extends StatelessWidget {
  const MeterChooser({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Counter>(
        builder: (context, state, child) => SegmentedButton<Meter>(
                segments: const <ButtonSegment<Meter>>[
                  ButtonSegment<Meter>(value: Meter.double, label: Text('2/4')),
                  ButtonSegment<Meter>(value: Meter.waltz, label: Text('3/4')),
                  ButtonSegment<Meter>(value: Meter.common, label: Text('4/4')),
                ],
                selected: <Meter>{
                  state.meter
                },
                onSelectionChanged: (Set<Meter> newSelection) {
                  var state = context.read<Counter>();
                  state.meter = newSelection.first;
                }));
  }
}

enum CountMethod { beat, measure }

class MethodChooser extends StatelessWidget {
  const MethodChooser({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Counter>(
        builder: (context, state, child) => SegmentedButton<CountMethod>(
                segments: const <ButtonSegment<CountMethod>>[
                  ButtonSegment<CountMethod>(
                      value: CountMethod.beat, label: Text('Count Beats')),
                  ButtonSegment<CountMethod>(
                      value: CountMethod.measure,
                      label: Text('Count Measures')),
                ],
                selected: <CountMethod>{
                  state.method
                },
                onSelectionChanged: (Set<CountMethod> newSelection) {
                  var state = context.read<Counter>();
                  state.method = newSelection.first;
                }));
  }
}
