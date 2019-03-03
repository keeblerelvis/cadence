CREATE TABLE domains(
/* domain */
  id BINARY(16) PRIMARY KEY NOT NULL,
  name VARCHAR(255) UNIQUE NOT NULL,
  status INT NOT NULL,
  description VARCHAR(255) NOT NULL,
  owner_email VARCHAR(255) NOT NULL,
  data BLOB,
/* end domain */
  retention INT NOT NULL,
  emit_metric TINYINT(1) NOT NULL,
  archival_bucket VARCHAR(255) NOT NULL,
  archival_status TINYINT NOT NULL,
/* end domain_config */
  config_version BIGINT NOT NULL,
  notification_version BIGINT NOT NULL,
  failover_notification_version BIGINT NOT NULL,
  failover_version BIGINT NOT NULL,
  is_global_domain TINYINT(1) NOT NULL,
/* domain_replication_config */
  active_cluster_name VARCHAR(255) NOT NULL,
  clusters BLOB
/* end domain_replication_config */
);

CREATE TABLE domain_metadata (
  notification_version BIGINT NOT NULL
);

INSERT INTO domain_metadata (notification_version) VALUES (0);

CREATE TABLE shards (
	shard_id INT NOT NULL,
	owner VARCHAR(255) NOT NULL,
	range_id BIGINT NOT NULL,
	stolen_since_renew INT NOT NULL,
	updated_at DATETIME(6) NOT NULL,
	replication_ack_level BIGINT NOT NULL,
	transfer_ack_level BIGINT NOT NULL,
	timer_ack_level DATETIME(6) NOT NULL,
	cluster_transfer_ack_level BLOB NOT NULL,
	cluster_timer_ack_level BLOB NOT NULL,
	domain_notification_version BIGINT NOT NULL,
	PRIMARY KEY (shard_id)
);

CREATE TABLE transfer_tasks(
	shard_id INT NOT NULL,
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	task_id BIGINT NOT NULL,
	task_type TINYINT NOT NULL,
	target_domain_id BINARY(16) NOT NULL,
	target_workflow_id VARCHAR(255) NOT NULL,
	target_run_id BINARY(16),
	target_child_workflow_only TINYINT(1) NOT NULL,
	task_list VARCHAR(255) NOT NULL,
	schedule_id BIGINT NOT NULL,
	version BIGINT NOT NULL,
	visibility_timestamp DATETIME(6) NOT NULL,
	PRIMARY KEY (shard_id, task_id)
);

CREATE TABLE executions(
  shard_id INT NOT NULL,
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	--
	parent_domain_id BINARY(16), -- 1.
	parent_workflow_id VARCHAR(255), -- 2.
	parent_run_id BINARY(16), -- 3.
	initiated_id BIGINT, -- 4. these (parent-related fields) are nullable as their default values are not checked by tests
	completion_event_batch_id BIGINT, -- 5.
	completion_event BLOB, -- 6.
	completion_event_encoding VARCHAR(16),
	task_list VARCHAR(255) NOT NULL,
	workflow_type_name VARCHAR(255) NOT NULL,
	workflow_timeout_seconds INT UNSIGNED NOT NULL,
	decision_task_timeout_minutes INT UNSIGNED NOT NULL,
	execution_context BLOB, -- nullable because test passes in a null blob.
	state INT NOT NULL,
	close_status INT NOT NULL,
	-- replication_state members
  start_version BIGINT NOT NULL,
  current_version BIGINT NOT NULL,
  last_write_version BIGINT NOT NULL,
  last_write_event_id BIGINT,
  last_replication_info BLOB,
  -- replication_state members end
	last_first_event_id BIGINT NOT NULL,
	next_event_id BIGINT NOT NULL, -- very important! for conditional updates of all the dependent tables.
	last_processed_event BIGINT NOT NULL,
	start_time DATETIME(6) NOT NULL,
	last_updated_time DATETIME(6) NOT NULL,
	create_request_id VARCHAR(64) NOT NULL,
	decision_version BIGINT NOT NULL, -- 1.
	decision_schedule_id BIGINT NOT NULL, -- 2.
	decision_started_id BIGINT NOT NULL, -- 3. cannot be nullable as common.EmptyEventID is checked
	decision_request_id VARCHAR(64), -- not checked
	decision_timeout INT NOT NULL, -- 4.
	decision_attempt BIGINT NOT NULL, -- 5.
	decision_timestamp BIGINT NOT NULL, -- 6.
	cancel_requested TINYINT(1), -- a.
	cancel_request_id VARCHAR(64), -- b. default values not checked
	sticky_task_list VARCHAR(255) NOT NULL, -- 1. defualt value is checked
	sticky_schedule_to_start_timeout INT NOT NULL, -- 2.
	client_library_version VARCHAR(255) NOT NULL, -- 3.
	client_feature_version VARCHAR(255) NOT NULL, -- 4.
	client_impl VARCHAR(255) NOT NULL, -- 5.
	signal_count INT NOT NULL,
	history_size BIGINT NOT NULL,
	cron_schedule VARCHAR(255),
	has_retry_policy BOOLEAN NOT NULL,-- If there is a retry policy
	attempt INT NOT NULL,
  initial_interval INT NOT NULL,    -- initial retry interval, in seconds
  backoff_coefficient DOUBLE NOT NULL,
  maximum_interval INT NOT NULL,    -- max retry interval in seconds
  maximum_attempts INT NOT NULL,    -- max number of attempts including initial non-retry attempt
  expiration_seconds INT NOT NULL,
  expiration_time DATETIME(6) NOT NULL, -- retry expiration time
  non_retryable_errors BLOB,
	PRIMARY KEY (shard_id, domain_id, workflow_id, run_id)
);

