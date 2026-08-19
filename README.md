# moonbit-iec104

面向 SCADA、变电站自动化、配电网关和协议仿真的 IEC 60870-5-104 MoonBit 协议核心。库层不绑定 TCP 或操作系统 I/O，可复用于 native、wasm-gc 等目标。

## 项目定位

提供可验证的 APCI/ASDU 编解码、链路状态、序号窗口、信息对象、点表和确定性仿真能力，方便接入真实传输层、网关和测试工具。

## 核心能力

- I/S/U 帧、STARTDT/STOPDT/TESTFR、序号窗口和流式 APDU 解析
- IEC 104 Type ID、VSQ、传送原因、公共地址和信息体地址
- 单点、双点、步位、归一化/标度/短浮点/累计量和命令对象
- CP24Time2a、CP56Time2a、质量描述符与带时标 ASDU
- 点表历史、召唤事务、命令策略、重放保护、指标和健康报告

## 快速开始

```bash
moon update
moon check --deny-warn --target all
moon build --target wasm-gc
moon test --deny-warn --target wasm-gc
moon run cmd/main
```

## CLI

```bash
moon run cmd/main -- --help
moon run cmd/main -- --benchmark
```

默认命令编码一个示例 I 帧；`--benchmark` 运行固定的 10,000 帧工作负载并输出可复核的摘要。实测数据见 [BENCHMARKS.md](BENCHMARKS.md)。

## 架构

帧与链路位于 `frame_types.mbt`、`codec.mbt` 和 `state_machine.mbt`；应用层模型位于 `protocol_domain.mbt`、`quality.mbt`、`time_tags.mbt`、`application_objects.mbt` 和 `extended_asdu.mbt`；服务、点表、诊断、资源保护和仿真分别位于对应的 `*_services.mbt`、`point_store.mbt`、`diagnostics_metrics.mbt`、`security_limits.mbt` 和 `simulation.mbt`。

## 基准

基准输入和校验和是确定的，宿主机耗时在命令外部测量。完整环境、重复次数和结果见 [BENCHMARKS.md](BENCHMARKS.md)。

## 测试

边界测试覆盖地址、日期、质量位、签名值、ASDU 截断/尾随字节、序号回绕、流式输入、点表历史、事务回滚、CRC、资源限制和确定性工作负载。

```bash
moon check --deny-warn --target all
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target native
```

## CI

`.github/workflows/check.yml` 覆盖 Ubuntu、macOS 和 Windows，安装 MoonBit stable 并执行格式、接口、检查、构建和测试门禁。

## 许可证

Apache License 2.0，详见 [LICENSE](LICENSE)。
