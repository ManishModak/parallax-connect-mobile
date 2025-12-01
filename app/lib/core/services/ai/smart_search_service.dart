import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../../features/settings/data/settings_storage.dart';
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

  SmartSearchService(this._settings, this._baseUrl);

  /// Main entry point: Analyze intent and search if needed
  Future<SmartSearchResult> smartSearch(
    String query,
    List<Map<String, String>> history,
  ) async {
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
      results = await _searchViaMiddleware(searchQuery);
    } else if (executionMode == 'mobile') {
      results = await _searchOnDevice(searchQuery);
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

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'default',
          'messages': messages,
          'stream': false,
          'max_tokens': 150,
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'];
        content = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return jsonDecode(content);
      }
    } catch (e) {
      Log.e('Router failed', e);
    }

    // Fallback Heuristic
    final lower = query.toLowerCase();
    final needsSearch =
        lower.contains('price') ||
        lower.contains('news') ||
        lower.contains('search');
    return {
      'needs_search': needsSearch,
      'search_query': query,
      'reason': 'Fallback heuristic',
    };
  }

  /// Execute search via Middleware API
  Future<List<SearchResultItem>> _searchViaMiddleware(String query) async {
    try {
      final depth = _settings.getWebSearchDepth();
      final response = await http.post(
        Uri.parse('$_baseUrl/search'), // Custom endpoint we created
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'depth': depth}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
  Future<List<SearchResultItem>> _searchOnDevice(String query) async {
    try {
      // 1. Get Links (Lite)
      final url = Uri.parse('https://html.duckduckgo.com/html/');
      final response = await http.post(url, body: {'q': query});

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final results = document.querySelectorAll('.result:not(.result--ad)');

      List<SearchResultItem> items = [];
      int count = 0;

      // Determine limits based on depth
      final depth = _settings.getWebSearchDepth();
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
      final response = await http
          .get(Uri.parse(item.url))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final doc = html_parser.parse(response.body);
        doc
            .querySelectorAll('script, style, nav, footer, header')
            .forEach((e) => e.remove());
        // Simple text extraction
        String text =
            doc.body?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
        if (text.length > 1000) text = text.substring(0, 1000) + '...';
        item.content = text; // Update content
      }
    } catch (e) {
      // Ignore
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
  // We need the base URL. Usually in a config provider.
  // For now hardcode or get from env if available in Dart?
  // We'll assume localhost for dev or use a config provider.
  // Let's use a placeholder and fix it in the next step when we see where URL is stored.
  return SmartSearchService(settings, 'http://localhost:8000');
});
