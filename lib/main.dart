import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => AppState(), child: const MyApp()));
}

class AppState with ChangeNotifier {
  int value = 0;
  Meter _meter = Meter.common;
  CountMethod _method = CountMethod.measure;

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

  void increment() {
    log('In increment: $value');
    value += 1;
    notifyListeners();
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
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(flex: 1),
            const Row(children: <Widget>[
              Spacer(flex: 20),
              MeterChooser(),
              Spacer(flex: 20),
              MethodChooser(),
              Spacer(flex: 20)
            ]),
            const Spacer(flex: 1),
            ElevatedButton(
              onPressed: () {
                var state = context.read<AppState>();
                log('Pressing embedded action');
                state.increment();
              },
              child: const Text('Click Here'),
            ),
            const Spacer(flex: 1),
            const Text(
              'You have pushed the button this many times:',
            ),
            Consumer<AppState>(
                builder: (context, state, child) => Text(
                      '${state.value} - ${state.meter} - ${state.method}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )),
            const Spacer(flex: 1),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          var state = context.read<AppState>();
          log('Pressing floating action');
          state.increment();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

enum Meter { beat, double, waltz, common }

class MeterChooser extends StatelessWidget {
  const MeterChooser({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
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
                  var state = context.read<AppState>();
                  state.meter = newSelection.first;
                }));
  }
}

enum CountMethod { beat, measure }

class MethodChooser extends StatelessWidget {
  const MethodChooser({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
        builder: (context, state, child) => SegmentedButton<CountMethod>(
                segments: const <ButtonSegment<CountMethod>>[
                  ButtonSegment<CountMethod>(
                      value: CountMethod.beat, label: Text('beat')),
                  ButtonSegment<CountMethod>(
                      value: CountMethod.measure, label: Text('measure')),
                ],
                selected: <CountMethod>{
                  state.method
                },
                onSelectionChanged: (Set<CountMethod> newSelection) {
                  var state = context.read<AppState>();
                  state.method = newSelection.first;
                }));
  }
}
