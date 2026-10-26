import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.repository,
    required this.profile,
    super.key,
  });
  final ProfileRepository repository;
  final UserProfile profile;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late final _school = TextEditingController(text: widget.profile.institution);
  late final _program = TextEditingController(text: widget.profile.program);
  late String _year = widget.profile.year;
  late String _citizenship = widget.profile.citizenship;
  late final _interests = {...widget.profile.interests};
  late final _types = widget.profile.opportunityTypes
      .map(canonicalOpportunityType)
      .toSet();
  int _step = 0;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _school.dispose();
    _program.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      if (!_form.currentState!.validate()) return;
      final error = _school.text.trim().isEmpty
          ? 'Enter your school.'
          : _program.text.trim().isEmpty
          ? 'Enter your program.'
          : _year.isEmpty
          ? 'Choose your year.'
          : _citizenship.isEmpty
          ? 'Choose your residency.'
          : null;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      setState(() {
        _error = null;
        _step = 1;
      });
      return;
    }
    if (_interests.isEmpty || _types.isEmpty) {
      setState(
        () => _error = 'Choose at least one interest and opportunity type.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.updateProfile({
        'institution': _school.text.trim(),
        'program': _program.text.trim(),
        'year': _year,
        'citizenship': _citizenship,
        'interests': _interests.toList(),
        'opportunityTypes': _types.toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not save your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText('Set up your profile · ${_step + 1} of 2')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            _step == 0
                ? 'Start with where you are.'
                : 'What opens doors for you?',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          if (_step == 0)
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _school,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(
                        context,
                        'School or institution',
                      ),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? AppStrings.tr(context, 'Enter your school.')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _program,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(context, 'Program of study'),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? AppStrings.tr(context, 'Enter your program.')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _year.isEmpty ? null : _year,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(context, 'Year of study'),
                    ),
                    items: [
                      for (final year in {
                        'High school',
                        '1st year',
                        '2nd year',
                        '3rd year',
                        '4th year',
                        '5+ year',
                        'Graduate',
                        if (_year.isNotEmpty) _year,
                      })
                        DropdownMenuItem(
                          value: year,
                          child: studyYears.contains(year)
                              ? AppText(year)
                              : Text(year),
                        ),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? ''),
                    validator: (v) => (v?.isEmpty ?? true)
                        ? AppStrings.tr(context, 'Choose your year.')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _citizenship.isEmpty ? null : _citizenship,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(
                        context,
                        'Citizenship or residency',
                      ),
                    ),
                    items: [
                      for (final e in {
                        'citizen': 'Canadian citizen',
                        'pr': 'Permanent resident',
                        'intl': 'International student',
                        'refugee': 'Refugee',
                        'other': 'Other',
                        if (_citizenship.isNotEmpty &&
                            !{
                              'citizen',
                              'pr',
                              'intl',
                              'refugee',
                              'other',
                            }.contains(_citizenship))
                          _citizenship: _citizenship,
                      }.entries)
                        DropdownMenuItem(value: e.key, child: AppText(e.value)),
                    ],
                    onChanged: (v) => setState(() => _citizenship = v ?? ''),
                    validator: (v) => (v?.isEmpty ?? true)
                        ? AppStrings.tr(context, 'Choose your residency.')
                        : null,
                  ),
                ],
              ),
            )
          else ...[
            AppText(
              'Your interests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in {...matchingInterests, ..._interests})
                  FilterChip(
                    label: matchingInterests.contains(interest)
                        ? AppText(interest)
                        : Text(interest),
                    selected: _interests.contains(interest),
                    onSelected: _busy
                        ? null
                        : (v) => setState(() {
                            if (v) {
                              _interests.add(interest);
                            } else {
                              _interests.remove(interest);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AppText(
              'What are you looking for?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final e in const {
                  'scholarship': 'Scholarships',
                  'internship': 'Internships',
                  'grant': 'Grants',
                  'job': 'Jobs',
                }.entries)
                  FilterChip(
                    label: AppText(e.value),
                    selected: _types.contains(e.key),
                    onSelected: _busy
                        ? null
                        : (v) => setState(() {
                            if (v) {
                              _types.add(e.key);
                            } else {
                              _types.remove(e.key);
                            }
                          }),
                  ),
              ],
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(liveRegion: true, child: AppText(_error!)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _next,
            child: AppText(
              _busy
                  ? 'Saving…'
                  : _step == 0
                  ? 'Continue'
                  : 'Find my matches',
            ),
          ),
          if (_step == 1)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step = 0),
              child: const AppText('Back to education'),
            ),
        ],
      ),
    ),
  );
}
