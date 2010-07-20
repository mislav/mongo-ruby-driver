# encoding:utf-8
require 'test/test_helper'

class CodeTest < Test::Unit::TestCase
  context "Code with scope" do
    setup do
      @code_str = "function() { print('hello'); }"
      @code = BSON::Code.new(@code_str)
      @code_with_scope = BSON::Code.new(@code_str, {:initial => 0})
    end

    should "be equal if data is equal" do
      equivalent_code = BSON::Code.new(@code_str)
      assert_equal @code, equivalent_code
    end

    should "be equal if data and scope are equal" do
      equivalent_code = BSON::Code.new(@code_str, {:initial => 0})
      assert_equal @code_with_scope, equivalent_code
    end

    should "not be equal to a string with the same value" do
      assert_not_equal @code, @code_str
    end

    should "not be equal to a string with no scope" do
      assert_not_equal @code_with_scope, @code_str
    end
  end
end
