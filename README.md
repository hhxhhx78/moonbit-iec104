# moonbit-iec104

MoonBit 电力远动 IEC 60870-5-104 协议库，面向变电站、配电自动化和协议仿真场景。

## 能力

- APCI I/S/U 帧编解码、15-bit 发送/接收序号和发送窗口
- STARTDT、STOPDT、TESTFR 链路状态机
- 单点、双点、归一化值、短浮点值和 32-bit 位串基础模型
- 总召唤事务、遥信遥测点表、内存型 outstation 和事件日志
- 可替换传输边界、跨平台 MoonBit CI 和 7 个核心回归测试

## 使用

需要 MoonBit 0.10.3 或更新版本：

```bash
moon check --deny-warn --target all
moon test --deny-warn
moon run cmd/main
```

完整设计范围、目录说明、来源声明和后续路线见 [README.mbt.md](README.mbt.md)。项目采用 Apache-2.0 License。

## 仓库

- GitHub: https://github.com/qlc676788/moonbit-iec104
- Gitlink: https://gitlink.org.cn/qlcddjb/moonbit-iec104
