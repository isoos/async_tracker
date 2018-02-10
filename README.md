# async_tracker

Tracks async callbacks (e.g. microtask, `Future`, `Stream`, `Timer`) and
indicates when any of these has completed their executions.
It can be used to track and react on async event chains.

Clients of the `AsyncTracker` either listen on the `stream` or they can
add or remove listeners that receive these events.

## Usage

A simple usage example:

import 'package:async_tracker/async_tracker.dart';

````dart
main() {
  final tracker = new AsyncTracker();
  tracker.addListener(() {
    print('tracker has detected an execution');
  });

  tracker.run(() {
    // do any async stuff
  });
}
````
