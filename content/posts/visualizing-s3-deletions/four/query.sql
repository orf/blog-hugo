CREATE TABLE ordered_segment_intervals WITH (format = 'JSON') AS
select segment, max(index) as index
from key_prefix_segment
group by 1
order by 1;
