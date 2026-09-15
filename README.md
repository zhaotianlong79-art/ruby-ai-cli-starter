# ruby-ai-cli-starter

用 Ruby 做 AI 命令行工具的最小起点。一个能跑的示例，外加一份踩坑记录。

示例基于 [RubyLLM](https://github.com/crmne/ruby_llm) 调用 Claude，演示做 CLI 必需的三件事：

- **流式输出** —— 不做的话用户会盯着空白终端等十几秒
- **工具调用**（function calling）—— 让模型能读取本地状态
- **用量统计** —— 用来算成本

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
|---|---|---|
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
