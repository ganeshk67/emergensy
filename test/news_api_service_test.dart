import 'package:emergensy/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads and maps articles from the public RSS converter', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.rss2json.com');
      expect(request.url.path, '/v1/api.json');
      expect(
        request.url.queryParameters['rss_url'],
        contains('news.google.com/rss/search'),
      );
      return http.Response(
        '{"status":"ok","items":[{"title":"Health update - Example News",'
        '"description":"Latest update","link":"https://example.com/article",'
        '"thumbnail":"https://example.com/image.jpg"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = NewsApiService(client: client);
    addTearDown(service.close);

    final articles = await service.fetchHealthNews();

    expect(articles, hasLength(1));
    expect(articles.single.title, 'Health update - Example News');
    expect(articles.single.source, 'Example News');
    expect(articles.single.url, 'https://example.com/article');
    expect(articles.single.imageUrl, 'https://example.com/image.jpg');
  });

  test('reports non-success responses from the public RSS converter', () async {
    final service = NewsApiService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    addTearDown(service.close);

    await expectLater(
      service.fetchHealthNews(),
      throwsA(
        isA<NewsRequestException>().having(
          (error) => error.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });
}
