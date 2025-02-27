# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

describe 'OpenTelemetry::Instrumentation::ActiveSupport::SpanSubscriber' do
  let(:instrumentation) { OpenTelemetry::Instrumentation::ActiveSupport::Instrumentation.instance }
  let(:tracer) { instrumentation.tracer }
  let(:exporter) { EXPORTER }
  let(:last_span) { exporter.finished_spans.last }
  let(:span_kind) { nil }
  let(:notification_name) { 'bar.foo' }
  let(:subscriber) do
    OpenTelemetry::Instrumentation::ActiveSupport::SpanSubscriber.new(
      pattern: notification_name,
      tracer: tracer,
      kind: span_kind
    )
  end

  class CrashingEndSubscriber
    def start(name, id, payload) end

    def finish(name, id, payload)
      raise 'boom'
    end
  end

  before do
    exporter.reset
    instrumentation.instance_variable_set(:@installed, false)
    instrumentation.install({})
  end

  it 'uses the provided tracer' do
    subscriber = OpenTelemetry::Instrumentation::ActiveSupport::SpanSubscriber.new(
      pattern: 'oh.hai',
      tracer: OpenTelemetry.tracer_provider.tracer('foo')
    )
    span, = subscriber.start('oh.hai', 'abc', {})
    _(span.instrumentation_library.name).must_equal('foo')
  end

  it 'finishes the passed span' do
    span, token = subscriber.start('hai', 'abc', {})
    subscriber.finish('hai', 'abc', __opentelemetry_span: span, __opentelemetry_ctx_token: token)

    # If it's in exporter.finished_spans ... it's finished.
    _(last_span).wont_be_nil
  end

  it 'sets attributes as expected' do
    span, token = subscriber.start('hai', 'abc', {})
    # We only use the finished attributes - could change in the future, perhaps.
    subscriber.finish(
      'hai',
      'abc',
      __opentelemetry_span: span,
      __opentelemetry_ctx_token: token,
      string: 'keys_are_present',
      numeric_is_fine: 1,
      boolean_okay?: true,
      symbols: :are_stringified,
      empty_array_is_okay: [],
      homogeneous_arrays_are_fine: %i[one two],
      heterogeneous_arrays_are_not: [1, false],
      exception: %w[Exception is_not_set_as_attribute],
      exception_object: Exception.new('is_not_set_as_attribute'),
      nil_values_are_rejected: nil,
      complex_values_are_rejected: { foo: :bar }
    )

    _(last_span).wont_be_nil
    _(last_span.kind).must_equal(:internal)
    _(last_span.attributes['string']).must_equal('keys_are_present')
    _(last_span.attributes['numeric_is_fine']).must_equal(1)
    _(last_span.attributes['boolean_okay?']).must_equal(true)
    _(last_span.attributes['symbols']).must_equal('are_stringified')
    _(last_span.attributes['empty_array_is_okay']).must_equal([])
    _(last_span.attributes['homogeneous_arrays_are_fine']).must_equal(%w[one two])
    _(last_span.attributes.key?('heterogeneous_arrays_are_not')).must_equal(false)
    _(last_span.attributes.key?('exception')).must_equal(false)
    _(last_span.attributes.key?('exception_object')).must_equal(false)
    _(last_span.attributes.key?('nil_values_are_rejected')).must_equal(false)
    _(last_span.attributes.key?('complex_values_are_rejected')).must_equal(false)
  end

  it 'logs an exception_object correctly' do
    span, token = subscriber.start('hai', 'abc', {})
    # We only use the finished attributes - could change in the future, perhaps.
    subscriber.finish(
      'hai',
      'abc',
      __opentelemetry_span: span,
      __opentelemetry_ctx_token: token,
      exception_object: Exception.new('boom')
    )

    status = last_span.status
    _(status.code).must_equal(OpenTelemetry::Trace::Status::ERROR)
    _(status.description).must_equal('Unhandled exception of type: Exception')

    event = last_span.events.first
    _(event.name).must_equal('exception')
    _(event.attributes['exception.message']).must_equal('boom')
  end

  describe 'instrumentation option - disallowed_notification_payload_keys' do
    let(:subscriber) do
      OpenTelemetry::Instrumentation::ActiveSupport::SpanSubscriber.new(
        pattern: notification_name,
        tracer: tracer,
        notification_payload_transform: nil,
        disallowed_notification_payload_keys: [:foo]
      )
    end

    before do
      instrumentation.instance_variable_set(:@installed, false)
      instrumentation.install({})
    end

    after do
      instrumentation.instance_variable_set(:@installed, false)
      instrumentation.install({})
    end

    it 'does not set disallowed attributes from notification payloads' do
      span, token = subscriber.start('hai', 'abc', {})
      subscriber.finish(
        'hai',
        'abc',
        __opentelemetry_span: span,
        __opentelemetry_ctx_token: token,
        foo: 'bar',
        baz: 'bat'
      )

      _(last_span).wont_be_nil
      _(last_span.attributes.key?('foo')).must_equal(false)
      _(last_span.attributes['baz']).must_equal('bat')
    end
  end

  describe 'instrumentation option - notification_payload_transform' do
    let(:transformer_proc) { ->(v) { v.transform_values { 'optimus prime' } } }
    let(:subscriber) do
      OpenTelemetry::Instrumentation::ActiveSupport::SpanSubscriber.new(
        pattern: notification_name,
        tracer: tracer,
        notification_payload_transform: transformer_proc,
        disallowed_notification_payload_keys: [:foo]
      )
    end

    before do
      instrumentation.instance_variable_set(:@installed, false)
      instrumentation.install({})
    end

    after do
      instrumentation.instance_variable_set(:@installed, false)
      instrumentation.install({})
    end

    it 'allows a callable to transform all payload values' do
      span, token = subscriber.start('hai', 'abc', {})
      subscriber.finish(
        'hai',
        'abc',
        __opentelemetry_span: span,
        __opentelemetry_ctx_token: token,
        thing: 'a semi truck'
      )

      _(last_span).wont_be_nil
      _(last_span.attributes['thing']).must_equal('optimus prime')
    end
  end

  describe 'given a span kind' do
    let(:span_kind) { :client }

    it 'sets the kind on the span' do
      span, token = subscriber.start('hai', 'abc', {})
      # We only use the finished attributes - could change in the future, perhaps.
      subscriber.finish(
        'hai',
        'abc',
        __opentelemetry_span: span,
        __opentelemetry_ctx_token: token
      )

      _(last_span).wont_be_nil
      _(last_span.kind).must_equal(:client)
    end
  end

  describe 'instrument' do
    after do
      ActiveSupport::Notifications.notifier.listeners_for(notification_name).each do |listener|
        ActiveSupport::Notifications.unsubscribe(listener)
      end
    end

    describe 'when subscribing to events directly' do
      it 'does not trace an event by default' do
        ActiveSupport::Notifications.subscribe(notification_name) do
          # pass
        end
        ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        _(last_span).must_be_nil
      end

      it 'traces an event when a span subscriber is used' do
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name)
        ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
        _(last_span.kind).must_equal(:internal)
      end

      describe 'when using a custom span name formatter' do
        describe 'when using the LEGACY_NAME_FORMATTER' do
          let(:span_name_formatter) { OpenTelemetry::Instrumentation::ActiveSupport::LEGACY_NAME_FORMATTER }
          it 'uses the user supplied formatter' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name, nil, nil, span_name_formatter: span_name_formatter)
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal('foo bar')
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a custom formatter' do
          let(:span_name_formatter) { ->(name) { "custom.#{name}" } }

          it 'uses the user supplied formatter' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name, nil, nil, span_name_formatter: span_name_formatter)
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal('custom.bar.foo')
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a invalid formatter' do
          it 'defaults to the notification name' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name, nil, nil, span_name_formatter: ->(_) {})
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal(notification_name)
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a unstable formatter' do
          it 'defaults to the notification name' do
            allow(OpenTelemetry).to receive(:handle_error).with(exception: RuntimeError, message: String)

            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name, nil, nil, span_name_formatter: ->(_) { raise 'boom' })
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal(notification_name)
            _(last_span.attributes['extra']).must_equal('context')
          end
        end
      end

      it 'finishes spans even when block subscribers blow up' do
        ActiveSupport::Notifications.subscribe(notification_name) { raise 'boom' }
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name)

        expect do
          ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        end.must_raise RuntimeError

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
      end

      it 'finishes spans even when complex subscribers blow up' do
        ActiveSupport::Notifications.subscribe(notification_name, CrashingEndSubscriber.new)
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name)

        expect do
          ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        end.must_raise RuntimeError

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
      end

      it 'supports unsubscribe' do
        obj = OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_name)
        ActiveSupport::Notifications.unsubscribe(obj)

        ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

        _(obj.class).must_equal(ActiveSupport::Notifications::Fanout::Subscribers::Evented)
        _(last_span).must_be_nil
      end

      it 'supports setting the span kind' do
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, 'bar.foo', nil, [], kind: :client)
        ActiveSupport::Notifications.instrument('bar.foo', extra: 'context')

        _(last_span).wont_be_nil
        _(last_span.name).must_equal('bar.foo')
        _(last_span.attributes['extra']).must_equal('context')
        _(last_span.kind).must_equal(:client)
      end
    end

    describe 'when subscribing to events matching a regular expression' do
      let(:notification_pattern) { /.*\.foo/ }

      it 'does not trace an event by default' do
        ActiveSupport::Notifications.subscribe(notification_pattern) do
          # pass
        end
        ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        _(last_span).must_be_nil
      end

      it 'traces an event when a span subscriber is used' do
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern)
        ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
        _(last_span.kind).must_equal(:internal)
      end

      describe 'when using a custom span name formatter' do
        describe 'when using the LEGACY_NAME_FORMATTER' do
          let(:span_name_formatter) { OpenTelemetry::Instrumentation::ActiveSupport::LEGACY_NAME_FORMATTER }
          it 'uses the user supplied formatter' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern, nil, nil, span_name_formatter: span_name_formatter)
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal('foo bar')
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a custom formatter' do
          let(:span_name_formatter) { ->(name) { "custom.#{name}" } }

          it 'uses the user supplied formatter' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern, nil, nil, span_name_formatter: span_name_formatter)
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal('custom.bar.foo')
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a invalid formatter' do
          it 'defaults to the notification name' do
            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern, nil, nil, span_name_formatter: ->(_) {})
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal(notification_name)
            _(last_span.attributes['extra']).must_equal('context')
          end
        end

        describe 'when using a unstable formatter' do
          it 'defaults to the notification name' do
            allow(OpenTelemetry).to receive(:handle_error).with(exception: RuntimeError, message: String)

            OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern, nil, nil, span_name_formatter: ->(_) { raise 'boom' })
            ActiveSupport::Notifications.instrument(notification_name, extra: 'context')

            _(last_span).wont_be_nil
            _(last_span.name).must_equal(notification_name)
            _(last_span.attributes['extra']).must_equal('context')
          end
        end
      end

      it 'finishes spans even when block subscribers blow up' do
        # This scenario cannot be exercised reliably on Active Support < 7.0 since the #finish method
        # will never be called by the notifier if another subscriber raises an error.
        #
        # See this PR for additional details: https://github.com/rails/rails/pull/43282
        skip 'Notifications will be broken in this scenario on Active Support < 7.0' if ActiveSupport.version < Gem::Version.new('7.0')

        ActiveSupport::Notifications.subscribe(notification_pattern) { raise 'boom' }
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern)

        expect do
          ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        end.must_raise RuntimeError

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
      end

      it 'finishes spans even when complex subscribers blow up' do
        # This scenario cannot be exercised reliably on Active Support < 7.0 since the #finish method
        # will never be called by the notifier if another subscriber raises an error.
        #
        # See this PR for additional details: https://github.com/rails/rails/pull/43282
        skip 'Notifications will be broken in this scenario on Active Support < 7.0' if ActiveSupport.version < Gem::Version.new('7.0')

        ActiveSupport::Notifications.subscribe(notification_pattern, CrashingEndSubscriber.new)
        OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, notification_pattern)

        expect do
          ActiveSupport::Notifications.instrument(notification_name, extra: 'context')
        end.must_raise RuntimeError

        _(last_span).wont_be_nil
        _(last_span.name).must_equal(notification_name)
        _(last_span.attributes['extra']).must_equal('context')
      end
    end
  end
end
