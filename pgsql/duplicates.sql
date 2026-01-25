-- find reviews duplicates
WITH
	duplicates_identified AS (
		SELECT
			row_number() OVER (
				PARTITION BY
					customer_uuid,
					product_uuid,
					trim(review_content),
					order_uuid,
					variation_uuid
				ORDER BY
					created_at ASC
			) > 1 AS is_duplicate,
			*
		FROM
			reviews
		WHERE
			type = 'review'
			AND review_parent_uuid IS NULL
			AND deleted_at IS NULL
			AND order_uuid IS NOT NULL
			AND status != 'trash'
	),
	duplicates AS (
		SELECT
			*
		FROM
			duplicates_identified
		WHERE
			is_duplicate IS TRUE
	)
SELECT
	*
FROM
	duplicates;

-- Time Difference
WITH review_timings AS (
  SELECT
    *,
    created_at - lag(created_at) OVER (
      PARTITION BY
        customer_uuid,
        product_uuid,
        order_uuid,
        trim(review_content)
      ORDER BY created_at
    ) AS time_since_last_review
  FROM reviews
  WHERE
    type = 'review'
    AND review_parent_uuid IS NULL
    AND deleted_at IS NULL
    AND order_uuid IS NOT NULL
    AND status != 'trash'
)
SELECT *
FROM review_timings
WHERE time_since_last_review < INTERVAL '1 day';
-- example query to cross check
WITH duplicates_identified AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY
        org_uuid,
        COALESCE(NULLIF(email, ''), NULLIF(phone_number, ''))
      ORDER BY created_at ASC
    ) AS rn
  FROM customers
  WHERE
    deleted_at IS NULL
)
SELECT *
FROM duplicates_identified
WHERE rn > 1;

