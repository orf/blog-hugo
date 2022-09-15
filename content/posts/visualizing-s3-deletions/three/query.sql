CREATE TABLE key_prefix_segment AS
-- Select the set of distinct prefixes
WITH distinct_prefixes AS (
    select distinct prefix FROM keys_with_prefix
),
-- Sort the smaller number of prefixes and add the row_number to them.
-- This produces an ordered set of (prefix, incrementing counter)
prefix_count AS (
  select distinct_prefixes.prefix as prefix,
           row_number() OVER (ORDER BY distinct_prefixes.prefix ASC) as segment
     FROM distinct_prefixes
)
-- Select each key, the segment it belongs to and the row number within
-- the segment.
SELECT o.key,
       prefix_count.segment,
       row_number() OVER ( -- Use rank here in case of duplicate keys
         PARTITION BY o.prefix ORDER BY o.prefix ASC, o.key ASC
       ) as index
FROM keys_with_prefix o
INNER JOIN prefix_count ON (o.prefix = prefix_count.prefix);
