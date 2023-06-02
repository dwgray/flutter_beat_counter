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
    log('Entering Timeout: $_clickState');
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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Beat Counter'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Center(child: Text(title)),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(flex: 2),
            ElevatedButton(
              onPressed: () {
                var state = context.read<Counter>();
                state.click();
              },
              child: Consumer<Counter>(
                  builder: (context, state, child) => Text(state.clickLabel)),
            ),
            const Spacer(flex: 1),
            Consumer<Counter>(
                builder: (context, state, child) => Text(
                    "${state.mpm.toStringAsFixed(1)} mpm ${state.meter.index}/4")),
            const Spacer(flex: 1),
            Consumer<Counter>(
                builder: (context, state, child) =>
                    Text("${state.bpm.toStringAsFixed(1)} bpm")),
            const Spacer(flex: 2),
            const MeterChooser(),
            const Spacer(flex: 1),
            const MethodChooser(),
            const Spacer(flex: 1),
          ],
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
                  ButtonSegment<Meter>(value: Meter.beat, label: Text('beat')),
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
