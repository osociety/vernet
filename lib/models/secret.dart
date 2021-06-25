import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method

class Secret {
  final String ipifyKey;
  Secret({this.ipifyKey = ""});

  static String _createKey() {
    String key = ")cz-Q8VSPZdfeft{q9_:p>@+N@M,y-L~";
    List<int> codeUnits = key.codeUnits;
    List<int> mCodes = [];
    for (int i = 0; i < codeUnits.length; i++) {
      mCodes.add((codeUnits[i] * 2) % 26);
    }
    return String.fromCharCodes(mCodes);
  }

  static String _createDigest() {
    var bytes = utf8.encode(_createKey());
    var digest = sha1.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    String ipifyKey = jsonMap["ipify_key"];
    String digest = _createDigest();
    final key = Key.fromUtf8(digest);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final decrypted = encrypter.decrypt64(ipifyKey, iv: iv);
    return new Secret(ipifyKey: decrypted);
  }
}
