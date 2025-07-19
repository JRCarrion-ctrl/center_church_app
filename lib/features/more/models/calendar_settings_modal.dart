import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';

class CalendarSettingsModal {
  static Future<void> show(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    List<String> selectedGroupIds = List.from(appState.visibleCalendarGroupIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Calendars to Show',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...appState.userGroups.map((group) => CheckboxListTile(
                    title: Text(group.name),
                    value: selectedGroupIds.contains(group.id),
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedGroupIds.add(group.id);
                        } else {
                          selectedGroupIds.remove(group.id);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    appState.setVisibleCalendarGroupIds(selectedGroupIds);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
