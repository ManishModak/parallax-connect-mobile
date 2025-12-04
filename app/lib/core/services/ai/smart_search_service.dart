import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../features/settings/data/settings_storage.dart';
import '../storage/config_storage.dart';
import '../../network/dio_provider.dart';
import '../../utils/logger.dart';

/// Result from Smart Search
class SmartSearchResult {
  final bool needsSearch;
  final String searchQuery;
  final String reason;
  final List<SearchResultItem> results;
  final String summary;

  SmartSearchResult({
    required this.needsSearch,
    this.searchQuery = '',
    this.reason = '',
    this.results = const [],
    this.summary = '',
  });
}

class SearchResultItem {
  final String title;
  final String url;
  final String snippet;
  String content; // Mutable to allow updating after fetch

  SearchResultItem({
    required this.title,
    required this.url,
    required this.snippet,
    this.content = '',
  });
}

/// Service to handle "Smart" web search (Router + Execution)
class SmartSearchService {
  final SettingsStorage _settings;
  final String _baseUrl; // Parallax API URL
  final Dio _dio;

  SmartSearchService(this._settings, this._baseUrl, this._dio);

  /// Main entry point: Analyze intent and search if needed
  Future<SmartSearchResult> smartSearch(
    String query,
    List<Map<String, String>> history, {
    String depth = 'deep',
  }) async {
    final isSmartEnabled = _settings.getSmartSearchEnabled();
    final executionMode = _settings
        .getWebSearchExecutionMode(); // mobile, middleware, parallax

    if (!isSmartEnabled) {
      return SmartSearchResult(
        needsSearch: false,
        reason: 'Smart search disabled',
      );
    }

    // 1. Router Step (Intent Classification)
    final routerResult = await _classifyIntent(query, history);

    if (!routerResult['needs_search']) {
      return SmartSearchResult(
        needsSearch: false,
        reason: routerResult['reason'] ?? 'No search needed',
      );
    }

    final searchQuery = routerResult['search_query'] ?? query;
    Log.i('🧠 Smart Search: Searching for "$searchQuery" via $executionMode');

    // 2. Execution Step
    List<SearchResultItem> results = [];

    if (executionMode == 'middleware') {
      results = await _searchViaMiddleware(searchQuery, depth);
    } else if (executionMode == 'mobile') {
      results = await _searchOnDevice(searchQuery, depth);
    } else {
      // Parallax mode (future)
      Log.w('Parallax search mode not implemented yet');
    }

    return SmartSearchResult(
      needsSearch: true,
      searchQuery: searchQuery,
      reason: routerResult['reason'],
      results: results,
      summary: _formatResults(results),
    );
  }

  /// Calls Parallax to classify intent
  Future<Map<String, dynamic>> _classifyIntent(
    String query,
    List<Map<String, String>> history,
  ) async {
    try {
      // Construct prompt similar to Python router
      final systemPrompt =
          'You are a Search Intent Classifier. Respond ONLY with JSON: {"needs_search": true/false, "search_query": "keywords", "reason": "why"}. Rules: Search if user asks for facts, news, prices, or "search". Do NOT search for greetings, coding help, or chat summarization.';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        ...history.take(2), // Take last 2
        {'role': 'user', 'content': query},
      ];

      final response = await _dio.post(
        '$_baseUrl/v1/chat/completions',
        data: {
          'model': 'default',
          'messages': messages,
          'stream': false,
          'max_tokens': 150,
          'temperature': 0.0,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final choice = data['choices'][0] as Map<String, dynamic>;
        // Handle both Parallax format ('messages') and OpenAI format ('message')
        final messageData = choice['messages'] ?? choice['message'];
        String content = messageData['content'] as String;
        content = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return jsonDecode(content);
      }
    } catch (e) {
      Log.e('Router failed', e);
    }

    // Fallback Heuristics - comprehensive trigger detection
    final lower = query.toLowerCase();

    // Core triggers
    final coreTriggers = [
      'price',
      'cost',
      'worth',
      'news',
      'latest',
      'recent',
      'update',
      'today',
      'yesterday',
      'current',
      'now',
      'weather',
      'forecast',
      'search',
      'find',
      'look up',
      'who is',
      'what is',
      'where is',
    ];

    // Temporal and comparison triggers
    final otherTriggers = [
      '2024',
      '2025',
      'this year',
      'vs',
      'versus',
      'compared to',
      'better than',
      'how much',
      'how many',
      'how to',
    ];

    final allTriggers = [...coreTriggers, ...otherTriggers];
    final needsSearch = allTriggers.any((t) => lower.contains(t));

    return {
      'needs_search': needsSearch,
      'search_query': query,
      'reason': 'Fallback heuristic',
    };
  }

