CREATE TABLE keys_with_prefix AS
-- Select the set of distinct prefixes
WITH distinct_prefixes AS (select distinct prefix
                           FROM keys_with_prefix),
-- Sort these prefixes and select the
     prefix_count AS (select distinct_prefixes.prefix                                  as prefix,
                             row_number() OVER (ORDER BY distinct_prefixes.prefix ASC) as segment
                      FROM distinct_prefixes)
SELECT o.key,
       prefix_count.segment,
       row_number() OVER (
         PARTITION BY o.prefix ORDER BY o.prefix ASC, o.key ASC
         ) as index
FROM keys_with_prefix o
       INNER JOIN prefix_count ON (o.prefix = prefix_count.prefix)
