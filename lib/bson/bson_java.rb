# encoding: UTF-8
# A thin wrapper for the native Java extensions
module BSON
  class BSON_JAVA
    def self.deserialize(buf)
      if buf.is_a? String
        buf = ByteBuffer.new(buf.unpack("C*")) if buf
      end
      dec = Java::OrgBson::BSONDecoder.new
      callback = Java::OrgJbson::RubyBSONCallback.new(JRuby.runtime)
      dec.decode(buf.to_a.to_java(Java::byte), callback)
      callback.get
    end

    def self.serialize(obj, check=false, move=false)
      enc = Java::OrgJbson::RubyBSONEncoder.new(JRuby.runtime)
      enc.encode(obj)
    end
  end
end
