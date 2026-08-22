///|
test "station database capacity and lifecycle boundaries" {
  let common = CommonAddress::new(1).unwrap()
  let database = StationDatabase::new(event_limit=3).unwrap()
  let config = StationConfig::new(
    common,
    "edge-station",
    point_capacity=1,
    history_limit=2,
    heartbeat_interval=5,
  ).unwrap()
  assert_true(database.register(config, 0) is Ok(_))
  assert_true(
    database.write(
      common,
      single_point_object(InformationAddress::new(1).unwrap(), true).unwrap(),
      1,
      source="rtu",
    )
    is Ok(_),
  )
  assert_true(
    database.write(
      common,
      single_point_object(InformationAddress::new(2).unwrap(), false).unwrap(),
      2,
    )
    is Err(_),
  )
  assert_eq(database.read(common, PointFilter::all()).unwrap().length(), 1)
  assert_true(database.miss_heartbeat(common, 7) is Ok(_))
  assert_eq(database.event_count(), 2)
  assert_true(
    database.write(
      CommonAddress::new(2).unwrap(),
      single_point_object(InformationAddress::new(3).unwrap(), true).unwrap(),
      3,
    )
    is Err(_),
  )
}

///|
test "station transaction revision conflict is rejected" {
  let database = StationDatabase::new().unwrap()
  let first = CommonAddress::new(10).unwrap()
  let second = CommonAddress::new(11).unwrap()
  let transaction = DatabaseTransaction::new(database.revision(), 2)
  ignore(
    transaction
    .add_station(StationConfig::new(first, "first").unwrap())
    .unwrap(),
  )
  assert_true(
    database.register(StationConfig::new(second, "second").unwrap(), 1) is Ok(_),
  )
  assert_true(database.commit(transaction) is Err(_))
  assert_eq(database.station_count(), 1)
}

///|
test "service registry blocks dependencies and reconciles them" {
  let registry = ServiceRegistry::new(event_limit=12).unwrap()
  let database = ServiceDefinition::new(
    "station-db",
    StationDatabaseService,
    critical=true,
  ).unwrap()
  let dependency = ServiceDependency::new("station-db").unwrap()
  let api = ServiceDefinition::new(
    "api",
    ApiService,
    dependencies=[dependency],
    heartbeat_interval=2,
  ).unwrap()
  ignore(registry.register(api, 0).unwrap())
  ignore(registry.register(database, 0).unwrap())
  assert_true(registry.start("api", 1) is Err(_))
  assert_eq(registry.blocked().length(), 1)
  assert_true(registry.start("station-db", 2) is Ok(_))
  let started = registry.reconcile(3)
  assert_eq(started, ["api"])
  assert_eq(registry.running(), ["api", "station-db"])
  assert_true(registry.startup_order() is Ok(_))
  assert_true(registry.mark_stale(6).contains("api"))
  assert_eq(registry.health_summary().degraded(), 0)
  assert_eq(registry.health_summary().running(), 2)
}

///|
test "service leases fence competing workers" {
  let registry = ServiceRegistry::new().unwrap()
  let definition = ServiceDefinition::new("transport", TransportService).unwrap()
  ignore(registry.register(definition, 0).unwrap())
  let first = registry.acquire_lease("transport", "worker-a", 10, 5).unwrap()
  assert_eq(first.owner(), "worker-a")
  assert_true(registry.acquire_lease("transport", "worker-b", 11, 5) is Err(_))
  assert_true(registry.renew_lease("transport", "worker-a", 12, 5) is Ok(_))
  assert_true(registry.release_lease("transport", "worker-a", 13) is Ok(_))
  assert_eq(registry.expire_leases(20).length(), 0)
}

///|
test "quality policy distinguishes accepted stale and invalid points" {
  let common = CommonAddress::new(3).unwrap()
  let engine = QualityPolicyEngine::new(history_limit=4).unwrap()
  let strict = QualityGateRule::new(
    2,
    "strict",
    max_age=2,
    future_skew=1,
    require_source=true,
    reject_stale=true,
  ).unwrap()
  assert_true(engine.register_rule(strict) is Ok(_))
  assert_true(engine.assign(common, 2) is Ok(_))
  let address = InformationAddress::new(9).unwrap()
  let current = PointRecord::new(
    normalized_object(address, 10).unwrap(),
    10,
    source="rtu",
  )
  let accepted = engine.evaluate_point(common, current, 11)
  assert_eq(accepted.disposition(), QualityAccepted)
  let stale = PointRecord::new(
    normalized_object(address, 10).unwrap(),
    1,
    source="rtu",
  )
  let stale_result = engine.evaluate_point(common, stale, 11)
  assert_eq(stale_result.disposition(), QualityRejected)
  assert_true(stale_result.has_finding(QualityStaleValue))
  let missing_source = PointRecord::new(
    normalized_object(address, 10).unwrap(),
    11,
    source="",
  )
  let degraded = engine.evaluate_point(common, missing_source, 11)
  assert_eq(degraded.disposition(), QualityDegraded)
  assert_eq(engine.metrics().evaluated(), 3)
  assert_eq(engine.history_len(), 3)
  assert_true(engine.snapshot().configuration_issues().is_empty())
}

///|
test "quality policy configuration and bounded history" {
  let common = CommonAddress::new(4).unwrap()
  let engine = QualityPolicyEngine::new(history_limit=2).unwrap()
  assert_true(QualityGateRule::new(0, "invalid") is Err(_))
  assert_true(engine.assign(common, 99) is Err(_))
  let address = InformationAddress::new(1).unwrap()
  let object = normalized_object(address, 1).unwrap()
  ignore(engine.evaluate_object(common, object, "gateway", 1, 1))
  ignore(engine.evaluate_object(common, object, "gateway", 2, 2))
  ignore(engine.evaluate_object(common, object, "gateway", 3, 3))
  assert_eq(engine.history_len(), 2)
  assert_eq(engine.rejected_history().length(), 0)
  assert_eq(engine.filter_accepted(engine.history()).length(), 2)
  assert_eq(engine.metrics().acceptance_percent(), 100)
}

///|
test "validation profile catches station and point store limits" {
  let common = CommonAddress::new(5).unwrap()
  let profile = ValidationProfile::new(max_points=1, max_history=1).unwrap()
  let config = StationConfig::new(
    common,
    "validator",
    point_capacity=1,
    history_limit=1,
  ).unwrap()
  let station_report = validate_station_config(config, profile)
  assert_true(station_report.valid())
  let store = PointStore::new(common, history_limit=1).unwrap()
  ignore(
    store
    .upsert(
      normalized_object(InformationAddress::new(1).unwrap(), 1).unwrap(),
      1,
    )
    .unwrap(),
  )
  let report = validate_point_store(store, profile)
  assert_true(report.valid())
  assert_eq(report.checked(), 1)
  assert_true(
    !validate_transport_frame_admission(b"", ResourceLimits::default()).valid(),
  )
}

///|
test "application vectors remain deterministic after expansion" {
  let report = run_conformance_suite(standard_conformance_vectors())
  assert_eq(report.total(), report.passed() + report.failed())
  assert_eq(report.failed(), 0)
  assert_true(report.total() >= 4)
  let supported = supported_type_catalog()
  assert_true(supported.length() > 0)
  assert_true(supported[0].supported())
}
