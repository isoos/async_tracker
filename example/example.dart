import 'package:async_tracker/async_tracker.dart';

main() {
  final tracker = new AsyncTracker();
  tracker.addListener(() {
    print('tracker has detected an execution');
  });

  tracker.run(() {
    // do any async stuff
  });
}
