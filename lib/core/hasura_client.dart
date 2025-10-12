// lib/core/hasura_client.dart
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:graphql_flutter/graphql_flutter.dart';
import '../features/auth/oidc_auth.dart';

const String kHasuraHttpUrl = 'https://api.ccfapp.com/v1/graphql';
const String kHasuraWsUrl   = 'wss://api.ccfapp.com/v1/graphql';

void debugPrintJwt(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    dev.log(payload, name: 'JWT payload');
  } catch (_) {}
}

/// ---------- Logging & Request-ID links (v5-compatible) ----------------------

String _newRid() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final r = (math.Random().nextInt(1 << 32)).toRadixString(16);
  return '$t-$r';
}

/// Adds X-Request-ID and logs request/response.
/// Uses Request.updateContextEntry<> instead of withContext (v5).
class RequestIdLink extends Link {
  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final rid = _newRid();

    final updated = request.updateContextEntry<HttpLinkHeaders>((prev) {
      final prevHeaders = prev?.headers ?? const <String, String>{};
      return HttpLinkHeaders(headers: {...prevHeaders, 'X-Request-ID': rid});
    });

    final name = request.operation.operationName ?? '<unnamed>';
    dev.log('→ $name rid=$rid vars=${_shortVars(request.variables)}', name: 'GQL');

    return forward!(updated).map((resp) {
      final hasErrs = resp.errors?.isNotEmpty == true;
      if (hasErrs) {
        dev.log('← $name rid=$rid errors=${_fmtErrors(resp.errors)}', name: 'GQL', level: 1000);
      } else {
        dev.log('← $name rid=$rid ok', name: 'GQL');
      }
      return resp;
    });
  }

  static String _shortVars(Map<String, dynamic> v) {
    final map = <String, dynamic>{};
    v.forEach((k, val) {
      final s = '$val';
      map[k] = s.length > 200 ? '${s.substring(0, 200)}…' : s;
    });
    return map.toString();
  }

  static String _fmtErrors(List<GraphQLError>? errs) {
    if (errs == null || errs.isEmpty) return '[]';
    return errs
        .map((e) => {
              'message': e.message,
              'path': e.path?.join('.'),
              'code': e.extensions?['code'],
              'details': e.extensions?['internal'] ?? e.extensions?['error']
            })
        .toList()
        .toString();
  }
}

/// ErrorLink API for v5: keep these callbacks.
final ErrorLink _errorLink = ErrorLink(
  onException: (request, forward, exception) {
    dev.log('! LinkException: $exception', name: 'GQL', level: 1000);
    return forward(request);
  },
  onGraphQLError: (request, forward, response) {
    dev.log('! GraphQLErrors: ${RequestIdLink._fmtErrors(response.errors)}', name: 'GQL', level: 1000);
    return forward(request);
  },
);

Link _baseLink() => Link.from([
      RequestIdLink(),
      _errorLink,
      DedupeLink(),
    ]);

GraphQLClient _clientFrom(Link transport) => GraphQLClient(
      link: transport,
      cache: GraphQLCache(store: InMemoryStore()),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.noCache, error: ErrorPolicy.all),
        mutate: Policies(fetch: FetchPolicy.noCache, error: ErrorPolicy.all),
        subscribe: Policies(fetch: FetchPolicy.noCache, error: ErrorPolicy.all),
      ),
    );

/// ---------- Clients ---------------------------------------------------------

Future<GraphQLClient> makeHasuraClient() async {
  await OidcAuth.refreshIfNeeded();
  final accessToken = await OidcAuth.readAccessToken();

  if (accessToken == null || accessToken.isEmpty) {
    return buildPublicHasuraClient();
  }

  // Optional: verify claims visually
  debugPrintJwt(accessToken);

  final authLink = AuthLink(
    getToken: () async {
      await OidcAuth.refreshIfNeeded();
      final t = await OidcAuth.readAccessToken();
      return t == null ? null : 'Bearer $t';
    },
  );

  final httpLink = authLink.concat(HttpLink(kHasuraHttpUrl));

  final wsLink = WebSocketLink(
    kHasuraWsUrl,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: () async {
        await OidcAuth.refreshIfNeeded();
        final t = await OidcAuth.readAccessToken();
        return {'headers': {'Authorization': 'Bearer $t'}};
      },
    ),
  );

  final split = Link.split((op) => op.isSubscription, wsLink, httpLink);
  final link = _baseLink().concat(split);
  return _clientFrom(link);
}

GraphQLClient buildPublicHasuraClient() {
  final httpLink = HttpLink(kHasuraHttpUrl);
  final wsLink = WebSocketLink(
    kHasuraWsUrl,
    config: const SocketClientConfig(autoReconnect: true),
  );
  final split = Link.split((op) => op.isSubscription, wsLink, httpLink);
  final link = _baseLink().concat(split);
  return _clientFrom(link);
}
