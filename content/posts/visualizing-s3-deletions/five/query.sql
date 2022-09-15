CREATE TABLE bucket_s3_events_grouped WITH (format = 'JSON') AS
-- Truncate the event time into a group. Can be hours, minutes, etc.
select date_trunc('hour', datetime)    as bucket,
       operation,
       i.segment,
       -- Create an array of all *numbered* items within the segment
       -- that the given operation was applied to, within the "bucket".
       array_agg(i.index order by i.index) as indexes
from parsed_access_logs l
       INNER JOIN key_prefix_segment i ON (i.key = i.key)
group by 1, 2, 3
order by 1, 2, 3
