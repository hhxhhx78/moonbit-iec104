///|
test "file transfer preserves ordering and checksum boundaries" {
  let station = CommonAddress::new(6).unwrap()
  let identity = FileIdentity::new(station, "event.log", 7).unwrap()
  let data = Bytes::from_array([b'a', b'b', b'c', b'd', b'e'])
  let file = StoredFile::new(identity, data, 1)
  let segments = split_file_segments(file, 2).unwrap()
  assert_eq(segments.length(), 3)
  let session = FileTransferSession::new(
    1,
    identity,
    UploadFile,
    file.size(),
    2,
    Some(file.checksum()),
    1,
  ).unwrap()
  assert_true(session.append(segments[0], 2) is Err(_))
  assert_true(session.activate(2) is Ok(_))
  assert_true(session.append(segments[1], 3) is Err(_))
  assert_true(session.append(segments[0], 3) is Ok(_))
  assert_true(session.append(segments[1], 4) is Ok(_))
  assert_true(session.append(segments[2], 5) is Ok(_))
  assert_eq(session.state(), FileCompleted)
  assert_eq(session.data(), data)
  assert_true(split_file_segments(file, 0) is Err(_))
}

///|
test "telemetry deadband rate and alarm workflow" {
  let station = CommonAddress::new(7).unwrap()
  let address = InformationAddress::new(20).unwrap()
  let pipeline = TelemetryPipeline::new(alarm_limit=2).unwrap()
  let deadband = DeadbandRule::new(
    absolute=Float::from_int(2),
    relative_percent=Float::from_int(100),
    minimum_interval=10,
  ).unwrap()
  pipeline.set_deadband(address, deadband)
  let rate = RateRule::new(Float::from_int(5), minimum_interval=1).unwrap()
  pipeline.set_rate_rule(address, rate)
  let alarm = AlarmRule::new(
    "high-temperature",
    CriticalAlarm,
    high=Float::from_int(50),
    hysteresis=Float::from_int(2),
  ).unwrap()
  pipeline.set_alarm_rules(address, [alarm])
  let first = pipeline
    .ingest(
      station,
      short_float_object(address, Float::from_int(10)).unwrap(),
      1,
      source="sensor",
    )
    .unwrap()
  assert_true(first.accepted())
  let second = pipeline
    .ingest(
      station,
      short_float_object(address, Float::from_int(11)).unwrap(),
      2,
      source="sensor",
    )
    .unwrap()
  assert_true(!second.changed())
  let third = pipeline
    .ingest(
      station,
      short_float_object(address, Float::from_int(60)).unwrap(),
      12,
      source="sensor",
    )
    .unwrap()
  assert_true(third.changed())
  assert_eq(third.alarms().length(), 1)
  assert_eq(pipeline.alarm_history().length(), 1)
  assert_eq(pipeline.sample_count(), 1)
}

///|
test "command scheduler applies idempotency deadlines and confirmation" {
  let scheduler = CommandScheduler::new(audit_limit=4).unwrap()
  let station = CommonAddress::new(8).unwrap()
  let address = InformationAddress::new(30).unwrap()
  let command = single_command_object(address, true, 1).unwrap()
  let request = scheduler
    .submit(
      station,
      command,
      HighPriority,
      0,
      20,
      "breaker-open",
      policy=RetryPolicy::new(max_attempts=2).unwrap(),
    )
    .unwrap()
  assert_eq(request.attempts(), 0)
  assert_true(
    scheduler.submit(station, command, LowPriority, 1, 20, "breaker-open")
    is Err(_),
  )
  let dispatch = scheduler.dispatch(CommandPolicy::allow_all(), 1).unwrap()
  assert_true(dispatch is Some(_))
  assert_eq(scheduler.get(request.ticket()).unwrap().attempts(), 1)
  assert_true(scheduler.confirm(request.ticket(), 2, false) is Ok(_))
  assert_eq(scheduler.get(request.ticket()).unwrap().lifecycle(), QueuedCommand)
  assert_true(scheduler.dispatch(CommandPolicy::deny_all(), 4) is Err(_))
  assert_true(scheduler.cancel(request.ticket(), 5) is Ok(_))
  assert_eq(scheduler.audits().length(), 4)
}

///|
test "telemetry subscriptions reject inverted ranges" {
  let first = InformationAddress::new(50).unwrap()
  let last = InformationAddress::new(40).unwrap()
  assert_true(
    TelemetrySubscription::new(1, first_address=first, last_address=last)
    is Err(_),
  )
  let subscription = TelemetrySubscription::new(
    2,
    minimum_state=DegradedTelemetry,
    include_unchanged=true,
  ).unwrap()
  let pipeline = TelemetryPipeline::new().unwrap()
  assert_true(pipeline.subscribe(subscription) is Ok(_))
  assert_true(pipeline.unsubscribe(2))
  assert_true(!pipeline.unsubscribe(2))
}
