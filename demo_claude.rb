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
end

MODEL = ENV.fetch('MODEL', 'claude-opus-5')

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

chat = RubyLLM.chat(model: MODEL).with_tools(ProjectStats)

# 流式输出——CLI 必须做，否则用户会盯着空白终端等十几秒
chat.ask(question) do |chunk|
  print chunk.content
  $stdout.flush
end
puts
puts '-' * 60

# 用量统计——做 CLI 时用来算成本
last = chat.messages.last
if last.respond_to?(:input_tokens) && last.input_tokens
  puts "输入 tokens: #{last.input_tokens}   输出 tokens: #{last.output_tokens}"
end
