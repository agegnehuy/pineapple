class Opportunity {
  const Opportunity({
    required this.id,
    required this.title,
    required this.organization,
    required this.kind,
    required this.kindLabel,
    required this.amount,
    required this.amountSub,
    required this.deadline,
    required this.deadlineLabel,
    required this.summary,
    required this.match,
    required this.reasons,
    required this.tags,
    required this.logo,
    this.url,
    this.region = '',
    this.market = '',
    this.applyMode = 'external',
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);

    return Opportunity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Opportunity').toString(),
      organization: (json['org'] ?? '').toString(),
      kind: (json['kind'] ?? 'opportunity').toString(),
      kindLabel: (json['kindLabel'] ?? 'Opportunity').toString(),
      amount: (json['amount'] ?? '').toString(),
      amountSub: (json['amountSub'] ?? '').toString(),
      deadline: (json['deadline'] ?? '').toString(),
      deadlineLabel: (json['deadlineLabel'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      match: (json['match'] as num?)?.round() ?? 0,
      reasons: strings('reasons'),
      tags: strings('tags'),
      logo: (json['logo'] ?? '').toString(),
      url: json['url']?.toString(),
      region: (json['region'] ?? '').toString(),
      market: (json['market'] ?? '').toString(),
      applyMode: (json['applyMode'] ?? 'external').toString(),
    );
  }

  final String id;
  final String title;
  final String organization;
  final String kind;
  final String kindLabel;
  final String amount;
  final String amountSub;
  final String deadline;
  final String deadlineLabel;
  final String summary;
  final int match;
  final List<String> reasons;
  final List<String> tags;
  final String logo;
  final String? url;
  final String region;
  final String market;
  final String applyMode;
}
