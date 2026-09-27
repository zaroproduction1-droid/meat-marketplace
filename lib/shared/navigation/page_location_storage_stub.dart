final _values = <String, String>{};
String? readLocation(String key) => _values[key];
void writeLocation(String key, String value) {
  _values[key] = value;
}

void clearLocation(String key) {
  _values.remove(key);
}
