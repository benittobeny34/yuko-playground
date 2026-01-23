SELECT
	val is json as is_json,
	val is json scalar as is_scalar,
	val is json array as is_array,
	val is json object as is_object,
	val is json object with unique keys as is_unique_object_keys
FROM
	(
		VALUES
			('123'),
			('"234"'),
			('abc'),
			('"ABC"'),
			('{"a": "b", "c": "d"}'),
			('{a: "b", "c": "d"}')
	) test (val);
