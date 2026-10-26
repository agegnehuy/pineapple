import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final ProfileRepository repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _institution;
  late final TextEditingController _program;
  late final TextEditingController _year;
  late final TextEditingController _citizenship;
  late final TextEditingController _gpa;
  late final TextEditingController _interests;
  late final TextEditingController _opportunityTypes;
  String _financialNeed = '';
  bool _saving = false;
  String? _error;
  bool _allowPop = false;
  bool _confirmingLeave = false;
  late final List<String> _originalTexts;
  late final String _originalFinancialNeed;

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _institution,
    _program,
    _year,
    _citizenship,
    _gpa,
    _interests,
    _opportunityTypes,
  ];

  bool get _hasChanges =>
      _financialNeed != _originalFinancialNeed ||
      _controllers.asMap().entries.any(
        (entry) => entry.value.text != _originalTexts[entry.key],
      );

  void _onEdited() => setState(() {});

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _institution = TextEditingController(text: profile.institution);
    _program = TextEditingController(text: profile.program);
    _year = TextEditingController(text: profile.year);
    _citizenship = TextEditingController(text: profile.citizenship);
    _gpa = TextEditingController(text: profile.gpa);
    _interests = TextEditingController(text: profile.interests.join(', '));
    _opportunityTypes = TextEditingController(
      text: profile.opportunityTypes.map(canonicalOpportunityType).join(', '),
    );
    _financialNeed = profile.financialNeed;
    _originalFinancialNeed = _financialNeed;
    _originalTexts = _controllers
        .map((controller) => controller.text)
        .toList(growable: false);
    for (final controller in _controllers) {
      controller.addListener(_onEdited);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onEdited);
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _list(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final requiredValues = {
      'First name': _firstName.text,
      'Last name': _lastName.text,
      'Institution': _institution.text,
      'Program of study': _program.text,
      'Year of study': _year.text,
      'Citizenship status': _citizenship.text,
    };
    for (final entry in requiredValues.entries) {
      if (entry.value.trim().isEmpty) {
        setState(() => _error = 'Enter ${entry.key.toLowerCase()}.');
        return;
      }
    }
    if (_list(_interests.text).isEmpty ||
        _list(_opportunityTypes.text).isEmpty) {
      setState(
        () => _error = 'Choose at least one interest and opportunity type.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateProfile({
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'institution': _institution.text.trim(),
        'program': _program.text.trim(),
        'year': _year.text.trim(),
        'citizenship': _citizenship.text.trim(),
        'gpa': _gpa.text.trim().replaceAll(',', '.'),
        'interests': _list(_interests.text),
        'opportunityTypes': _list(
          _opportunityTypes.text,
        ).map(canonicalOpportunityType).toSet().toList(),
        'financialNeed': _financialNeed,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Profile saved.')));
        _close(true);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException
            ? error.message
            : 'Your profile could not be saved. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(_error!),
          action: SnackBarAction(label: 'Retry', onPressed: _save),
        ),
      );
    }
  }

  void _close(bool changed) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(changed);
    });
  }

  Future<void> _confirmLeave() async {
    if (_saving || _confirmingLeave) return;
    _confirmingLeave = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Keep your changes?'),
        content: const AppText(
          'You have edits that haven’t been saved. Save them before leaving this page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const AppText('Discard changes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const AppText('Save and leave'),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (!mounted) return;
    if (choice == 'discard') _close(false);
    if (choice == 'save') await _save();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _allowPop || (!_hasChanges && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: AbsorbPointer(
        absorbing: _saving,
        child: Scaffold(
          appBar: AppBar(title: const AppText('Edit profile')),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                children: [
                  AppText(
                    'A profile that fits.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 12),
                  const AppText('Update your details whenever life changes.'),
                  const SizedBox(height: 28),
                  AppText(
                    'Your basics',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RequiredField(
                          controller: _firstName,
                          label: 'First name',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RequiredField(
                          controller: _lastName,
                          label: 'Last name',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _citizenship.text.isEmpty
                        ? null
                        : _citizenship.text,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(context, 'Citizenship status'),
                    ),
                    items: [
                      for (final entry in {
                        ...citizenshipOptions,
                        if (_citizenship.text.isNotEmpty &&
                            !citizenshipOptions.containsKey(_citizenship.text))
                          _citizenship.text: _citizenship.text,
                      }.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: AppText(entry.value),
                        ),
                    ],
                    onChanged: (value) => _citizenship.text = value ?? '',
                    validator: (value) => value?.isNotEmpty == true
                        ? null
                        : AppStrings.tr(
                            context,
                            'Choose your citizenship status.',
                          ),
                  ),
                  const SizedBox(height: 28),
                  AppText(
                    'Academics',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _RequiredField(
                    controller: _institution,
                    label: 'Institution',
                  ),
                  const SizedBox(height: 16),
                  _RequiredField(
                    controller: _program,
                    label: 'Program or field of study',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _year.text.isEmpty ? null : _year.text,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr(context, 'Year of study'),
                          ),
                          items: [
                            for (final year in {
                              ...studyYears,
                              if (_year.text.isNotEmpty) _year.text,
                            })
                              DropdownMenuItem(
                                value: year,
                                child: studyYears.contains(year)
                                    ? AppText(year)
                                    : Text(year),
                              ),
                          ],
                          onChanged: (value) => _year.text = value ?? '',
                          validator: (value) => value?.isNotEmpty == true
                              ? null
                              : AppStrings.tr(context, 'Required'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _gpa,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.tr(context, 'GPA'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AppText(
                    'What you want',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _MultiChoiceField(
                    controller: _interests,
                    label: 'Interests',
                    options: {
                      for (final interest in matchingInterests)
                        interest: interest,
                    },
                    requiredMessage: 'Add at least one interest.',
                  ),
                  const SizedBox(height: 16),
                  _MultiChoiceField(
                    controller: _opportunityTypes,
                    label: 'Opportunity types',
                    options: opportunityTypeOptions,
                    requiredMessage: 'Add at least one opportunity type.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        {'yes', 'no', 'prefer-not'}.contains(_financialNeed)
                        ? _financialNeed
                        : '',
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(context, 'Financial need'),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: AppText('Select one')),
                      DropdownMenuItem(value: 'yes', child: AppText('Yes')),
                      DropdownMenuItem(value: 'no', child: AppText('No')),
                      DropdownMenuItem(
                        value: 'prefer-not',
                        child: AppText('Prefer not to say'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _financialNeed = value ?? ''),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AppText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: AppBusyIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const AppText('Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: AppStrings.tr(context, label)),
      validator: (value) => (value?.trim().isEmpty ?? true)
          ? AppStrings.tr(context, 'Required')
          : null,
    );
  }
}

class _MultiChoiceField extends StatelessWidget {
  const _MultiChoiceField({
    required this.controller,
    required this.label,
    required this.options,
    required this.requiredMessage,
  });
  final TextEditingController controller;
  final String label, requiredMessage;
  final Map<String, String> options;
  Set<String> get selected => controller.text
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet();
  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: controller.text,
    validator: (_) =>
        selected.isEmpty ? AppStrings.tr(context, requiredMessage) : null,
    builder: (field) => InputDecorator(
      decoration: InputDecoration(
        labelText: AppStrings.tr(context, label),
        errorText: field.errorText,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in {...options.keys, ...selected})
            FilterChip(
              label: options.containsKey(key)
                  ? AppText(options[key]!)
                  : Text(key),
              selected: selected.contains(key),
              onSelected: (value) {
                final values = selected;
                if (value) {
                  values.add(key);
                } else {
                  values.remove(key);
                }
                controller.text = values.join(', ');
                field.didChange(controller.text);
              },
            ),
        ],
      ),
    ),
  );
}