CREATE TABLE current_executions(
  shard_id INT NOT NULL,
  domain_id BINARY(16) NOT NULL,
  workflow_id VARCHAR(255) NOT NULL,
  --
  run_id BINARY(16) NOT NULL,
  create_request_id VARCHAR(64) NOT NULL,
	state INT NOT NULL,
	close_status INT NOT NULL,
  start_version BIGINT NOT NULL,
	last_write_version BIGINT NOT NULL,
  PRIMARY KEY (shard_id, domain_id, workflow_id)
);

CREATE TABLE buffered_events (
  id BIGINT AUTO_INCREMENT NOT NULL,
  shard_id INT NOT NULL,
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	--
	data MEDIUMBLOB NOT NULL,
	data_encoding VARCHAR(16) NOT NULL,
	PRIMARY KEY (id)
);

CREATE INDEX buffered_events_by_events_ids ON buffered_events(shard_id, domain_id, workflow_id, run_id);

CREATE TABLE tasks (
  shard_id INT NOT NULL DEFAULT 0,
  domain_id BINARY(16) NOT NULL,
  workflow_id VARCHAR(255) NOT NULL,
  run_id BINARY(16) NOT NULL,
  schedule_id BIGINT NOT NULL,
  task_list_name VARCHAR(255) NOT NULL,
  task_type TINYINT NOT NULL, -- {Activity, Decision}
  task_id BIGINT NOT NULL,
  expiry_ts DATETIME(6) NOT NULL,
  PRIMARY KEY (shard_id, domain_id, task_list_name, task_type, task_id)
);

CREATE TABLE task_lists (
	domain_id BINARY(16) NOT NULL,
	range_id BIGINT NOT NULL,
	name VARCHAR(255) NOT NULL,
	task_type TINYINT NOT NULL, -- {Activity, Decision}
	ack_level BIGINT NOT NULL DEFAULT 0,
	kind TINYINT NOT NULL, -- {Normal, Sticky}
	expiry_ts DATETIME(6) NOT NULL,
	PRIMARY KEY (domain_id, name, task_type)
);

CREATE TABLE replication_tasks (
  shard_id INT NOT NULL,
	task_id BIGINT NOT NULL,
	--
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	task_type TINYINT NOT NULL,
	first_event_id BIGINT NOT NULL,
	next_event_id BIGINT NOT NULL,
	version BIGINT NOT NULL,
  last_replication_info BLOB NOT NULL,
	scheduled_id BIGINT NOT NULL,
	PRIMARY KEY (shard_id, task_id)
);

CREATE TABLE timer_tasks (
	shard_id INT NOT NULL,
	visibility_timestamp DATETIME(6) NOT NULL,
	task_id BIGINT NOT NULL,
	--
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	task_type TINYINT NOT NULL,
	timeout_type TINYINT NOT NULL,
	event_id BIGINT NOT NULL,
	schedule_attempt BIGINT NOT NULL,
	version BIGINT NOT NULL,
	PRIMARY KEY (shard_id, visibility_timestamp, task_id)
);

CREATE TABLE events (
	domain_id      BINARY(16) NOT NULL,
	workflow_id    VARCHAR(255) NOT NULL,
	run_id         BINARY(16) NOT NULL,
	first_event_id BIGINT NOT NULL,
	batch_version  BIGINT,
	range_id       BIGINT NOT NULL,
	tx_id          BIGINT NOT NULL,
	data MEDIUMBLOB NOT NULL,
	data_encoding  VARCHAR(16) NOT NULL,
	PRIMARY KEY (domain_id, workflow_id, run_id, first_event_id)
);

