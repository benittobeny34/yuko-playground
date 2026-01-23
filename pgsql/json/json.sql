-- Check Functions
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


-- Build Object
SELECT
    json_build_object('id', 123, 'name', 'Alice', 'active', TRUE, 'roles', ARRAY['admin', 'editor']);

-- Build JsonB Object
SELECT
    jsonb_build_object('id', 123, 'name', 'Alice', 'active', TRUE, 'roles', ARRAY['admin', 'editor']);


--- Row to json_in in single row
select json_agg(
json_build_object(
	'id', id,
	'email', email
)
) as users_json
from (
select id, email from users where email_verified_at is not null) u;
