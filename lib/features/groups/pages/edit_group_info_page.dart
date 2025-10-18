// File: lib/features/groups/pages/edit_group_info_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ccf_app/core/graph_provider.dart';
import '../models/group.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';

class EditGroupInfoPage extends StatefulWidget {
  final Group group;

  const EditGroupInfoPage({super.key, required this.group});

  @override
  State<EditGroupInfoPage> createState() => _EditGroupInfoPageState();
}

class _EditGroupInfoPageState extends State<EditGroupInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  GraphQLClient? _client;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController =
        TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client ??= GraphProvider.of(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_client == null) return;

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final descRaw = _descriptionController.text.trim();
    final desc = descRaw.isEmpty ? null : descRaw;

    // 1) Update group (by PK)
    const mUpdate = r'''
      mutation UpdateGroup($id: uuid!, $name: String!, $description: String) {
        update_groups_by_pk(
          pk_columns: { id: $id },
          _set: { name: $name, description: $description }
        ) { id }
      }
    ''';

    // 2) Read back the full group (so we can return an up-to-date model)
    const qGroup = r'''
      query GetGroup($id: uuid!) {
        groups_by_pk(id: $id) {
          id
          name
          description
          photo_url
          visibility
          temporary
          archived
          created_at
        }
      }
    ''';

    try {
      final upd = await _client!.mutate(MutationOptions(
        document: gql(mUpdate),
        variables: {
          'id': widget.group.id,
          'name': name,
          'description': desc,
        },
      ));
      if (upd.hasException) throw upd.exception!;

      final qry = await _client!.query(QueryOptions(
        document: gql(qGroup),
        variables: {'id': widget.group.id},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (qry.hasException) throw qry.exception!;

      final data = qry.data?['groups_by_pk'] as Map<String, dynamic>?;
      if (data == null) throw Exception('Group not found after update');

      final updatedGroup = Group.fromMap(data);

      if (!mounted) return;
      Navigator.of(context).pop(updatedGroup);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_068".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "key_068a".tr()),
                validator: (value) =>
                    value == null || value.isEmpty ? "key_068b".tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: "key_068c".tr()),
                maxLines: 4,
              ),
              const Spacer(),
              if (_saving)
                const CircularProgressIndicator()
              else
                PrimaryButton(
                  title: "key_068d".tr(),
                  onTap: _saveChanges,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
