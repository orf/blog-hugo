CREATE TABLE keys_with_prefix AS
SELECT substr(key, 1, 5) as prefix, key
FROM s3_inventories o
WHERE is_delete_marker = false
  -- Make sure this is a snapshot taken before the lifecycle
  -- rules are applied
  AND dt = '2022-09-02-00-00'
  AND bucket = 'target-bucket';
