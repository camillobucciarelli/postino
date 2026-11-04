/// A JSON array of objects (null: none) typed for use under strict-casts and avoid_dynamic_calls.
List<Map<String, dynamic>> jsonObjects(Object? json) =>
    (json as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
