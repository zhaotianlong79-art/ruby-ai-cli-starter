# frozen_string_literal: true

# RubyLLM + Claude 最小可跑示例：流式输出 + 工具调用 + 用量统计。
# 这三样是做 AI CLI 的地基。
#
#   cp .env.example .env && 填入 key
#   bundle exec ruby demo_claude.rb "你的问题"

require 'dotenv/load'
require 'ruby_llm'

abort '缺少 ANTHROPIC_API_KEY，请复制 .env.example 为 .env 并填入' unless ENV['ANTHROPIC_API_KEY']

RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY')
  # 走自建网关 / 代理时设置；不设则默认 https://api.anthropic.com
  base = ENV['ANTHROPIC_API_BASE']
  config.anthropic_api_base = base.chomp('/') if base && !base.strip.empty?
end

MODEL = ENV.fetch('MODEL', 'claude-opus-5')

# 走自建网关时模型名通常是网关的别名，不在 RubyLLM 的内置注册表里，
# 需要跳过注册表校验（此时必须显式指定 provider）。
CUSTOM_ENDPOINT = !ENV['ANTHROPIC_API_BASE'].to_s.strip.empty?

# 工具：参数 schema 会从 execute 的关键字参数自动推断，
# 只有需要补充描述或指定类型时才用 ::parameter 显式声明。
class ProjectStats < RubyLLM::Tool
  description '统计指定目录下 Ruby 源文件的数量和总行数'
  parameter :subdir, description: '要统计的目录，例如 lib', required: false

  IGNORED = %r{(\A|/)(vendor|node_modules|tmp|\.git)/}

  def execute(subdir: '.')
    files = Dir.glob("#{subdir}/**/*.rb")
                .map { |f| f.delete_prefix('./') }
                .reject { |f| f.match?(IGNORED) }
    { subdir: subdir,
      file_count: files.size,
      total_lines: files.sum { |f| File.foreach(f).count } }
  end
end

question = ARGV.join(' ')
question = '用 project_stats 统计当前目录的代码量，然后一句话点评规模。' if question.empty?

puts "模型: #{MODEL}"
puts "提问: #{question}"
puts '-' * 60

chat = if CUSTOM_ENDPOINT
         RubyLLM.chat(model: MODEL, provider: :anthropic, assume_model_exists: true)
       else
         RubyLLM.chat(model: MODEL)
       end
chat = chat.with_tools(ProjectStats)

# 流式输出——CLI 必须做，否则用户会盯着空白终端等十几秒
chat.ask(question) do |chunk|
  print chunk.content
  $stdout.flush
end
puts
puts '-' * 60

# 用量统计——做 CLI 时用来算成本。
#
# 两个坑：
#   1. 2.0 的 API 是 msg.tokens / msg.cost，1.x 的 msg.input_tokens 已移除
#   2. 一次工具调用会产生多轮请求，只看最后一条消息会漏掉前面几轮，必须聚合
totals = chat.messages.each_with_object(Hash.new(0)) do |m, acc|
  m.tokens.to_h.each { |k, v| acc[k] += v.to_i }
end
puts "输入 tokens: #{totals[:input_tokens]}   输出 tokens: #{totals[:output_tokens]}   " \
     "（共 #{chat.messages.size} 条消息）"

# cost 依赖内置注册表里的定价；走网关用自定义别名时取不到，会是 nil。
cost = chat.messages.sum { |m| m.cost.total.to_f }
puts cost.positive? ? "成本: $#{format('%.6f', cost)}" : '成本: 不可用（模型不在定价表中）'
