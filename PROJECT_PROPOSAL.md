# MoonBit IEC 104 项目申报书

项目名称：MoonBit IEC 104
项目标识：moonbit-iec104
GitHub：https://github.com/qlc676788/moonbit-iec104
Gitlink：https://gitlink.org.cn/qlcddjb/moonbit-iec104

## 项目简介
本项目面向变电站与配电自动化场景，使用 MoonBit 实现 IEC 60870-5-104 协议核心，降低电力远动系统在 MoonBit 生态中的接入门槛。

## 项目方向与场景
项目属于工业通信基础设施与 MoonBit 生态库方向，服务于变电站监控、配电自动化、实验室仿真、协议网关和教学验证。

## 核心功能
1. 实现 I 帧、S 帧、U 帧、发送接收序号和发送窗口。
2. 实现 STARTDT、STOPDT、TESTFR 链路状态转换。
3. 提供单点、双点、归一化值、短浮点值和位串基础 ASDU 模型。
4. 提供总召唤事务跟踪、遥信遥测点表和内存型 outstation 仿真。
5. 提供协议校验、事件日志、可替换传输边界和跨平台 CI。

## 实施计划
第一阶段完成 APCI/ASDU 编解码、链路状态机、测试和可运行示例；第二阶段补充带 IOA 的完整信息对象、CP56Time2a 时标和总召唤响应；第三阶段增加基于 MoonBit async 的 TCP 适配器、TLS 边界和 IEC 61850 映射示例。

## 独立贡献与来源
项目为原创 MoonBit 实现，不直接移植或复制已有 IEC 104 开源代码。经 Mooncakes 关键词检索，未发现成熟的 IEC 104 MoonBit 包；通用 TCP/异步能力将通过 moonbitlang/async 的公开 API 接入，并在依赖引入时记录版本与许可证。

## 预期交付
交付 Apache-2.0 开源仓库、可复现 README、跨平台 CI、核心路径测试、可运行 CLI 示例和可发布至 Mooncakes 的稳定包。
