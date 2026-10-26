import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';

/// Opt-in production check. Supply an ignored --dart-define-from-file file.
/// Never run with a personal account or publish this test's APK.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  const language = String.fromEnvironment('E2E_LANGUAGE', defaultValue: 'en');
  testWidgets(
    'real authentication, encrypted restoration, profile and tracking',
    (tester) async {
      expect(
        email.contains('+myoccasio-mobile-'),
        isTrue,
        reason: 'Use only a dedicated, explicitly authorized test account.',
      );
      final store = SecureCookieStore(const FlutterSecureStorage());
      final client = ApiClient(
        baseUri: Uri.parse('https://myoccasio.ca'),
        cookieStore: store,
        language: () => language,
        requestTimeout: const Duration(seconds: 60),
      );
      final auth = AuthRepository(client, store);
      try {
        final session = await retryNetwork(
          () => auth.signIn(email: email, password: password),
        );
        expect(session.isAuthenticated, isTrue);
        expect(session.email, email);
        expect(await store.read(), isNotEmpty);
        // A fresh repository and storage instance must restore the persisted cookie.
        final restoredClient = ApiClient(
          baseUri: Uri.parse('https://myoccasio.ca'),
          cookieStore: SecureCookieStore(const FlutterSecureStorage()),
          language: () => language,
          requestTimeout: const Duration(seconds: 60),
        );
        try {
          final restored = await AuthRepository(
            restoredClient,
            SecureCookieStore(const FlutterSecureStorage()),
          ).currentSession();
          expect(restored.isAuthenticated, isTrue);
          expect(restored.email, email);
        } finally {
          restoredClient.close();
        }
        final profileRepo = ProfileRepository(client);
        final profile = await retryNetwork(profileRepo.getCurrentUser);
        expect(profile.email, email);
        try {
          await retryNetwork(
            () => profileRepo.updateProfile({
              'firstName': 'Mobile verification check',
            }),
          );
          expect(
            (await profileRepo.getCurrentUser()).firstName,
            'Mobile verification check',
          );
        } finally {
          await retryNetwork(
            () => profileRepo.updateProfile({'firstName': profile.firstName}),
          );
        }
        // Preserve any existing résumé. This account owns a unique disposable
        // verification PDF only while the roundtrip below is running.
        if (await retryNetwork(profileRepo.getResume) == null) {
          final filename =
              'myoccasio-mobile-verification-${DateTime.now().microsecondsSinceEpoch}.pdf';
          final bytes = _verificationPdf();
          try {
            // A lost upload response must not overwrite the file a second time.
            final uploaded = await profileRepo.saveResume(filename, bytes);
            expect(uploaded.name, filename);
            expect(uploaded.mimeType, 'application/pdf');
            expect(uploaded.size, bytes.length);
            final metadata = await retryNetwork(profileRepo.getResume);
            expect(metadata, isNotNull);
            expect(metadata!.name, filename);
            expect(metadata.mimeType, 'application/pdf');
            expect(metadata.size, bytes.length);
            final downloaded = await retryNetwork(
              profileRepo.downloadResumeFile,
            );
            expect(downloaded.name, filename);
            expect(downloaded.mimeType, 'application/pdf');
            expect(downloaded.bytes, orderedEquals(bytes));
          } finally {
            // Resolve the unique name even if the upload response was lost, and
            // never remove a different résumé that appeared during this test.
            final current = await retryNetwork(profileRepo.getResume);
            if (current?.name == filename) {
              await profileRepo.removeResume();
            }
          }
          expect(await retryNetwork(profileRepo.getResume), isNull);
        }
        final matches = await OpportunitiesRepository(client).getMatches();
        expect(matches.opportunities, isNotEmpty);
        final tracking = ApplicationsRepository(client);
        final existing = await tracking.getTrackedApplications();
        final ids = existing.map((item) => item.opportunityId).toSet();
        final opportunity = matches.opportunities.firstWhere(
          (item) => !ids.contains(item.id),
        );
        String? trackingId;
        try {
          await retryNetwork(
            () =>
                tracking.saveTrackedApplication(opportunityId: opportunity.id),
          );
          var saved = (await tracking.getTrackedApplications()).singleWhere(
            (item) => item.opportunityId == opportunity.id,
          );
          trackingId = saved.id;
          expect(saved.status, 'saved');
          await retryNetwork(
            () => tracking.saveTrackedApplication(
              opportunityId: opportunity.id,
              status: 'drafting',
            ),
          );
          saved = (await tracking.getTrackedApplications()).singleWhere(
            (item) => item.opportunityId == opportunity.id,
          );
          expect(saved.status, 'drafting');
        } finally {
          if (trackingId != null) {
            await retryNetwork(() => tracking.removeSaved(trackingId!));
          }
        }
        final academics = AcademicsRepository(client);
        expect(await academics.getGradingScales(), isNotEmpty);
        final calculationTitle =
            'Mobile verification ${DateTime.now().microsecondsSinceEpoch}';
        try {
          // No mutation retry: a lost response must not create duplicate results.
          await academics.saveCalculation({
            'calculationType': 'gpa',
            'title': calculationTitle,
            'inputs': {'verification': true},
            'result': {
              'gpa': 3.5,
              'maximumGpa': 4,
              'summary': 'Verification estimate',
            },
          });
          final calculation = (await academics.getSnapshot()).calculations
              .singleWhere((entry) => entry['title'] == calculationTitle);
          expect(calculation['result']['gpa'], 3.5);
        } finally {
          // Resolve the unique title even if the save response was lost.
          final created = (await retryNetwork(
            academics.getSnapshot,
          )).calculations.where((entry) => entry['title'] == calculationTitle);
          for (final calculation in created) {
            await academics.deleteCalculation(calculation['id'].toString());
          }
        }
        expect(
          (await academics.getSnapshot()).calculations.where(
            (entry) => entry['title'] == calculationTitle,
          ),
          isEmpty,
        );
        await auth.signOut();
        expect(await store.read(), isEmpty);
        expect((await auth.currentSession()).isAuthenticated, isFalse);
      } finally {
        try {
          await store.clear();
        } finally {
          client.close();
        }
      }
    },
    skip: email.isEmpty || password.isEmpty,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

/// A valid, self-contained one-page PDF with no personal or account data.
/// Byte offsets use ASCII text so the cross-reference table remains exact.
List<int> _verificationPdf() {
  final document = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  void object(int id, String body) {
    offsets.add(document.length);
    document.write('$id 0 obj\n$body\nendobj\n');
  }

  const content =
      'BT /F1 12 Tf 72 720 Td (MyOccasio mobile verification fixture.) Tj ET\n';
  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  object(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
    '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
  );
  object(4, '<< /Length ${content.length} >>\nstream\n${content}endstream');
  object(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  final crossReference = document.length;
  document.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    document.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  document.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
    'startxref\n$crossReference\n%%EOF\n',
  );
  return ascii.encode(document.toString());
}

// Test-only retry for known idempotent operations against the dedicated account.
// Production mutation requests never retry automatically.
Future<T> retryNetwork<T>(Future<T> Function() action) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await action();
    } on ApiException catch (error) {
      if (error.statusCode != null || attempt >= 3) rethrow;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}
