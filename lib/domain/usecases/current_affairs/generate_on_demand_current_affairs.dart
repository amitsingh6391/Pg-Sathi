import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/failure.dart';
import '../../entities/current_affair.dart';
import 'current_affairs_usecases.dart';

/// Admin on-demand generation of current affairs articles.
///
/// Calls the Groq API directly from the Flutter app — no Cloud Function needed.
/// Articles are generated and saved to Firestore by the admin client.
class GenerateOnDemandCurrentAffairs {
  const GenerateOnDemandCurrentAffairs({
    required this.firestore,
    required this.firebaseAuth,
    required this.remoteConfig,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;
  final FirebaseRemoteConfig remoteConfig;

  static const _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _rssFeeds = [
    ('https://www.thehindu.com/feeder/default.rss', 'The Hindu'),
    ('https://economictimes.indiatimes.com/rssfeedstopstories.cms', 'Economic Times'),
    ('https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml', 'Hindustan Times'),
    ('https://www.livemint.com/rss/news', 'Livemint'),
    ('https://indianexpress.com/feed/', 'Indian Express'),
  ];

  /// Fetches live headlines from Indian news RSS feeds.
  Future<List<String>> _fetchRssHeadlines({int maxPerFeed = 5}) async {
    final headlines = <String>[];
    for (final (url, source) in _rssFeeds) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) continue;
        final xml = res.body;
        final items = RegExp(r'<item[\s>]([\s\S]*?)<\/item>').allMatches(xml);
        int count = 0;
        for (final item in items) {
          if (count >= maxPerFeed) break;
          final titleMatch =
              RegExp(r'<title[^>]*>([\s\S]*?)<\/title>').firstMatch(item.group(1) ?? '');
          if (titleMatch == null) continue;
          var title = titleMatch.group(1) ?? '';
          title = title
              .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .trim();
          if (title.length > 5 &&
              !title.toLowerCase().contains('advertisement')) {
            headlines.add('[$source] $title');
            count++;
          }
        }
        debugPrint('[RSS] $count headlines from $source');
      } catch (e) {
        debugPrint('[RSS] Failed to fetch $source: $e');
      }
    }
    debugPrint('[RSS] Total ${headlines.length} headlines fetched');
    return headlines;
  }

  Future<Either<Failure, List<CurrentAffair>>> call({
    required int count,
    String? category,
    bool sendNotification = true,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        return const Left(CurrentAffairsFailure(message: 'Not signed in'));
      }

      // Get Groq API key from Remote Config
      final apiKey = remoteConfig.getString('groq_api_key');
      if (apiKey.isEmpty) {
        return const Left(CurrentAffairsFailure(
            message: 'Groq API key not configured in Remote Config'));
      }
      final model = remoteConfig.getString('groq_model').isNotEmpty
          ? remoteConfig.getString('groq_model')
          : 'llama-3.3-70b-versatile';

      final categoryInstruction = category != null && category != 'all'
          ? '\n\nIMPORTANT: ALL $count articles MUST be about "$category" category ONLY. Set category to "$category" for every article.'
          : '\n\nIMPORTANT: Cover diverse categories.';

      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      // Fetch live RSS headlines so articles are grounded in today's news
      final rssHeadlines = await _fetchRssHeadlines(maxPerFeed: 5);
      final hasRealNews = rssHeadlines.isNotEmpty;
      final realNewsSection = hasRealNews
          ? '\n\n=== REAL HEADLINES FROM INDIAN NEWS SOURCES ===\n'
              '${rssHeadlines.take(count * 5).join('\n')}\n'
              '=== END OF HEADLINES ===\n\n'
              'YOU MUST base your $count articles on the headlines above. Do NOT fabricate news not in the list.'
          : '\n\nNOTE: Live news fetch failed. Use your knowledge of the most recent events.';

      final prompt =
          'Generate exactly $count current affairs articles IN ENGLISH for Indian competitive exam aspirants (UPSC/SSC/Banking).\n\n'
          'Date: $dateStr\n'
          '$categoryInstruction\n'
          '$realNewsSection\n\n'
          'For each article:\n'
          '- title: Headline-style title (max 15 words, in English)\n'
          '- summary: 1-2 sentence summary of what happened (in English)\n'
          '- content: 3-5 paragraphs — what happened, why it matters, key facts, exam relevance (in English)\n'
          '- category: one of: national, international, economy, science, environment, polity, sports, defense, other\n'
          '- source: source from the headlines above\n\n'
          'Return only valid JSON:\n'
          '{"articles":[{"title":"...","summary":"...","content":"...","category":"national","source":"The Hindu"}]}';

      debugPrint('[AI Generate] Calling Groq directly: count=$count, category=$category, rssHeadlines=${rssHeadlines.length}');

      final response = await http
          .post(
            Uri.parse(_groqUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a current affairs editor for Indian competitive exams (UPSC/SSC/Banking). Return only valid JSON.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.7,
              'max_tokens': 8192,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        debugPrint('[AI Generate] Groq error: ${response.statusCode} ${response.body}');
        return Left(CurrentAffairsFailure(
            message: 'Groq API error (${response.statusCode})'));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          decoded['choices']?[0]?['message']?['content'] as String? ?? '';

      var cleaned = text.trim();
      if (cleaned.contains('```json')) {
        cleaned =
            cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawArticles = (parsed['articles'] as List?) ?? [];

      debugPrint('[AI Generate] Groq returned ${rawArticles.length} articles');

      if (rawArticles.isEmpty) {
        return const Left(
            CurrentAffairsFailure(message: 'No articles returned by AI'));
      }

      // Save to Firestore
      final batch = firestore.batch();
      final timestamp = Timestamp.now();
      final savedArticles = <CurrentAffair>[];

      for (final raw in rawArticles) {
        final article = raw as Map<String, dynamic>;
        final docRef = firestore.collection('current_affairs').doc();
        final data = {
          'title': article['title'] ?? '',
          'summary': article['summary'] ?? '',
          'content': article['content'] ?? '',
          'category':
              (article['category'] ?? 'other').toString().toLowerCase(),
          'source': article['source'],
          'imageUrl': null,
          'createdBy': 'admin_ai_on_demand',
          'createdAt': timestamp,
          'publishedAt': timestamp,
          'generationSlot': 'on_demand',
        };
        batch.set(docRef, data);
        savedArticles.add(CurrentAffair(
          id: docRef.id,
          title: data['title'] as String,
          summary: data['summary'] as String,
          content: data['content'] as String,
          category: CurrentAffairsCategory.values.firstWhere(
            (e) => e.name == (data['category'] as String),
            orElse: () => CurrentAffairsCategory.other,
          ),
          source: data['source'] as String?,
          imageUrl: null,
          createdBy: 'admin_ai_on_demand',
          createdAt: timestamp.toDate(),
          publishedAt: timestamp.toDate(),
        ));
      }

      await batch.commit();
      debugPrint(
          '[AI Generate] Saved ${savedArticles.length} articles to Firestore');

      // Trigger push notification to all students via topic
      if (savedArticles.isNotEmpty) {
        try {
          await firestore.collection('notification_requests').add({
            'broadcast': true,
            'title': 'Current Affairs - Latest Updates',
            'body': savedArticles.first.title,
            'data': {
              'type': 'current_affair',
              'currentAffairId': savedArticles.first.id,
            },
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('[AI Generate] Notification request written');
        } catch (e) {
          debugPrint('[AI Generate] Notification request failed (non-fatal): $e');
        }
      }

      return Right(savedArticles);
    } catch (e, st) {
      debugPrint('[AI Generate] Unexpected error: $e\n$st');
      return Left(CurrentAffairsFailure(message: 'Generation failed: $e'));
    }
  }
}