  /// Execute search via Middleware API
  Future<List<SearchResultItem>> _searchViaMiddleware(
    String query,
    String depth,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/search',
        data: {'query': query, 'depth': depth},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = data['results'] as List;
        return list
            .map(
              (e) => SearchResultItem(
                title: e['title'],
                url: e['url'],
                snippet: e['snippet'],
                content: e['content'] ?? '',
              ),
            )
            .toList();
      }
    } catch (e) {
      Log.e('Middleware search failed', e);
    }
    return [];
  }

  /// Execute search on device (DuckDuckGo HTML scraping)
  Future<List<SearchResultItem>> _searchOnDevice(
    String query,
    String depth,
  ) async {
    try {
      // 1. Get Links (DuckDuckGo HTML)
      final response = await _dio.post(
        'https://html.duckduckgo.com/html/',
        data: {'q': query},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.data as String);
      final results = document.querySelectorAll('.result:not(.result--ad)');

      List<SearchResultItem> items = [];
      int count = 0;

      // Determine limits based on depth
      // final depth = _settings.getWebSearchDepth(); // Removed
      int maxResults = depth == 'normal' ? 4 : (depth == 'deep' ? 3 : 6);
      int fullContentCount = depth == 'normal' ? 1 : (depth == 'deep' ? 3 : 6);

      for (var result in results) {
        if (count >= maxResults) break;

        final titleEl = result.querySelector('.result__a');
        final snippetEl = result.querySelector('.result__snippet');
        final urlEl = result.querySelector('.result__url');

        if (titleEl != null && urlEl != null) {
          String link = titleEl.attributes['href'] ?? '';
          // Clean DDG link
          if (link.contains('uddg=')) {
            link = Uri.decodeComponent(link.split('uddg=')[1].split('&')[0]);
          }

          items.add(
            SearchResultItem(
              title: titleEl.text.trim(),
              url: link,
              snippet: snippetEl?.text.trim() ?? '',
            ),
          );
          count++;
        }
      }

      // 2. Fetch Content (Parallel)
      List<Future<void>> tasks = [];
      for (int i = 0; i < items.length; i++) {
        if (i < fullContentCount) {
          tasks.add(_fetchPageContent(items[i]));
        }
      }
      await Future.wait(tasks);

      return items;
    } catch (e) {
      Log.e('Device search failed', e);
      return [];
    }
  }

  Future<void> _fetchPageContent(SearchResultItem item) async {
    try {
      final response = await _dio.get(
        item.url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200) {
        final doc = html_parser.parse(response.data as String);

        // Extended noise removal (matching server-side)
        doc
            .querySelectorAll(
              'script, style, nav, footer, header, aside, iframe, form, '
              'noscript, svg, button, input, select, textarea, menu',
            )
            .forEach((e) => e.remove());

        // Remove elements with ad/sidebar/comment-related classes
        doc
            .querySelectorAll('[class]')
            .where((el) {
              final classes = el.className.toLowerCase();
              final noisePatterns = [
                'ad',
                'sidebar',
                'comment',
                'share',
                'social',
                'related',
                'newsletter',
                'popup',
                'cookie',
              ];
              return noisePatterns.any((p) => classes.contains(p));
            })
            .forEach((e) => e.remove());

        // Prioritize article content
        var content =
            doc.querySelector('article') ??
            doc.querySelector('main') ??
            doc.querySelector('[role="main"]') ??
            doc.querySelector(
              '.article-content, .post-content, .entry-content',
            );

        // Fallback to body
        content ??= doc.body;

        String text =
            content?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

        // Increased limit for better context
        if (text.length > 2000) {
          // Try to truncate at sentence boundary
          final truncated = text.substring(0, 2000);
          final lastPeriod = truncated.lastIndexOf('. ');
          if (lastPeriod > 1400) {
            text = '${truncated.substring(0, lastPeriod + 1)}';
          } else {
            text = '$truncated...';
          }
        }
        item.content = text;
      }
    } catch (e) {
      // Ignore - content will remain empty
    }
  }

  String _formatResults(List<SearchResultItem> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('\n\n[WEB SEARCH RESULTS]\n');
    for (var i = 0; i < results.length; i++) {
      buffer.writeln(
        'Source ${i + 1}: ${results[i].title} (${results[i].url})',
      );
      if (results[i].content.isNotEmpty) {
        buffer.writeln('Content: ${results[i].content}');
      } else {
        buffer.writeln('Snippet: ${results[i].snippet}');
      }
      buffer.writeln('---');
    }
    buffer.writeln('[END WEB SEARCH RESULTS]\n\n');
    return buffer.toString();
  }
}

final smartSearchServiceProvider = Provider<SmartSearchService>((ref) {
  final settings = ref.watch(settingsStorageProvider);
  final configStorage = ref.watch(configStorageProvider);
  final dio = ref.watch(dioProvider);
  final baseUrl = configStorage.getBaseUrl() ?? 'http://localhost:8000';
  return SmartSearchService(settings, baseUrl, dio);
});
