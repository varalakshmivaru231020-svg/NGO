final _data = <String, String>{};

String? readKv(String key) => _data[key];

void writeKv(String key, String data) => _data[key] = data;
