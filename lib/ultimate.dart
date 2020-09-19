import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sound/model.dart';

/** 
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

/*

var client = http.Client();
  var req = http.Request("GET", Uri.parse(url));
  req.followRedirects = true;
  req.maxRedirects = 10;
  req.persistentConnection = true;
  req.headers['User-Agent'] = 'python-requests/2.9.1';
  req.headers['Connection'] = "keep-alive";
  req.headers['Accept-Encoding'] = "gzip, deflate";
    http.StreamedResponse r = await req.send();
    if (r.statusCode == 200) {
    final data = await r.stream.bytesToString();
*/

Future<String> readResponse(HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen((data) {
    contents.write(data);
  }, onDone: () => completer.complete(contents.toString()));
  return completer.future;
}

Future<Note> parseUltimateGuitar(String url) async {
  var client = HttpClient();
  client.userAgent = "python-requests/2.9.1";

  url = "http://192.168.178.50:90";
  HttpClientRequest req = await client.getUrl(Uri.parse(url));
  req.headers.set("Connection", "keep-alive");
  req.headers.set("Accept-Encoding", "gzip, deflate");
  req.headers.set("content-length", "-1");
  //req.contentLength = -1;
  req.persistentConnection = true;
  req.followRedirects = true;
  HttpClientResponse r = await req.close();

  if (r.statusCode == 200) {
    final data = await readResponse(r);
    print("data: $data");

    Document doc = parse(data);
    Element e = doc.getElementsByClassName("js-store")[0];
    print(e.innerHtml);
    final json = jsonDecode(e.text);
    print(json);
    return null;
  } else {
    return null;
  }
}

main() async {
  await parseUltimateGuitar(
      "https://tabs.ultimate-guitar.com/tab/passenger/new-until-its-old-chords-2621235");
}

**/
