import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_storage.dart';
import '../utils/logger.dart';

class SearchResult {
  final String title;
  final String url;
  final String snippet;

  SearchResult({required this.title, required this.url, required this.snippet});
}

/// Abstract provider for web search
abstract class WebSearchProvider {
  Future<List<SearchResult>> search(String query, {int limit = 10});
}

/// DuckDuckGo "Lite" HTML scraper (Free, Unlimited)
class DuckDuckGoSearchProvider implements WebSearchProvider {
  static const _baseUrl = 'https://html.duckduckgo.com/html';

  @override
  Future<List<SearchResult>> search(String query, {int limit = 10}) async {
    try {
      final cleanQuery = _cleanQuery(query);
      Log.d('DuckDuckGo Search: $cleanQuery');

      final response = await http.get(
        Uri.parse('$_baseUrl/?q=${Uri.encodeComponent(cleanQuery)}'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch search results: ${response.statusCode}',
        );
      }

      final document = html_parser.parse(response.body);
      final resultElements = document.querySelectorAll(
        '.result:not(.result--ad)',
      );
      final results = <SearchResult>[];

      int count = 0;
      for (final result in resultElements) {
        if (count >= limit) break;

        final titleElement = result.querySelector('.result__a');
        final snippetElement = result.querySelector('.result__snippet');
        final urlElement = result.querySelector('.result__url');

        if (titleElement != null && snippetElement != null) {
          String url = urlElement?.text.trim() ?? '';
          final href = titleElement.attributes['href'];
          if (href != null) {
            if (href.startsWith('http')) {
              url = href;
            } else if (href.contains('uddg=')) {
              final uri = Uri.parse('https://html.duckduckgo.com$href');
              url = uri.queryParameters['uddg'] ?? url;
            }
          }

          results.add(
            SearchResult(
              title: titleElement.text.trim(),
              url: url,
              snippet: snippetElement.text.trim(),
            ),
          );
          count++;
        }
      }

      return results;
    } catch (e) {
      Log.e('DuckDuckGo search failed', e);
      return [];
    }
  }

  String _cleanQuery(String query) {
    // Basic cleaning: remove extra spaces
    return query.trim();
  }
}

/// Brave Search API (Free Tier: 2k/month)
class BraveSearchProvider implements WebSearchProvider {
  static const _baseUrl = 'https://api.search.brave.com/res/v1/web/search';
  final String apiKey;
  final Dio _dio;

  BraveSearchProvider(this.apiKey) : _dio = Dio();

  @override
  Future<List<SearchResult>> search(String query, {int limit = 10}) async {
    try {
      Log.d('Brave Search: $query');
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'q': query, 'count': limit},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'X-Subscription-Token': apiKey,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Brave API error: ${response.statusCode}');
      }

      final data = response.data;
      final resultsList = data['web']?['results'] as List?;

      if (resultsList == null || resultsList.isEmpty) {
        return [];
      }

      return resultsList.map((result) {
        return SearchResult(
          title: result['title'] ?? '',
          url: result['url'] ?? '',
          snippet: result['description'] ?? '',
        );
      }).toList();
    } catch (e) {
      Log.e('Brave search failed', e);
      return [];
    }
  }
}

class WebSearchService {
  final SettingsStorage _settings;

  WebSearchService(this._settings);

  Future<String> search(String query) async {
    final providerType = _settings.getWebSearchProvider();
    final depth = _settings.getWebSearchDepth();
    WebSearchProvider provider;

    if (providerType == 'brave') {
      final apiKey = _settings.getBraveSearchApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        provider = BraveSearchProvider(apiKey);
      } else {
        Log.w('Brave API key missing, falling back to DuckDuckGo');
        provider = DuckDuckGoSearchProvider();
      }
    } else {
      provider = DuckDuckGoSearchProvider();
    }

    // Search Depth Configuration
    int resultLimit;
    int contentFetchLimit;
    int contentLengthLimit;
    Duration fetchTimeout;

    switch (depth) {
      case 'deeper':
        resultLimit = 20;
        contentFetchLimit = 10;
        contentLengthLimit = 6000;
        fetchTimeout = const Duration(seconds: 10);
        break;
      case 'deep':
        resultLimit = 15;
        contentFetchLimit = 5;
        contentLengthLimit = 3000;
        fetchTimeout = const Duration(seconds: 6);
        break;
      case 'normal':
      default:
        resultLimit = 10;
        contentFetchLimit = 2;
        contentLengthLimit = 1000;
        fetchTimeout = const Duration(seconds: 3);
        break;
    }

    final results = await provider.search(query, limit: resultLimit);

    if (results.isEmpty) {
      return 'No search results found for: $query';
    }

    final buffer = StringBuffer();
    // Fetch content for top results in parallel
    final topResults = results.take(contentFetchLimit).toList();
    final contentFutures = topResults.map(
      (r) => _fetchPageContent(r.url, contentLengthLimit, fetchTimeout),
    );
    final contents = await Future.wait(contentFutures);

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('Title: ${result.title}');
      buffer.writeln('URL: ${result.url}');
      buffer.writeln('Snippet: ${result.snippet}');

      if (i < contentFetchLimit && contents[i].isNotEmpty) {
        buffer.writeln('Page Content: ${contents[i]}');
      }
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  Future<String> _fetchPageContent(
    String url,
    int lengthLimit,
    Duration timeout,
  ) async {
    if (url.isEmpty) return '';
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        // Remove noise
        document
            .querySelectorAll(
              'script, style, nav, footer, header, aside, iframe',
            )
            .forEach((e) => e.remove());

        final text =
            document.body?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

        // Limit characters for context
        return text.length > lengthLimit
            ? '${text.substring(0, lengthLimit)}...'
            : text;
      }
    } catch (e) {
      // Ignore errors during deep fetch
      Log.d('Failed to fetch content for $url: $e');
    }
    return '';
  }
}

final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  final settings = ref.watch(settingsStorageProvider);
  return WebSearchService(settings);
});
