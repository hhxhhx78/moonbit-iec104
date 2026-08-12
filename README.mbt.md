# moonbit-iec104

MoonBit 电力远动 IEC 60870-5-104 协议库。项目面向变电站、配电自动化和实验室仿真，提供不依赖具体网络框架的协议核心：APCI 帧编解码、I/S/U 帧、STARTDT/STOPDT/TESTFR、发送接收序号、ASDU 基础模型、遥信遥测值和可测试的主站/子站链路状态机。

## 为什么做这个项目

MoonBit 生态已有通用 TCP、异步 IO 和二进制数据能力，但截至 2026-08-10，在 Mooncakes 以 `IEC 104`、`IEC60870`、`IEC104` 和 `telecontrol` 检索没有发现成熟的 IEC 104 实现。本项目不重复通用 socket 封装，而是提供面向电力协议的类型安全核心，并让传输层可替换，方便接入 `moonbitlang/async`、串口网关或仿真器。

## 当前范围

- APCI：I 帧、S 帧、U 帧，15-bit 发送/接收序号与窗口控制。
- 链路：STARTDT、STOPDT、TESTFR 和状态转换。
- ASDU：单点、双点、归一化值、短浮点值、32-bit 位串的基础编码模型。
- 应用：总召唤/周期/突发传送可在上层基于 `AsduHeader.cause` 组合；内置 `Outstation` 便于测试数据源。
- 规划：补充带 IOA 的完整信息对象、时标 CP56Time2a、总召唤事务、TCP 适配器、TLS 边界和 IEC 61850 映射。

## 快速开始

需要 MoonBit 0.10.3 或更新版本。

```bash
moon check --deny-warn
moon test --deny-warn
moon run cmd/main
```

在代码中组合一个 I 帧：

```moonbit nocheck
///|
let payload = @hhxhhx78/moonbit-iec104.normalized_value_asdu(3, 1, 2300, 0)

///|
let apdu = @hhxhhx78/moonbit-iec104.encode_frame(
  @hhxhhx78/moonbit-iec104.information_frame(0, 0, payload),
)
```

## 目录

| 文件 | 用途 |
| --- | --- |
| `frame_types.mbt` | 帧、ASDU 和信息对象公共类型 |
| `codec.mbt` | APCI/ASDU 编解码 |
| `state_machine.mbt` | 可注入传输的链路状态机 |
| `model.mbt` | 遥信遥测构造器与内存型 outstation |
| `cmd/main` | 最小可运行示例 |

## 开源与来源

本项目为原创 MoonBit 实现，使用 Apache-2.0 License。没有复制第三方源码、测试数据或商业协议栈实现。协议字段依据 IEC 60870-5-104 公共标准术语设计；IEC 标准正文不是本仓库的再发布内容。MoonBit 的 TCP/异步适配计划使用 `moonbitlang/async` 的公开 API，并将在引入依赖时记录版本与许可证。

## CI 与质量门禁

`.github/workflows/check.yml` 运行格式检查、所有后端检查、信息文件一致性、双目标测试和覆盖率分析。提交前建议执行：

```bash
moon fmt --check
moon check --deny-warn --target all
moon info
git diff --exit-code
moon test --deny-warn
moon test --deny-warn --target native
```

项目仍处于协议核心开发阶段，API 会在补齐完整信息对象地址与时标后进入 0.2.x 稳定化。
