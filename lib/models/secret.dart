class Secret {
  final String ipifyKey;
  Secret({this.ipifyKey = ""});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(ipifyKey: jsonMap["ipify_key"]);
  }
}
