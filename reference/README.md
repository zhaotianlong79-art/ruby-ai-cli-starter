# reference/ —— 第三方参考代码

> **这个目录下的代码不是本仓库原创。**
>
> 全部来自 [crmne/ruby_llm](https://github.com/crmne/ruby_llm)，
> 版权归 **Copyright (c) 2025 Carmine Paolino**，
> 依 **MIT** 协议使用（全文见 [LICENSE-ruby_llm](LICENSE-ruby_llm)）。
>
> 收录于 commit [`08d273f`](https://github.com/crmne/ruby_llm/tree/08d273f1f01171774a588694bba3e6eafa5a7340)（ruby_llm 2.0.0.rc3，2026-09-14）。
> 每个文件正文与上游**逐字节一致**，仅在头部添加了出处说明。

这些文件**不参与构建，也不被本项目的代码引用**，纯粹作为设计参考留存。

## 为什么只收录这 10 个文件

ruby_llm 的 `lib/` 有 37768 行，但其中 `protocols/`（13197 行，133 个文件）和
`providers/`（6066 行，103 个文件）是 17 家 provider 的协议适配，属于体力活，没有设计价值。
`active_record/`（1880 行）是 Rails 集成，做 CLI 用不到。

真正值得读的只有下面这 2222 行，占全部的约 6%。

## 各文件看点

### `lib/tool.rb` (446 行) —— 最值得读的一个

工具（function calling）的 DSL 设计。最漂亮的一点是**参数 schema 从 `execute` 的关键字参数自动推断**：必需关键字变成必需参数，可选关键字变成可选参数，只有需要补描述或指定类型时才用 `::parameter` 显式声明。

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  def execute(latitude:, longitude:)   # schema 自动推断，无需手写 JSON Schema
    ...
  end
end
```

看 `inherited` 钩子怎么处理子类继承配置（哪些 ivar 该 dup、哪些该 copy），这是 Ruby 元编程写 DSL 的典型手法。

### `lib/configuration.rb` (331 行)

`option` 宏 + `register_provider_options`：核心配置项集中声明，provider 专属配置项由各 provider 类自己注册进来。做插件化 CLI 时这个模式很好用。

注意一个细节：赋空字符串会存成 `nil`，这样未设置的环境变量表现得就像从未配置过。

### `lib/transport/` (364 行，3 个文件)

Faraday 中间件栈的组织方式：

- `connection.rb` —— 连接构建、中间件顺序、超时重试配置
- `error_middleware.rb` —— 把各家五花八门的 HTTP 错误统一映射成本地异常类型
- `usage_middleware.rb` —— 只有 28 行，从响应里抽取 token 用量，是中间件做横切关注点的极简范例

### `lib/protocol/` (444 行，2 个文件)

- `streaming.rb` —— SSE 流式响应处理，包括流中途报错怎么办（`raise_stream_error`）
- `stream_accumulator.rb` —— 把流式碎片累积成完整消息，工具调用的参数是逐字符流过来的，拼接逻辑都在这

### `lib/tokens.rb` + `lib/cost.rb` (486 行)

token 计数和成本换算的值对象设计。`cost.rb` 处理了缓存读写、批处理折扣等各种计价情况。

### `spec/vcr_configuration.rb` (163 行) —— 做 AI 工具必看

**用 VCR 把 HTTP 交互录成 cassette，之后全程离线回放。** ruby_llm 录了 817 个，
所以它 4270 个测试能在 4 分半内跑完且不花一分钱 API 费用。

重点看它怎么过滤敏感信息——各家的 key 在 header 里的位置都不一样，录制前必须全部脱敏，
否则 API key 会被写进 cassette 提交上去。

## 完整代码

这里只是节选。完整项目见 https://github.com/crmne/ruby_llm
