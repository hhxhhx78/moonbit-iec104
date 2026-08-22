# moonbit-iec104

一个面向 SCADA、变电站自动化、配电网关和协议仿真的 IEC 60870-5-104 协议核心。项目使用 MoonBit 编写，库层不绑定 TCP 实现或操作系统 I/O，便于嵌入网关、测试工具和确定性仿真器。

## 项目定位

本项目覆盖 IEC 104 链路层与常用应用层数据模型，重点放在可验证的二进制编解码、链路状态、序号窗口、信息对象和边界行为。网络传输由调用方接入，协议核心因此可以在 native、wasm-gc 等目标上复用。

## 核心能力

- APCI I/S/U 帧编解码、15 位发送/接收序号和序号窗口。
- STARTDT、STOPDT、TESTFR 链路状态机、定时器和流式 APDU 解析。
- IEC 104 常用 Type ID、VSQ、传送原因、公共地址和信息体地址模型。
- 单点、双点、步位、归一化值、标度值、短浮点值、累计量及命令对象。
- CP24Time2a、CP56Time2a、质量描述符、地址序列和带时标 ASDU 编解码。
- 点表、历史变更、总召唤/计数量召唤、读命令、时钟同步和命令策略。
- 站点数据库、事务提交、质量门控、历史归档、遥测死区和告警生命周期。
- 命令调度、文件分片传输、冗余切换、服务依赖编排和传输会话管理。
- 资源限制、重放保护、CRC、帧统计、健康报告、契约向量和确定性工作负载。

## 快速开始

需要 MoonBit stable 工具链。首次使用时执行：

```bash
moon update
moon fmt
moon check --deny-warn --target all
moon build --target wasm-gc
moon test --deny-warn --target wasm-gc
```

运行示例 CLI：

```bash
moon run cmd/main
moon run cmd/main -- --help
moon run cmd/main -- --benchmark
moon run cmd/main -- --application-benchmark
```

在库代码中构造并编码一个 I 帧：

```moonbit nocheck
///|
let payload = @hhxhhx78/moonbit-iec104.normalized_value_asdu(3, 1, 2300, 0)

///|
let apdu = @hhxhhx78/moonbit-iec104.encode_frame(
  @hhxhhx78/moonbit-iec104.information_frame(0, 0, payload),
)
```

## CLI

`cmd/main` 提供一个不依赖外部服务的可重复示例：默认编码一个归一化测量值 I 帧；`--benchmark` 执行固定的 10,000 帧编解码工作负载；`--application-benchmark` 执行站点、遥测、命令、文件和仿真服务工作负载；`--help` 显示用法。宿主机耗时由基准命令外部测量，避免把平台时钟引入协议核心。

## 架构

| 层次 | 主要文件 | 职责 |
| --- | --- | --- |
| 链路与帧 | `frame_types.mbt`, `codec.mbt`, `validation.mbt`, `state_machine.mbt` | APCI、ASDU 基础模型、校验和链路状态 |
| 应用数据 | `protocol_domain.mbt`, `quality.mbt`, `time_tags.mbt`, `application_objects.mbt`, `extended_asdu.mbt` | Type ID、地址、质量、时标和信息对象 |
| 服务与状态 | `transport_layer.mbt`, `station_database.mbt`, `telemetry_pipeline.mbt`, `command_scheduler.mbt`, `point_store.mbt` | 传输会话、站点数据库、遥测、命令和点表 |
| 运行时能力 | `file_transfer.mbt`, `historical_archive.mbt`, `redundancy_manager.mbt`, `service_registry.mbt`, `runtime_facade.mbt` | 文件、归档、冗余、依赖编排和统一运行时 |
| 工具与可靠性 | `wire_tools.mbt`, `security_limits.mbt`, `diagnostics_metrics.mbt`, `health_report.mbt` | 字节工具、资源保护、指标和诊断 |
| 仿真与契约 | `simulation.mbt`, `conformance_catalog.mbt`, `protocol_profiles.mbt`, `benchmark_api.mbt` | 确定性仿真、类型目录、能力协商和基准接口 |
| 示例 | `cmd/main` | 可运行的最小 CLI |

## 基准

基准工作负载由 `run_benchmark_workload` 定义，输入、输出字节数和 CRC 校验和均是确定的；宿主机实测结果记录在 [BENCHMARKS.md](BENCHMARKS.md)，包含执行环境、命令、重复次数和原始输出。重新测量：

```powershell
1..5 | ForEach-Object { Measure-Command { moon run cmd/main -- --benchmark } }
```

该数据用于比较同一环境下的回归趋势，不代表所有设备或网络部署的吞吐承诺。

## 测试

测试覆盖帧编解码、链路状态、Type ID 和地址边界、CP24/CP56 闰年与无效日期、质量位、签名测量值、ASDU 截断/尾随字节、序号回绕、流式输入、点表容量与事务冲突、服务依赖与租约、质量门控、文件分片顺序、遥测死区、命令幂等、资源限制、CRC 和确定性基准。推荐在本地分别运行：

```bash
moon check --deny-warn --target all
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target native
```

## CI

`.github/workflows/check.yml` 在 Ubuntu、macOS 和 Windows 上安装 MoonBit stable，执行版本检查、依赖更新、格式检查、接口文件一致性、所有目标检查、wasm-gc 构建和测试。CI 使用最小只读仓库权限；本地若缺少某个后端运行时，应以对应平台 CI 结果和明确的本地环境提示为准。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
