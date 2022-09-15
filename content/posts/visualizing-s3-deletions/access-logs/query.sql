CREATE TABLE parsed_access_logs AS
-- Access logs datetime fields need to be parsed
SELECT parse_datetime(
         requestdatetime, 'dd/MMM/yyyy:HH:mm:ss Z'
       ) as datetime,
       (case
          WHEN operation = 'S3.EXPIRE.OBJECT' then 'expire'
          ELSE 'delete'
        END) as operation,
       url_decode(key) as key -- And the keys need to be decoded
FROM "s3_access_logs"
-- Only select the operations we care about
WHERE operation IN ('S3.CREATE.DELETEMARKER', 'S3.EXPIRE.OBJECT')
  AND bucket = 'target-bucket'
