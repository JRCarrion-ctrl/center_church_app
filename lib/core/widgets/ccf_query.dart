import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class CCFQuery extends StatelessWidget {
  final QueryOptions options;
  // Notice this builder only returns when we have actual data!
  final Widget Function(Map<String, dynamic> data, VoidCallback refetch) onData;

  const CCFQuery({
    super.key,
    required this.options,
    required this.onData,
  });

  @override
  Widget build(BuildContext context) {
    return Query(
      options: options,
      builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
        
        // 1. GLOBAL LOADING STATE
        if (result.isLoading && result.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. GLOBAL ERROR STATE
        if (result.hasException) {
          // Log it to your console silently
          debugPrint('GraphQL Error [${options.document}]: ${result.exception.toString()}');

          bool isNetworkError = result.exception!.linkException != null;
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline, 
                    size: 48, 
                    color: Colors.grey.shade400
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isNetworkError 
                        ? "Cannot connect to the server. Please check your internet connection."
                        : "Something went wrong. Please try again.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (refetch != null)
                    FilledButton.tonal(
                      onPressed: refetch, 
                      child: const Text("Retry")
                    )
                ],
              ),
            ),
          );
        }

        // 3. SUCCESS STATE
        // If we get here, we guarantee we have data and no errors.
        return onData(result.data ?? {}, refetch ?? () {});
      },
    );
  }
}