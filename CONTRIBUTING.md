# Contributing

本项目优先接受围绕 IEC 104 核心行为的可复现改动。提交前请使用 MoonBit 0.10.3 或更新版本，并运行：

```bash
moon fmt --check
moon check --deny-warn --target all
moon test --deny-warn
moon info
git diff --exit-code
```

协议字段或状态机行为变更应同时增加回归测试，并在 README 或变更记录中说明兼容性影响。传输层适配必须保持核心包可在无网络环境下测试。
