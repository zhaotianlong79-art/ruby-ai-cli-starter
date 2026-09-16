# ruby-ai-cli-starter

用 Ruby 做 AI 命令行工具的最小起点。一个能跑的示例，外加一份踩坑记录。

> **⚠️ 关于 [`reference/`](reference/) 目录**
>
> 该目录下的代码**不是本仓库原创**，来自 [crmne/ruby_llm](https://github.com/crmne/ruby_llm)，
> 版权归 Copyright (c) 2025 Carmine Paolino，依 MIT 协议收录，仅作设计参考，不参与构建。
> 详见 [reference/README.md](reference/README.md) 和 [reference/LICENSE-ruby_llm](reference/LICENSE-ruby_llm)。
>
> 本仓库自身的原创代码只有 [`demo_claude.rb`](demo_claude.rb)。

示例基于 [RubyLLM](https://github.com/crmne/ruby_llm) 调用 Claude，演示做 CLI 必需的三件事：

- **流式输出** —— 不做的话用户会盯着空白终端等十几秒
- **工具调用**（function calling）—— 让模型能读取本地状态
- **用量统计** —— 用来算成本

## RubyLLM 是什么

[RubyLLM](https://github.com/crmne/ruby_llm) 是 Ruby 的 **LLM 统一接口层**。

它解决的问题是：今天用 Claude，明天要换 Gemini 省钱，后天要加个本地 Ollama 做隐私兜底。直接调各家 SDK 的话，每换一家就得重写业务代码——参数名、流式协议、工具调用格式、多模态传法，各家全都不一样。

RubyLLM 把这些差异吃掉，对外只暴露一套 API：

```ruby
RubyLLM.chat(model: "claude-opus-5").ask "..."
RubyLLM.chat(model: "gemini-3.7-flash").ask "..."   # 换个字符串，业务代码不动
```

覆盖 17 个 provider（OpenAI、Anthropic、Gemini、Bedrock、Vertex、xAI、Mistral、DeepSeek、Ollama 等），内置 1669 个模型的注册表——所以不配置任何东西就能查到 `claude-opus-5` 的上下文窗口是 1M、输出上限 128K。

功能面覆盖对话（文本/图片/音频/视频/PDF）、图像生成、embeddings、工具调用、结构化输出、流式，外加一套 Rails 集成（`acts_as_chat` 直接把对话存进 ActiveRecord）。

定位类似 Python 的 LangChain，但轻得多——运行时依赖只有 10 个 gem，没有那套沉重的抽象。

### 什么时候不该用它

**如果你只接 Claude，就别用。** 多 provider 抽象层在这种场景下是纯粹的额外开销，[官方 `anthropic` gem](https://github.com/anthropics/anthropic-sdk-ruby) 少一层间接、跟 API 同步更快。RubyLLM 的价值只在你**确实要切换或同时支持多家模型**时才体现出来。

## 快速开始

```bash
bundle config set --local path vendor/bundle   # 装到项目本地，不污染系统 Ruby
bundle install

cp .env.example .env                           # 填入你的 ANTHROPIC_API_KEY
bundle exec ruby demo_claude.rb "统计一下这个项目的代码量"
```

换模型：`MODEL=claude-haiku-4-5 bundle exec ruby demo_claude.rb "..."`

## 踩坑记录

搭这套环境时遇到的问题，按出现顺序。

### 1. `bundle install` 报权限错误

Homebrew 装的 Ruby，bundler 默认要往 `/opt/homebrew/lib/ruby/gems/` 写，会被拒。

```bash
bundle config set --local path vendor/bundle
```

装到项目本地。顺带的好处是项目之间依赖互不干扰，删目录即可彻底清理。

### 2. RubyLLM 2.0 的 API 和 1.x 不兼容

2.0 目前是预发布版（`2.0.0.rc3`），**Gemfile 里必须写死版本号**，否则 bundler 只会解析到 1.x：

```ruby
gem 'ruby_llm', '2.0.0.rc3'
```

2.0 里几个容易写错的地方（README 上看不出来，得翻源码）：

| 写法 | 正确 | 说明 |
| --- | --- | --- |
| `chat.with_tool(T)` | `chat.with_tools(T)` | 只有复数形式，单数不存在 |
| `param :x, desc: ...` | `parameter :x, description: ...` | 方法名和关键字名都不同 |
| 手写完整 schema | 通常不用写 | schema 会从 `execute` 的关键字参数自动推断，只在需要补描述或指定类型时才显式声明 |

### 3. 工具里做文件扫描要排除依赖目录

`Dir.glob("./**/*.rb")` 返回的路径带 `./` 前缀，写 `start_with?('vendor/')` 过滤不掉。结果是把 `vendor/bundle` 里上万行第三方代码也统计了进去。

```ruby
Dir.glob("#{subdir}/**/*.rb")
   .map { |f| f.delete_prefix('./') }
   .reject { |f| f.match?(%r{(\A|/)(vendor|node_modules|tmp|\.git)/}) }
```

### 4. 想跑 RubyLLM 自己的测试套件

克隆 [crmne/ruby_llm](https://github.com/crmne/ruby_llm) 后：

- dev 依赖里的 `mysql2` / `pg` 需要本地装 mysql-client 和 libpq，没有就编译失败。这两个只用于 CI 的多数据库矩阵，本地可以从 Gemfile 注释掉，sqlite3 已覆盖测试
- `upgrade_migration_spec` 会起子进程真跑 1.x → 2.0 迁移，需要额外装旧版：

```bash
GEM_HOME=vendor/legacy_gems gem install ruby_llm -v 1.16.0 --no-document

SKIP_COVERAGE=1 SKIP_LOCAL_PROVIDER_TESTS=1 \
RUBY_LLM_LEGACY_GEM_HOME="$PWD/vendor/legacy_gems" \
bundle exec rspec spec/ruby_llm
```

这样能跑到 **4270 examples / 1 failure**，剩的那个是 VertexAI 排序测试，需要 Google Cloud 凭证，跟 Claude 无关。

## 选型说明

这里用 RubyLLM 是为了一次看到流式、工具调用、多 provider 三样东西。如果你只接 Claude，[官方 `anthropic` gem](https://github.com/anthropics/anthropic-sdk-ruby) 少一层抽象、跟 API 同步更快，更适合上生产。

另外注意 RubyLLM 2.0 仍是 **rc 预发布版**，学习和原型没问题，上生产请用 1.x 稳定版或官方 SDK。

## 下一步

做 AI CLI 第一天就该把**离线测试**搭起来——不然每跑一次测试就烧一次 API 费用。
RubyLLM 的做法值得抄：用 [VCR](https://github.com/vcr/vcr) 录制 HTTP 交互成 cassette，之后全程离线回放（它录了 817 个）。

## License

MIT
