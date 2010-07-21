# encoding: UTF-8
# A thin wrapper for the CBson class
module BSON
  module JMongo
    import com.mongodb.BasicDBList
    import com.mongodb.BasicDBObject
    import com.mongodb.Bytes
    import org.bson.BSONDecoder
    import org.bson.BSONEncoder

    import org.bson.BSONCallback
    import org.bson.types.BasicBSONList
    import org.bson.BasicBSONObject
    import org.bson.types.Binary
    import org.bson.types.ObjectId
    import org.bson.types.Symbol
    import org.bson.types.CodeWScope
  end
end

module BSON
  class BSON_JAVA
    def self.deserialize(buf)
      if buf.is_a? String
        buf = ByteBuffer.new(buf.unpack("C*")) if buf
      end
      dec = JMongo::BSONDecoder.new
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
