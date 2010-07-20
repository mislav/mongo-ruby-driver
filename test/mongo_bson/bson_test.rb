# encoding:utf-8
require 'test/test_helper'
require 'complex'
require 'bigdecimal'
require 'rational'

begin
  require 'active_support/core_ext'
  require 'active_support/hash_with_indifferent_access'
  Time.zone = "Pacific Time (US & Canada)"
  Zone = Time.zone.now
rescue LoadError
  warn 'Could not test BSON with HashWithIndifferentAccess.'
  module ActiveSupport
    class TimeWithZone
    end
  end
  Zone = ActiveSupport::TimeWithZone.new
end

class BSONTest < Test::Unit::TestCase
  include BSON

  def setup
    @encoder = BSON::BSON_CODER
  end

  # Assert that a document can be serialized and deserialized.
  def assert_bson(doc)
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_read_bson_io_document
    doc = {'doc' => 'hello, world'}
    bson = BSON.serialize(doc)
    io = StringIO.new
    io.write(bson.to_s)
    io.rewind
    assert_equal BSON.deserialize(bson), BSON.read_bson_document(io)
  end

  def test_serialize_returns_byte_buffer
    doc = {'doc' => 'hello, world'}
    bson = BSON.serialize(doc)
    assert bson.is_a?(ByteBuffer)
  end

  def test_deserialize_from_string
    doc = {'doc' => 'hello, world'}
    bson = BSON.serialize(doc)
    string = bson.to_s
    assert_equal doc, BSON.deserialize(string)
  end

  def test_deprecated_bson_module
    doc = {'doc' => 'hello, world'}
    bson = BSON.serialize(doc)
    assert_equal doc, BSON.deserialize(bson)
  end

  def test_string
    assert_bson({'doc' => 'hello, world'})
  end

  def test_valid_utf8_string
    assert_bson({'doc' => 'aé'})
  end

  def test_valid_utf8_key
    assert_bson({'aé' => 'hello'})
  end

  def test_document_length
    doc = {'name' => 'a' * 5 * 1024 * 1024}
    assert_raise InvalidDocument do
      assert @encoder.serialize(doc)
    end
  end

  # In 1.8 we test that other string encodings raise an exception.
  # In 1.9 we test that they get auto-converted.
  if RUBY_VERSION >= '1.9'
      def test_non_utf8_string
        bson = @encoder.serialize({'str' => 'aé'.encode('iso-8859-1')})
        result = @encoder.deserialize(bson)['str']
        assert_equal 'aé', result
        assert_equal 'UTF-8', result.encoding.name
      end

      def test_non_utf8_key
        bson = @encoder.serialize({'aé'.encode('iso-8859-1') => 'hello'})
        assert_equal 'hello', @encoder.deserialize(bson)['aé']
      end
  elsif RUBY_PLATFORM =~ /java/
    def test_invalid_string
      require 'iconv'
      string = Iconv.conv('iso-8859-1', 'utf-8', 'aé')
      doc = {'doc' => string}
      bson = @encoder.serialize(doc)
      assert_equal doc, @encoder.deserialize(bson)
    end
  else
    require 'iconv'
    def test_invalid_string
      string = Iconv.conv('iso-8859-1', 'utf-8', 'aé')
      doc = {'doc' => string}
      assert_raise InvalidStringEncoding do
        @encoder.serialize(doc)
      end
    end

    def test_invalid_key
      key = Iconv.conv('iso-8859-1', 'utf-8', 'aé')
      doc = {key => 'hello'}
      assert_raise InvalidStringEncoding do
        @encoder.serialize(doc)
      end
    end
  end

  if RUBY_VERSION >= '1.9'
    # Based on a test from sqlite3-ruby
    def test_default_internal_is_honored
      before_enc = Encoding.default_internal

      str = "壁に耳あり、障子に目あり"
      bson = @encoder.serialize("x" => str)

      Encoding.default_internal = 'EUC-JP'
      out = @encoder.deserialize(bson)["x"]

      assert_equal Encoding.default_internal, out.encoding
      assert_equal str.encode('EUC-JP'), out
      assert_equal str, out.encode(str.encoding)
    ensure
      Encoding.default_internal = before_enc
    end
  end


  def test_code
    doc = {'$where' => Code.new('this.a.b < this.b')}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_code_with_scope
    doc = {'$where' => Code.new('this.a.b < this.b', {'foo' => 1})}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_number
    doc = {'doc' => 41.99}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_int
    doc = {'doc' => 42}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)

    doc = {"doc" => -5600}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)

    doc = {"doc" => 2147483647}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)

    doc = {"doc" => -2147483648}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_ordered_hash
    doc = BSON::OrderedHash.new
    doc["b"] = 1
    doc["a"] = 2
    doc["c"] = 3
    doc["d"] = 4
    bson = @encoder.serialize(doc)
    puts
    p bson
    puts
    de = @encoder.deserialize(bson)
    p de
    p de.class
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_object
    doc = {'doc' => {'age' => 42, 'name' => 'Spongebob', 'shoe_size' => 9.5}}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_oid
    doc = {'doc' => ObjectID.new}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_array
    doc = {'doc' => [1, 2, 'a', 'b']}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_regex
    doc = {'doc' => /foobar/i}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    assert_equal doc, doc2

    r = doc2['doc']
    assert_kind_of Regexp, r

    doc = {'doc' => r}
    bson_doc = @encoder.serialize(doc)
    doc2 = nil
    doc2 = @encoder.deserialize(bson_doc)
    assert_equal doc, doc2
  end

  def test_boolean
    doc = {'doc' => true}
    bson = @encoder.serialize(doc)
    assert_equal doc, @encoder.deserialize(bson)
  end

  def test_date
    doc = {'date' => Time.now}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    # Mongo only stores up to the millisecond
    assert_in_delta doc['date'], doc2['date'], 0.001
  end

  def test_date_returns_as_utc
    doc = {'date' => Time.now}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    assert doc2['date'].utc?
  end

  def test_date_before_epoch
    begin
      doc = {'date' => Time.utc(1600)}
      bson = @encoder.serialize(doc)
      doc2 = @encoder.deserialize(bson)
      # Mongo only stores up to the millisecond
      assert_in_delta doc['date'], doc2['date'], 0.001
    rescue ArgumentError
      # some versions of Ruby won't let you create pre-epoch Time instances
      #
      # TODO figure out how that will work if somebady has saved data
      # w/ early dates already and is just querying for it.
    end
  end

  def assert_unsupported_date_class(invalid_date)
    doc = {'date' => invalid_date}
    begin
    bson = @encoder.serialize(doc)
    rescue => e
    ensure
      if !invalid_date.is_a? Time
        assert_equal InvalidDocument, e.class
        assert_match /UTC Time/, e.message
      end
    end
  end

  def test_symbol_as_key
    doc = {:foo => "bar"}
    bson = @encoder.serialize(doc)
    expected = {"foo" => "bar"}
    assert_equal expected, @encoder.deserialize(bson)
  end

  def test_exeption_on_using_unsupported_date_class
    assert_unsupported_date_class(Date.today)
    assert_unsupported_date_class(DateTime.now)
    assert_unsupported_date_class(Zone)
  end

  unless RUBY_PLATFORM =~ /java/
    # Not supporting dbref deserialization on jRuby.
    def test_dbref
      oid = ObjectID.new
      doc = {}
      doc['dbref'] = DBRef.new('namespace', oid)
      bson = @encoder.serialize(doc)
      doc2 = @encoder.deserialize(bson)
      assert_equal 'namespace', doc2['dbref'].namespace
      assert_equal oid, doc2['dbref'].object_id
    end
  end

  def test_symbol
    doc = {'sym' => :foo}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    assert_equal :foo, doc2['sym']
  end

  def test_binary
    bin = Binary.new
    'binstring'.each_byte { |b| bin.put(b) }

    doc = {'bin' => bin}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    bin2 = doc2['bin']
    assert_kind_of Binary, bin2
    assert_equal 'binstring', bin2.to_s
    assert_equal Binary::SUBTYPE_BYTES, bin2.subtype
  end

  def test_binary_with_string
    b = Binary.new('somebinarystring')
    doc = {'bin' => b}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    bin2 = doc2['bin']
    assert_kind_of Binary, bin2
    assert_equal 'somebinarystring', bin2.to_s
    assert_equal Binary::SUBTYPE_BYTES, bin2.subtype
  end

  def test_binary_type
    bin = Binary.new([1, 2, 3, 4, 5], Binary::SUBTYPE_USER_DEFINED)

    doc = {'bin' => bin}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    bin2 = doc2['bin']
    assert_kind_of Binary, bin2
    assert_equal [1, 2, 3, 4, 5], bin2.to_a
    assert_equal Binary::SUBTYPE_USER_DEFINED, bin2.subtype
  end

  def test_binary_byte_buffer
    bb = Binary.new
    5.times { |i| bb.put(i + 1) }

    doc = {'bin' => bb}
    bson = @encoder.serialize(doc)
    doc2 = @encoder.deserialize(bson)
    bin2 = doc2['bin']
    assert_kind_of Binary, bin2
    assert_equal [1, 2, 3, 4, 5], bin2.to_a
    assert_equal Binary::SUBTYPE_BYTES, bin2.subtype
  end

  def test_put_id_first
    val = BSON::OrderedHash.new
    val['not_id'] = 1
    val['_id'] = 2
    roundtrip = @encoder.deserialize(@encoder.serialize(val, false, true).to_a)
    assert_kind_of BSON::OrderedHash, roundtrip
    puts "ROUNDTRIP"
    puts roundtrip
    puts roundtrip.class
    puts
    puts roundtrip.keys
    puts
    assert_equal '_id', roundtrip.keys.first

    val = {'a' => 'foo', 'b' => 'bar', :_id => 42, 'z' => 'hello'}
    roundtrip = @encoder.deserialize(@encoder.serialize(val, false, true).to_a)
    assert_kind_of BSON::OrderedHash, roundtrip
    assert_equal '_id', roundtrip.keys.first
  end

  def test_nil_id
    doc = {"_id" => nil}
    assert_equal doc, @encoder.deserialize(bson = @encoder.serialize(doc, false, true).to_a)
  end

  def test_timestamp
    val = {"test" => [4, 20]}
    assert_equal val, @encoder.deserialize([0x13, 0x00, 0x00, 0x00,
                                      0x11, 0x74, 0x65, 0x73,
                                      0x74, 0x00, 0x04, 0x00,
                                      0x00, 0x00, 0x14, 0x00,
                                      0x00, 0x00, 0x00])
  end

  def test_overflow
    doc = {"x" => 2**75}
    assert_raise RangeError do
      bson = @encoder.serialize(doc)
    end

    doc = {"x" => 9223372036854775}
    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)

    doc = {"x" => 9223372036854775807}
    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)

    doc["x"] = doc["x"] + 1
    assert_raise RangeError do
      bson = @encoder.serialize(doc)
    end

    doc = {"x" => -9223372036854775}
    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)

    doc = {"x" => -9223372036854775808}
    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)

    doc["x"] = doc["x"] - 1
    assert_raise RangeError do
      bson = @encoder.serialize(doc)
    end
  end

  def test_invalid_numeric_types
    [BigDecimal.new("1.0"), Complex(0, 1), Rational(2, 3)].each do |type|
      doc = {"x" => type}
      begin
        @encoder.serialize(doc)
      rescue => e
      ensure
        assert_equal InvalidDocument, e.class
        assert_match /Cannot serialize/, e.message
      end
    end
  end

  def test_do_not_change_original_object
    val = BSON::OrderedHash.new
    val['not_id'] = 1
    val['_id'] = 2
    assert val.keys.include?('_id')
    @encoder.serialize(val)
    assert val.keys.include?('_id')

    val = {'a' => 'foo', 'b' => 'bar', :_id => 42, 'z' => 'hello'}
    assert val.keys.include?(:_id)
    @encoder.serialize(val)
    assert val.keys.include?(:_id)
  end

  # note we only test for _id here because in the general case we will
  # write duplicates for :key and "key". _id is a special case because
  # we call has_key? to check for it's existence rather than just iterating
  # over it like we do for the rest of the keys. thus, things like
  # HashWithIndifferentAccess can cause problems for _id but not for other
  # keys. rather than require rails to test with HWIA directly, we do this
  # somewhat hacky test.
  def test_no_duplicate_id
    dup = {"_id" => "foo", :_id => "foo"}
    one = {"_id" => "foo"}

    assert_equal @encoder.serialize(one).to_a, @encoder.serialize(dup).to_a
  end

  def test_no_duplicate_id_when_moving_id
    dup = {"_id" => "foo", :_id => "foo"}
    one = {"_id" => "foo"}

    assert_equal @encoder.serialize(one, false, true).to_s, @encoder.serialize(dup, false, true).to_s
  end

  def test_null_character
    assert_bson({"a" => "\x00"})

    assert_raise InvalidDocument do
      @encoder.serialize({"\x00" => "a"})
    end

    assert_raise InvalidDocument do
      @encoder.serialize({"a" => (Regexp.compile "ab\x00c")})
    end
  end

  def test_max_key
    doc = {"a" => MaxKey.new}

    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)
  end

  def test_min_key
    doc = {"a" => MinKey.new}

    assert_equal doc, @encoder.deserialize(@encoder.serialize(doc).to_a)
  end

  def test_symbol_key_converts_to_string

  end

  def test_invalid_object
    o = Object.new
    assert_raise InvalidDocument do
      @encoder.serialize({'foo' => o})
    end

    assert_raise InvalidDocument do
      @encoder.serialize({'foo' => Date.today})
    end
  end