CREATE TABLE activity_info_maps (
-- each row corresponds to one key of one map<string, ActivityInfo>
	shard_id INT NOT NULL,
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
  run_id BINARY(16) NOT NULL,
	schedule_id BIGINT NOT NULL, -- the key.
-- fields of activity_info type follow
version                     BIGINT NOT NULL,
scheduled_event_batch_id    BIGINT NOT NULL,
scheduled_event             BLOB,
scheduled_event_encoding    VARCHAR(16),
scheduled_time              DATETIME(6) NOT NULL,
started_id                  BIGINT NOT NULL,
started_event               BLOB,
started_event_encoding      VARCHAR(16),
started_time                DATETIME(6) NOT NULL,
activity_id                 VARCHAR(255) NOT NULL,
request_id                  VARCHAR(64) NOT NULL,
details                     BLOB,
schedule_to_start_timeout   INT NOT NULL,
schedule_to_close_timeout   INT NOT NULL,
start_to_close_timeout      INT NOT NULL,
heartbeat_timeout           INT NOT NULL,
cancel_requested            TINYINT(1),
cancel_request_id           BIGINT NOT NULL,
last_heartbeat_updated_time DATETIME(6) NOT NULL,
timer_task_status           INT NOT NULL,
attempt                     INT NOT NULL,
task_list                   VARCHAR(255) NOT NULL,
started_identity            VARCHAR(255) NOT NULL,
has_retry_policy            BOOLEAN NOT NULL,
init_interval               INT NOT NULL,
backoff_coefficient         DOUBLE NOT NULL,
max_interval                INT NOT NULL,
expiration_time             DATETIME(6) NOT NULL,
max_attempts                INT NOT NULL,
non_retriable_errors        BLOB, -- this was a list<text>. The use pattern is to replace, no modifications.
	PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, schedule_id)
);

CREATE TABLE timer_info_maps (
shard_id INT NOT NULL,
domain_id BINARY(16) NOT NULL,
workflow_id VARCHAR(255) NOT NULL,
run_id BINARY(16) NOT NULL,
timer_id VARCHAR(255) NOT NULL, -- what string type should this be?
--
  version BIGINT NOT NULL,
  started_id BIGINT NOT NULL,
  expiry_time DATETIME(6) NOT NULL,
  task_id BIGINT NOT NULL,
  PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, timer_id)
);

CREATE TABLE child_execution_info_maps (
  shard_id INT NOT NULL,
domain_id BINARY(16) NOT NULL,
workflow_id VARCHAR(255) NOT NULL,
run_id BINARY(16) NOT NULL,
initiated_id BIGINT NOT NULL,
--
version BIGINT NOT NULL,
initiated_event_batch_id  BIGINT NOT NULL,
initiated_event BLOB,
initiated_event_encoding  VARCHAR(16),
started_id BIGINT NOT NULL,
started_workflow_id VARCHAR(255) NOT NULL,
started_run_id BINARY(16),
started_event BLOB,
started_event_encoding  VARCHAR(16),
create_request_id VARCHAR(64),
domain_name VARCHAR(255) NOT NULL,
workflow_type_name VARCHAR(255) NOT NULL,
PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, initiated_id)
);

CREATE TABLE request_cancel_info_maps (
shard_id INT NOT NULL,
domain_id BINARY(16) NOT NULL,
workflow_id VARCHAR(255) NOT NULL,
run_id BINARY(16) NOT NULL,
initiated_id BIGINT NOT NULL,
--
version BIGINT NOT NULL,
cancel_request_id VARCHAR(64) NOT NULL, -- a uuid
PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, initiated_id)
);


CREATE TABLE signal_info_maps (
shard_id INT NOT NULL,
domain_id BINARY(16) NOT NULL,
workflow_id VARCHAR(255) NOT NULL,
run_id BINARY(16) NOT NULL,
initiated_id BIGINT NOT NULL,
--
version BIGINT NOT NULL,
signal_request_id VARCHAR(64) NOT NULL, -- uuid
signal_name VARCHAR(255) NOT NULL,
input BLOB,
control BLOB,
PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, initiated_id)
);

CREATE TABLE buffered_replication_task_maps (
 shard_id INT NOT NULL,
domain_id BINARY(16) NOT NULL,
workflow_id VARCHAR(255) NOT NULL,
run_id BINARY(16) NOT NULL,
first_event_id BIGINT NOT NULL,
--
version BIGINT NOT NULL,
next_event_id BIGINT NOT NULL,
history MEDIUMBLOB,
history_encoding VARCHAR(16) NOT NULL,
new_run_history BLOB,
new_run_history_encoding VARCHAR(16) NOT NULL DEFAULT 'json',
PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, first_event_id)
);

CREATE TABLE signals_requested_sets (
	shard_id INT NOT NULL,
	domain_id BINARY(16) NOT NULL,
	workflow_id VARCHAR(255) NOT NULL,
	run_id BINARY(16) NOT NULL,
	signal_id VARCHAR(64) NOT NULL,
	--
	PRIMARY KEY (shard_id, domain_id, workflow_id, run_id, signal_id)
);
