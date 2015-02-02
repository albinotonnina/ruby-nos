require "securerandom"
require "initializable"

module RubyNos
  class Message

    include Initializable
    attr_accessor :version, :from, :type, :to, :hops, :reliable, :data, :sig, :rnd, :sequence_number

    def serialize_message
    {
        v:  @version  || "v1.0",
        ty: @type,
        fr: @from,
        to: @to,
        hp: @hops     || 1,
        sg: @sig,
        sq: (@sequence_number || generate_new_sequence_number)
    }
    end

    def serialize_with_optional_fields options

      message = serialize_message

      options_hashes = options[:options].map do |option|
        {option => optional_fields.fetch(option)}
      end

      options_hashes.each do |hashie|
        message.merge!(hashie)
      end

      message
    end

    private

    def optional_fields
      {
          rx: @reliable || false,
          dt: @data
      }
    end

    def generate_new_sequence_number
      Time.now.to_i
    end
  end
end