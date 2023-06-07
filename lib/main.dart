import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => Counter(), child: const MyApp()));
}

enum ClickState { initial, firstClick, counting, done }

/* I'm managing state and handling "business logic" such as it is in a single class - this won't scale beyond
 a fairly simple application, but seems like a reasonably clean solution for this very small application 

  I'm making heavy use of custom setters and getters to supply a public interface on top of private state.

  The public interface is as follows:

  The internal state for the application is as follows
    - User setabble options
      - _method - Does the user want to count by beats of by measures
      - _meter - beat (no meter), 2/4 (double), 3/4 (waltz) or 4/4 (common)
    - Internal state 
      -  _clickState - This is a simple state machine to track whether the user has started counting, etc.
          this is used to manage the rest of the internal state and helps when compute the title of the click button 
      -  observe this state to render 
      - _lastClick - Timestamp of the last click
      - _intervals - the last 10 intervals between click s in ticks (which may be rescaled based on meter/method)
      - _cpm - counts per minute computed from _intervals
 */
class Counter with ChangeNotifier {
  static const int _maxWait = 5000;

  Meter _meter = Meter.common;
  CountMethod _method = CountMethod.measure;

  ClickState _clickState = ClickState.initial;
  int _lastClick = 0;
  final List<int> _intervals = [];
  Timer? _timeout;

  Meter get meter => _meter;
  set meter(Meter value) {
    if (_method == CountMethod.measure) {
      _convertIntervals(_meter, value);
    }

    _meter = value;
    notifyListeners();
  }

  CountMethod get method {
    return _meter == Meter.beat ? CountMethod.beat : _method;
  }

  set method(CountMethod value) {
    switch (value) {
      case CountMethod.beat:
        _convertIntervals(_meter, Meter.beat);
      case CountMethod.measure:
        _convertIntervals(Meter.beat, _meter);
    }
    _method = value;
    notifyListeners();
  }

  // Convert intervals to the new meter, keeping bmp constant
  void _convertIntervals(Meter oldMeter, Meter newMeter) {
    for (var i = 0; i < _intervals.length; i++) {
      var beat = _intervals[i] ~/ oldMeter.index;
      _intervals[i] = beat * newMeter.index;
    }
  }

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

    _timeout = Timer(const Duration(milliseconds: _maxWait), _onTimeout);

    notifyListeners();
  }

  void _onTimeout() {
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

  // Clicks per minute - computed from the last ten intevals between clicks
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
        switch (method) {
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

/// The main (and currently only) page is a simple column layout - this started a simple
///   column layout, but in order to have the fallback of going scrollable when the vertical
///   dimension is too small (e.g. landscape or extra-small device) I moved to a LayoutBuilder
///   containing a SingleChildScrollView - this method is well documented in the Widget's page
///   https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html
///
///   Note the use of Collection conditionals to hide the MPM card when the user has
///   selected "beat mode."
///
///   I'm passing my application state into the wizrd.  General guidance is to grab state at the
///   lowest point in the tree possible to prevent the system from building too much of the tree.
///   Since I am hiding an element of the column, this full widget needs to know the state.
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title, required this.state});
  final String title;
  final Counter state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(title)),
      ),
      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: viewportConstraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    CounterButton(state: state),
                    const SizedBox(height: 20),
                    if (state.meter != Meter.beat)
                      TempoCard(
                          text:
                              "${state.mpm.toStringAsFixed(1)} mpm ${state.meter.index}/4"),
                    if (state.meter != Meter.beat) const SizedBox(height: 10),
                    TempoCard(text: "${state.bpm.toStringAsFixed(1)} bpm"),
                    const Spacer(flex: 2),
                    const MeterChooser(),
                    const SizedBox(height: 10),
                    if (state.meter != Meter.beat) const MethodChooser(),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A smart button that uses state to track its clicks and define its label
class CounterButton extends StatelessWidget {
  const CounterButton({
    super.key,
    required this.state,
  });

  final Counter state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.textTheme.headlineLarge!.copyWith(fontWeight: FontWeight.bold);

    return SizedBox(
        width: double.infinity,
        height: 160,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                state.click();
              },
              child: Text(state.clickLabel,
                  textAlign: TextAlign.center, style: style),
            )));
  }
}

/// A generic tempo card that takes a string to display on a card.  This provides
///  the styling for those cards
class TempoCard extends StatelessWidget {
  const TempoCard({
    super.key,
    required this.text,
  });

  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineLarge!.copyWith(
        color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold);

    return SizedBox(
      width: double.infinity,
      child: Card(
        color: theme.colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}

/// Defines the possible meters - this was a bit of a stretch, since I was looking for
/// single word synonyms for 2/4, 3/4 and 4/4.  "none" is included to make the rest of the
/// values indices line up with their beats per measure.  "beat" isn't really a meter, but
/// an indiciation that the user just wants to count beats and not worry about meter
enum Meter { none, beat, double, waltz, common }

/// A simple segmented button (semantically a radio group) to choose the meter.  I originally
/// implemented this as a StatefulWidget, but found it cleaner for this small application
/// to manage application state centrally - so clicking on these buttons calls a method
/// on the state and then through the magic of reactivity, the control reflects the change
/// in the application state that results
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

/// Simple enum to define whether the user wants to click once per beat or once per measure
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
