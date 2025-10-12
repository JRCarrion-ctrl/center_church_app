import 'package:flutter/widgets.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class GraphProvider extends StatelessWidget {
  final ValueNotifier<GraphQLClient> client;
  final Widget child;

  const GraphProvider({
    super.key,
    required this.client,
    required this.child,
  });

  // Get the actual client, not the notifier
  static GraphQLClient of(BuildContext context) =>
      GraphQLProvider.of(context).value;

  // (Optional) If you ever need the notifier itself
  static ValueNotifier<GraphQLClient> ofNotifier(BuildContext context) =>
      GraphQLProvider.of(context);

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: client,
      child: CacheProvider(        // <-- not const
        child: child,              // <-- pass your real child here
      ),
    );
  }
}
