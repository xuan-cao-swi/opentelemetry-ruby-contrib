# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'bundler/setup'

# Define Langchain mock classes BEFORE bundler loads langchainrb
# This prevents the real classes from being loaded
module Langchain
  module LLM
    class Base
      def initialize(*args, **kwargs)
        @mock_response = nil
      end

      def chat(params = {}, &)
        raise @mock_response if @mock_response.is_a?(Exception)

        @mock_response
      end

      def complete(prompt:, **params)
        raise @mock_response if @mock_response.is_a?(Exception)

        @mock_response
      end

      def embed(text:, **params)
        raise @mock_response if @mock_response.is_a?(Exception)

        @mock_response
      end

      def summarize(text:)
        raise @mock_response if @mock_response.is_a?(Exception)

        @mock_response
      end

      def mock_response(response)
        @mock_response = response
      end

      def defaults
        {}
      end
    end

    class OpenAI < Base
      def defaults
        { chat_completion_model_name: 'gpt-4o-mini' }
      end
    end

    class Anthropic < Base
      def defaults
        { chat_completion_model_name: 'claude-3-haiku-20240307' }
      end
    end

    class GoogleGemini < Base
      def defaults
        { chat_completion_model_name: 'gemini-2.0-flash-lite' }
      end
    end

    class MistralAI < Base
      def defaults
        { chat_completion_model_name: 'mistral-large-latest', embeddings_model_name: 'mistral-embed' }
      end
    end
  end
end

Bundler.require(:default, :development, :test)

require 'minitest/autorun'
require 'webmock/minitest'

# global opentelemetry-sdk setup:
EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)

OpenTelemetry::SDK.configure do |c|
  c.error_handler = ->(exception:, message:) { raise(exception || message) }
  c.logger = Logger.new($stderr, level: ENV.fetch('OTEL_LOG_LEVEL', 'fatal').to_sym)
  c.add_span_processor span_processor
end

# Mock response classes
class MockResponse
  attr_reader :raw_response, :model, :prompt_tokens, :completion_tokens, :total_tokens, :embedding

  # rubocop:disable Metrics/ParameterLists
  def initialize(raw_response, model: nil, prompt_tokens: nil, completion_tokens: nil, total_tokens: nil, embedding: nil)
    @raw_response = raw_response
    @model = model
    @prompt_tokens = prompt_tokens
    @completion_tokens = completion_tokens
    @total_tokens = total_tokens
    @embedding = embedding
  end
  # rubocop:enable Metrics/ParameterLists
end
