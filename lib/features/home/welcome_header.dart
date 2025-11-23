// File: lib/features/home/welcome_header.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/features/media/media_service.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  Future<List<String>>? _serviceTimeFuture; 

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = GraphQLProvider.of(context).value;
    
    _serviceTimeFuture ??= _loadTimes(client);
  }

  // CHANGE 2: Return raw strings directly
  Future<List<String>> _loadTimes(GraphQLClient client) async {
    try {
      final data = await MediaService(client).getServiceTime();
      
      final englishStr = data['english'];
      final spanishStr = data['spanish'];

      if (englishStr == null || englishStr.isEmpty || 
          spanishStr == null || spanishStr.isEmpty) {
        return []; 
      }

      // No parsing needed, just return what the server sent
      return [englishStr, spanishStr];
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CHANGE 3: Builder expects List<String>
    return FutureBuilder<List<String>>(
      future: _serviceTimeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150, 
            child: Center(child: CircularProgressIndicator())
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); 
        }

        final times = snapshot.data!;
        final englishTime = times[0]; 
        final spanishTime = times[1]; 

        return NextServiceCard(
          nextEnglishService: englishTime,
          nextSpanishService: spanishTime,
          currentTime: _currentTime,
        );
      },
    );
  }
}

class NextServiceCard extends StatelessWidget {
  // CHANGE 4: Fields are now Strings
  final String nextEnglishService;
  final String nextSpanishService;
  final DateTime currentTime;

  const NextServiceCard({
    super.key,
    required this.nextEnglishService,
    required this.nextSpanishService,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            "key_420".tr(), // "Join Us"
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "key_421".tr(), // "this sunday"
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          _ServiceTimeRow(
            title: "key_422".tr(), // "English Service"
            // CHANGE 5: Pass string directly, no DateFormat needed
            time: nextEnglishService,
          ),
          const SizedBox(height: 16),
          _ServiceTimeRow(
            title: "key_423".tr(), // "Spanish Service"
            time: nextSpanishService,
          ),
        ],
      ),
    );
  }
}

class _ServiceTimeRow extends StatelessWidget {
  final String title;
  final String time;

  const _ServiceTimeRow({
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(title, style: textTheme.titleMedium),
        const Spacer(),
        Text(
          time,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}