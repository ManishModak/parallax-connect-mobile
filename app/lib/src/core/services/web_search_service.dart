import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_storage.dart';
import '../utils/logger.dart';

/// Abstract provider for web search
abstract class WebSearchProvider {
  Future<String> search(String query);
}

/// DuckDuckGo "Lite" HTML scraper (Free, Unlimited)
class DuckDuckGoSearchProvider implements WebSearchProvider {
  static const _baseUrl = 'https://html.duckduckgo.com/html';

  @override
  Future<String> search(String query) async {
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
      final results = document.querySelectorAll('.result');
      final buffer = StringBuffer();

      int count = 0;
      for (final result in results) {
        if (count >= 5) break; // Limit to top 5 results

        final titleElement = result.querySelector('.result__a');
        final snippetElement = result.querySelector('.result__snippet');
        final urlElement = result.querySelector('.result__url');

        if (titleElement != null && snippetElement != null) {
          buffer.writeln('Title: ${titleElement.text.trim()}');
          if (urlElement != null) {
            buffer.writeln('URL: ${urlElement.text.trim()}');
          }
          buffer.writeln('Snippet: ${snippetElement.text.trim()}');
          buffer.writeln('---');
          count++;
        }
      }

      if (buffer.isEmpty) {
        return 'No search results found for: $query';
      }

      return buffer.toString();
    } catch (e) {
      Log.e('DuckDuckGo search failed', e);
      return 'Error performing web search: $e';
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
  Future<String> search(String query) async {
    try {
      Log.d('Brave Search: $query');
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'q': query, 'count': 5},
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
      final results = data['web']?['results'] as List?;

      if (results == null || results.isEmpty) {
        return 'No search results found.';
      }

      final buffer = StringBuffer();
      for (final result in results) {
        buffer.writeln('Title: ${result['title']}');
        buffer.writeln('URL: ${result['url']}');
        buffer.writeln('Snippet: ${result['description']}');
        buffer.writeln('---');
      }

      return buffer.toString();
    } catch (e) {
      Log.e('Brave search failed', e);
      return 'Error performing web search: $e';
    }
  }
}

class WebSearchService {
  final SettingsStorage _settings;

  WebSearchService(this._settings);

  Future<String> search(String query) async {
    final providerType = _settings.getWebSearchProvider();
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

    return await provider.search(query);
  }
}

final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  final settings = ref.watch(settingsStorageProvider);
  return WebSearchService(settings);
});
