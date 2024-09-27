RSpec.describe JSONTaggedLogging do
  class TestFormatter
    def call(severity, timestamp, progname, msg)
      (Hash === msg ? msg.to_json : msg) + "\n"
    end
  end

  let(:logger) { Logger.new(log_device).tap { |l| l.formatter = formatter } }
  let(:log_device) { StringIO.new }
  let(:formatter) { TestFormatter.new }

  subject { JSONTaggedLogging.new(logger) }

  context 'for a practical tagged loging use case' do
    let(:formatter) { JSONTaggedLogging::JSONFormatter.new(level: false) }

    it 'logs appropriate JSON logs' do
      service = "ActiveJob"
      job_id = "a12345-b123-c123"
      dd_service = "rails"
      dd_trace_id= "2157598387333209718"
      dd_span_id = "3622846221405278982"
      dd_tag = "dd.service=#{dd_service} dd.trace_id=#{dd_trace_id} dd.span_id=#{dd_span_id}"
      account_id = 1454
      user_id = 43
      subject.tagged(service) do |logger|
        logger.tagged(job_id) do |logger|
          logger.tagged(dd_tag) do |logger|
            logger.tagged(client: { user_id: user_id, account_id: account_id }) do |logger|
              logger.info "Beginning remote request"
              logger.info({ message: "Got results", client: { account_id: 50, user_id: 50 }, count: 5, duration: 0.500})
            end
          end
        end
      end

      base_message = {
        tags: [service, job_id],
        dd: {
          service: dd_service,
          trace_id: dd_trace_id,
          span_id: dd_span_id
        },
        client: {
          user_id: user_id, account_id: account_id
        }
      }
      expect(log_device.string).to eq([
        base_message.merge(message: "Beginning remote request"),
        base_message.merge(message: "Got results", count: 5, duration: 0.5000).merge({ client: { user_id: 50, account_id: 50 }})
      ].map(&:to_json).join("\n") + "\n")
    end
  end

  describe '.new' do
    it { is_expected.to be_a ActiveSupport::TaggedLogging }
    it { is_expected.to respond_to(:tagged) }

    it 'logs JSON to the log device' do
      message = { foo: 'bar' }
      logger.info(message)
      expect(log_device.string).to eq(message.to_json + "\n")
    end

    it 'applies the special Formatter module' do
      expect(subject.formatter).to be_a JSONTaggedLogging::Formatter
    end
  end

  describe 'untagged' do
    it "doesn't modify plain messages" do
      subject.info('foo')
      expect(log_device.string).to eq('foo' + "\n")
    end

    it "doesn't modify JSON messages without tags" do
      subject.info({ foo: { bar: 'baz' } })
      expect(log_device.string).to eq({ foo: { bar: 'baz' } }.to_json + "\n")
    end
  end

  describe JSONTaggedLogging::JSONFormatter do
    subject { described_class.new(level: false, timestamp: false, severety: false, progname: false) }

    it 'extracts abc=def' do
      expect(subject.call(0, 0, "", { tags: ['abc=def'], message: "foo"}))
        .to eq({abc: 'def', message: "foo" }.to_json + "\n")
    end

    it 'extracts abc=def xyz=psa-_abc.$' do
      expect(subject.call(0, 0, "", { tags: ['abc=def xyz=psa-_abc.$'], message: "foo"}))
        .to eq({ abc: 'def', xyz: 'psa-_abc.$', message: 'foo' }.to_json + "\n")
    end

    it 'extracts dd.span_id=123 dd.trace_id=456 dd.service=test' do
      expect(subject.call(0, 0, "", { tags: ['dd.span_id=123 dd.trace_id=456 dd.service=test'], message: "foo"}))
        .to eq({dd: { span_id: '123', trace_id: '456', service: 'test'}, message: 'foo' }.to_json + "\n")
    end

    it 'deep merges tags and message' do
      expect(subject.call(0, 0, "", {
        tags: [
          {
            a: {
              b: {
                c: 'd'
              }
            }
          },
          b: {
            a: 'b'
          },
          c: 'a'
        ],
        b: {
          c: 'd'
        },
        a: { b: { c: 'e', d: 'f' }, c: { d: 'e' } },
        c: 'd'
      })).to eq({
        a: { b: { c: 'e', d: 'f' }, c: { d: 'e' } },
        b: { a: 'b', c: 'd' },
        c: 'd'
      }.to_json + "\n")
    end
  end

  describe '#tagged' do
    it 'yields and adds tags to the log only within block' do
      subject.tagged('foo') do
        subject.info('bar')
      end
      subject.info('baz')
      expect(log_device.string).to eq([
        { tags: ['foo'], message: 'bar'}.to_json,
        'baz'
      ].join("\n") + "\n")
    end

    it 'returns a new tagged logger when called' do
      new_logger = subject.tagged('foo').tagged('bar')
      expect(new_logger).to be_a ActiveSupport::TaggedLogging
      expect(new_logger).not_to eq(subject)
      expect(new_logger.formatter).not_to eq(subject.formatter)

      new_logger.info('baz')
      expect(log_device.string).to eq({ tags: ["foo", "bar"], message: 'baz'}.to_json + "\n")
    end
  end
end