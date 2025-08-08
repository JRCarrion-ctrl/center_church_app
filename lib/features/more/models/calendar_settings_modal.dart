import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import 'package:easy_localization/easy_localization.dart';

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
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              bool isAllSelected = selectedGroupIds.length == appState.userGroups.length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "key_197a".tr(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isAllSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedGroupIds = appState.userGroups.map((g) => g.id).toList();
                              } else {
                                selectedGroupIds.clear();
                              }
                            });
                          },
                        ),
                        Text("key_197".tr()),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: appState.userGroups.length,
                        itemBuilder: (context, index) {
                          final group = appState.userGroups[index];
                          final isSelected = selectedGroupIds.contains(group.id);
                          return CheckboxListTile(
                            title: Text(group.name),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedGroupIds.add(group.id);
                                } else {
                                  selectedGroupIds.remove(group.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: Text("key_198".tr()),
                        onPressed: () {
                          appState.setVisibleCalendarGroupIds(selectedGroupIds);
                         Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