#  def test_move_id
#    a = BSON::OrderedHash.new
#    a['text'] = 'abc'
#    a['key'] = 'abc'
#    a['_id']  = 1
#
#
#    #assert_equal ")\000\000\000\020_id\000\001\000\000\000\002text" +
#    #             "\000\004\000\000\000abc\000\002key\000\004\000\000\000abc\000\000",
#    #             @encoder.serialize(a, false, true).to_s
#
#    assert_equal ")\000\000\000\002text\000\004\000\000\000abc\000\002key" +
#                 "\000\004\000\000\000abc\000\020_id\000\001\000\000\000\000",
#                 @encoder.serialize(a, false, false).to_s
#  end
#
#  def test_move_id_with_nested_doc
#    b = BSON::OrderedHash.new
#    b['text'] = 'abc'
#    b['_id']   = 2
#    c = BSON::OrderedHash.new
#    c['text'] = 'abc'
#    c['hash'] = b
#    c['_id']  = 3
#    assert_equal ">\000\000\000\020_id\000\003\000\000\000\002text" +
#                 "\000\004\000\000\000abc\000\003hash\000\034\000\000" +
#                 "\000\002text\000\004\000\000\000abc\000\020_id\000\002\000\000\000\000\000",
#                 @encoder.serialize(c, false, true).to_s
#    assert_equal ">\000\000\000\002text\000\004\000\000\000abc\000\003hash" +
#                 "\000\034\000\000\000\002text\000\004\000\000\000abc\000\020_id" +
#                 "\000\002\000\000\000\000\020_id\000\003\000\000\000\000",
#                 @encoder.serialize(c, false, false).to_s
#  end
#
  if defined?(HashWithIndifferentAccess)
    def test_keep_id_with_hash_with_indifferent_access
      doc = HashWithIndifferentAccess.new
      embedded = HashWithIndifferentAccess.new
      embedded['_id'] = ObjectID.new
      doc['_id']      = ObjectID.new
      doc['embedded'] = [embedded]
      @encoder.serialize(doc, false, true).to_a
      assert doc.has_key?("_id")
      assert doc['embedded'][0].has_key?("_id")

      doc['_id'] = ObjectID.new
      @encoder.serialize(doc, false, true).to_a
      assert doc.has_key?("_id")
    end
  end
end
