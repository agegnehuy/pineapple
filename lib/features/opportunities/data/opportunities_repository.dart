import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';

class OpportunityFeed {
  const OpportunityFeed({
    required this.opportunities,
    required this.totalMatches,
    required this.profileStatus,
    this.firstName = '',
  });

  final List<Opportunity> opportunities;
  final int totalMatches;
  final String profileStatus;
  final String firstName;
}

class OpportunitiesRepository {
  OpportunitiesRepository(this._api);

  final ApiClient _api;

  Future<OpportunityFeed> getMatches() async {
    final response = await _api.get('/api/matches');
    final json = response.json as Map<String, dynamic>;
    final rawMatches = json['matches'] as List<dynamic>? ?? const [];
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    return OpportunityFeed(
      opportunities: rawMatches
          .whereType<Map<String, dynamic>>()
          .map(Opportunity.fromJson)
          .toList(growable: false),
      totalMatches:
          (json['totalMatches'] as num?)?.round() ?? rawMatches.length,
      profileStatus: (profile['status'] ?? '').toString(),
      firstName: (profile['firstName'] ?? '').toString(),
    );
  }
}
