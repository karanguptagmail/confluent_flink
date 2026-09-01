-- Flink SQL statement to aggregate orders by tumbling window
CREATE TABLE my_sink_topic AS
SELECT
  window_start,
  window_end,
  SUM(price) AS total_revenue,
  COUNT(*) AS cnt
FROM
  TABLE(TUMBLE(TABLE `examples`.`marketplace`.`orders`, DESCRIPTOR($rowtime), INTERVAL '1' MINUTE))
GROUP BY window_start, window_end;
