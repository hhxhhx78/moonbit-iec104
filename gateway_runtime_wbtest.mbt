///|
fn gateway_test_envelope(
  ingress : Int,
  egress : Int,
  common : CommonAddress,
  address : InformationAddress,
) -> GatewayEnvelope {
  let cause = CauseOfTransmission::new(Spontaneous).unwrap()
  let object = single_point_object(address, true).unwrap()
  let asdu = AsduEnvelope::new(MSpNa, false, cause, common, [object]).unwrap()
  GatewayEnvelope::new(ingress, egress, asdu, 100, trace_id="test").unwrap()
}

///|
test "gateway policy boundaries and type filters" {
  assert_true(GatewayAdmissionPolicy::new(0) is Err(_))
  assert_true(GatewayAdmissionPolicy::new(128) is Err(_))
  let policy = GatewayAdmissionPolicy::new(1, allow_monitoring=false).unwrap()
  let common = CommonAddress::new(1).unwrap()
  let envelope = gateway_test_envelope(
    1,
    2,
    common,
    InformationAddress::new(1).unwrap(),
  )
  assert_true(policy.evaluate(envelope.asdu()) is Err(_))
  let allow = GatewayAdmissionPolicy::new(1).unwrap()
  allow.deny_type(MSpNa)
  assert_true(allow.evaluate(envelope.asdu()) is Err(_))
  let allow_list = GatewayAdmissionPolicy::new(1).unwrap()
  allow_list.allow_type(MSpNa)
  assert_true(allow_list.evaluate(envelope.asdu()) is Ok(_))
}

///|
test "gateway route priority and duplicate protection" {
  let common = CommonAddress::new(1).unwrap()
  let low = GatewayRoute::new(
    10,
    1,
    2,
    common_address=common,
    type_ids=[MSpNa],
    priority=1,
  ).unwrap()
  let high = GatewayRoute::new(
    11,
    1,
    3,
    common_address=common,
    type_ids=[MSpNa],
    priority=8,
  ).unwrap()
  let table = GatewayRouteTable::new(capacity=2).unwrap()
  assert_true(table.add(low) is Ok(_))
  assert_true(table.add(high) is Ok(_))
  assert_true(table.add(high) is Err(_))
  match table.select(1, common, MSpNa) {
    None => fail("route selection returned no route")
    Some(route) => assert_eq(route.destination(), 3)
  }
  assert_true(table.set_enabled(11, false))
  match table.select(1, common, MSpNa) {
    None => fail("fallback route was not selected")
    Some(route) => assert_eq(route.destination(), 2)
  }
  assert_true(table.remove(10))
  assert_true(!table.remove(10))
}

///|
test "gateway lifecycle, forwarding and dead letters" {
  let common = CommonAddress::new(1).unwrap()
  let address = InformationAddress::new(1).unwrap()
  let runtime = GatewayRuntime::new(2).unwrap()
  assert_true(runtime.start() is Ok(_))
  assert_true(runtime.start() is Err(_))
  let route = GatewayRoute::new(1, 1, 2, common_address=common).unwrap()
  assert_true(runtime.add_route(route) is Ok(_))
  let envelope = gateway_test_envelope(1, 4, common, address)
  assert_true(runtime.enqueue(envelope) is Ok(_))
  assert_eq(runtime.queue_len(), 1)
  let dispatches = runtime.drain()
  assert_eq(dispatches.length(), 1)
  assert_true(dispatches[0].is_forwarded())
  assert_eq(runtime.outbound_len(), 1)
  assert_eq(runtime.poll_outbound().unwrap().egress(), 2)
  let unmatched = gateway_test_envelope(9, 4, common, address)
  assert_true(runtime.enqueue(unmatched) is Ok(_))
  ignore(runtime.drain())
  assert_eq(runtime.dead_letter_len(), 1)
  assert_eq(runtime.counters().forwarded(), 1)
  assert_eq(runtime.counters().dropped(), 1)
  assert_true(runtime.begin_drain() is Ok(_))
  assert_true(
    runtime.enqueue(gateway_test_envelope(1, 2, common, address)) is Err(_),
  )
  assert_true(runtime.stop() is Ok(_))
}

///|
test "gateway point store attachment and diagnostics" {
  let common = CommonAddress::new(3).unwrap()
  let address = InformationAddress::new(17).unwrap()
  let runtime = GatewayRuntime::new(4).unwrap()
  let binding = GatewayStoreBinding::new(common, history_limit=2).unwrap()
  assert_true(runtime.attach_store(binding) is Ok(_))
  assert_true(
    runtime.attach_store(GatewayStoreBinding::new(common).unwrap()) is Err(_),
  )
  let envelope = gateway_test_envelope(1, 2, common, address)
  assert_eq(runtime.ingest_to_store(envelope).unwrap(), 1)
  assert_eq(runtime.counters().stored(), 1)
  assert_eq(runtime.store_count(), 1)
  let snapshot = runtime.snapshot()
  assert_eq(snapshot.mode(), Stopped)
  assert_eq(snapshot.routes(), 0)
  assert_eq(snapshot.queue(), 0)
  assert_true(runtime.diagnostics().contains("mode=stopped"))
}
