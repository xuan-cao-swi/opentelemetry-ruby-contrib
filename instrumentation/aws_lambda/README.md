# OpenTelemetry AWS-Lambda Instrumentation

The OpenTelemetry `aws-lambda` gem is a community maintained instrumentation for [aws-sdk-lambda][aws-sdk-lambda].

## How do I get started?

Install the gem using:

```
gem install opentelemetry-instrumentation-aws_lambda
```

Or, if you use [bundler][bundler-home], include `opentelemetry-instrumentation-aws_lambda` in your `Gemfile`.

## Usage

From the Lambda Layer side, create the wrapper. More information can be found at https://github.com/open-telemetry/opentelemetry-lambda
```ruby
require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/aws_lambda'
OpenTelemetry::SDK.configure do |c|
  c.service_name = '<YOUR_SERVICE_NAME>'
  c.use 'OpenTelemetry::Instrumentation::AwsLambda'
end

def otel_wrapper(event:, context:)
  otel_wrapper = OpenTelemetry::Instrumentation::AwsLambda::Handler.new()
  otel_wrapper.call_wrapped(event: event, context: context)
end
```

## Example

To run the example:

1. `cd` to the examples directory and install gems
	* `cd example`
	* `bundle install`
2. Run the sample client script
	* `ruby trace_demonstration.rb`

This will run SNS publish command, printing OpenTelemetry traces to the console as it goes.

## How can I get involved?

The `opentelemetry-instrumentation-aws_lambda` gem source is [on github][repo-github], along with related gems including `opentelemetry-api` and `opentelemetry-sdk`.

The OpenTelemetry Ruby gems are maintained by the OpenTelemetry-Ruby special interest group (SIG). You can get involved by joining us in [GitHub Discussions][discussions-url] or attending our weekly meeting. See the [meeting calendar][community-meetings] for dates and times. For more information on this and other language SIGs, see the OpenTelemetry [community page][ruby-sig].

## License

Apache 2.0 license. See [LICENSE][license-github] for more information.

[aws-sdk-home]: https://github.com/aws/aws-sdk-ruby
[bundler-home]: https://bundler.io
[repo-github]: https://github.com/open-telemetry/opentelemetry-ruby
[license-github]: https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/main/LICENSE
[ruby-sig]: https://github.com/open-telemetry/community#ruby-sig
[community-meetings]: https://github.com/open-telemetry/community#community-meetings
[discussions-url]: https://github.com/open-telemetry/opentelemetry-ruby/discussions