RSpec.describe JSONTaggedLogging::TaggedBroadcastLogger do
  let(:device1) { StringIO.new }
  let(:device2) { StringIO.new }
  let(:device3) { StringIO.new }

  let(:logger1) { ActiveSupport::TaggedLogging.new(Logger.new(device1)) }
  let(:logger2) { ActiveSupport::TaggedLogging.new(Logger.new(device2)) }
  let(:logger3) { Logger.new(device3).tap { |l|
    l.formatter =  proc { |severity, datetime, progname, msg| msg + "\n" }
  } }

  let(:logger) {
    described_class.new(logger1, logger2, logger3)
  }

  it 'is a ActiveSupport::BroadcastLogger' do
    expect(logger).to be_a(ActiveSupport::BroadcastLogger)
  end

  it 'broadcasts to all loggers' do
    logger.info('hello')

    expect(device1.string).to eq("hello\n")
    expect(device2.string).to eq("hello\n")
    expect(device3.string).to eq("hello\n")
  end

  describe '#tagged' do
    describe 'with a block' do
      it 'returns the broadcast logger' do
        expect(logger.tagged('foo', 'bar') { }).to be(logger)
      end

      it 'yields the broadcast logger' do
        expect { |b| logger.tagged('foo', 'bar', &b) }.to yield_with_args(logger)
      end

      it 'broadcasts to the tagged loggers' do
        logger.tagged('foo', 'bar') do
          logger.info 'hello'
        end

        expect(device1.string).to eq("[foo] [bar] hello\n")
        expect(device2.string).to eq("[foo] [bar] hello\n")
        expect(device3.string).to eq("hello\n")
      end
    end

    describe 'without a block' do
      subject { logger.tagged('foo', 'bar') }

      it 'returns a new TaggedBroadcastLogger' do
        expect(subject).to be_a(described_class)
        expect(subject).not_to be(logger)
      end

      it 'broadcasts to the same devices, with duplicates of the loggers' do
        expect(subject.broadcasts).not_to eq(logger.broadcasts)

        subject.info "hello"
        expect(device1.string).to eq("[foo] [bar] hello\n")
        expect(device2.string).to eq("[foo] [bar] hello\n")
        expect(device3.string).to eq("hello\n")
      end
    end
  end
end