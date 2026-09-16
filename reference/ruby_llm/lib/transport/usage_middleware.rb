# frozen_string_literal: true
#
# ============================================================================
# 第三方代码 —— 非本仓库原创，仅作学习参考。
#
#   来源:   https://github.com/crmne/ruby_llm/blob/08d273f1f01171774a588694bba3e6eafa5a7340/lib/ruby_llm/transport/usage_middleware.rb
#   版本:   ruby_llm 2.0.0.rc3
#   版权:   Copyright (c) 2025 Carmine Paolino
#   协议:   MIT（全文见 reference/LICENSE-ruby_llm）
#
# 原文件未作任何修改，仅在文件头添加本段出处说明。
# ============================================================================


require 'faraday'

module RubyLLM
  module Transport # :nodoc:
    # Sits inside Faraday retry middleware so every transport attempt produces
    # one usage observation.
    class UsageMiddleware < Faraday::Middleware # :nodoc: all
      CONTEXT_KEY = :ruby_llm_usage_tracker

      def call(env)
        tracker = env.request.context&.[](CONTEXT_KEY)
        return @app.call(env) unless tracker

        entry = tracker.start
        begin
          @app.call(env)
        rescue StandardError => e
          tracker.fail_attempt(entry, e)
          raise
        end
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_usage: RubyLLM::Transport::UsageMiddleware)
