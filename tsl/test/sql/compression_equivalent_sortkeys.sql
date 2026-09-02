-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

-- Test queries over compressed data with sort keys equivalent to other columns

\set PREFIX 'EXPLAIN (buffers off, costs off, timing off, summary off)'

-- Set up compressed hypertable with 3 segmentby and 3 orderby keys
CREATE TABLE test1 (
    s1 integer NOT NULL,
    s2 integer NOT NULL,
    s3 smallint NOT NULL,
    o1 integer NOT NULL,
    o2 integer NOT NULL,
    o3 smallint NOT NULL,
    v integer);

SELECT FROM create_hypertable('test1', 'o1');
ALTER TABLE test1 SET (timescaledb.compress, timescaledb.compress_segmentby='s1, s2, s3', timescaledb.compress_orderby = 'o1, o2 DESC, o3');

INSERT INTO test1  SELECT t1, t2, t3, t1, t4, t3 % 2, t3*10
FROM generate_series(1, 2) t1, generate_series(1, 5) t2, generate_series(1, 10) t3, generate_series(1, 4) t4;

SELECT count(compress_chunk(ch)) FROM show_chunks('test1') ch;

SET enable_seqscan = 0;
SET enable_bitmapscan = 0;
SET max_parallel_workers_per_gather = 0;

-- Equivalent segmentby columns, use compressed sort
set timescaledb.debug_require_batch_sorted_merge to 'forbid';

:PREFIX SELECT * FROM test1 WHERE s1 = s3 ORDER BY s3, s2;
:PREFIX SELECT * FROM test1 WHERE s1 = s3 ORDER BY s1, s2, o1;
:PREFIX SELECT * FROM test1 WHERE s1 = s2 ORDER BY s2, s3;
:PREFIX SELECT * FROM test1 WHERE s1 = s2 AND s2 = s3 ORDER BY s3;

-- Use batch sorted merge
set timescaledb.debug_require_batch_sorted_merge to 'force';

:PREFIX SELECT * FROM test1 WHERE s1 = s3 ORDER BY s3, o1;
:PREFIX SELECT * FROM test1 WHERE s1 = s2 ORDER BY s2, o1;

-- Equivalent segmentby and orderby columns, use compressed sort
set timescaledb.debug_require_batch_sorted_merge to 'forbid';

:PREFIX SELECT * FROM test1 WHERE s1 = o1 AND s2 = 1 AND s3 = 1 ORDER BY s1, o1;
:PREFIX SELECT * FROM test1 WHERE s1 = o1 AND s2 = 1 AND s3 = 1 ORDER BY s1, o1 DESC, o2;
:PREFIX SELECT * FROM test1 WHERE s3 = o1 AND s2 = 1 AND s1 = s3 ORDER BY s1, s2, s3, o2;
:PREFIX SELECT * FROM test1 WHERE s1 = o1 AND s2 = s3 ORDER BY s1, s3, o2 DESC;

-- Use batch sorted merge
set timescaledb.debug_require_batch_sorted_merge to 'force';

:PREFIX SELECT * FROM test1 WHERE s1 = o1 ORDER BY s1, o2 DESC, o3;
:PREFIX SELECT * FROM test1 WHERE s3 = o1 AND s1 = s3 ORDER BY s3, o2, o3 DESC;

-- Equivalent orderby columns, use compressed sort
set timescaledb.debug_require_batch_sorted_merge to 'forbid';

:PREFIX SELECT * FROM test1 WHERE o1 = o2 ORDER BY s1, s2, s3, o1, o3;
:PREFIX SELECT * FROM test1 WHERE o1 = o2 ORDER BY s1, s2, s3, o1, o2, o3;
:PREFIX SELECT * FROM test1 WHERE o1 = o3 ORDER BY s1, s2, s3, o1, o2 DESC, o3;
:PREFIX SELECT * FROM test1 WHERE o1 = o3 AND o1 = o2 ORDER BY s1, s2, s3, o3 DESC;

-- Use batch sorted merge over seqscan
set timescaledb.debug_require_batch_sorted_merge to 'force';
set enable_seqscan=1;
:PREFIX SELECT * FROM test1 WHERE o1 = o2 ORDER BY o1, o3;
:PREFIX SELECT * FROM test1 WHERE o1 = o3 ORDER BY o1, o2 DESC;
set enable_seqscan=0;

-- Equivalent to other columns: can use compressed sort
set timescaledb.debug_require_batch_sorted_merge to 'forbid';

:PREFIX SELECT * FROM test1 WHERE s1 = v ORDER BY s1, v;
:PREFIX SELECT * FROM test1 WHERE o1 = v AND s1 = 1 AND s2 = s3 ORDER BY s2, o1, v;
:PREFIX SELECT * FROM test1 WHERE o1 = v AND s1 = 1 AND s2 = s3 ORDER BY s2 DESC, o1 DESC, v DESC;

reset timescaledb.debug_require_batch_sorted_merge;

drop table test1 cascade;

RESET enable_seqscan;
RESET enable_bitmapscan;
RESET max_parallel_workers_per_gather;
