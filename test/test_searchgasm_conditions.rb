require File.dirname(__FILE__) + '/test_helper.rb'

class TestSearchgasmConditions < Test::Unit::TestCase
  fixtures :accounts, :users, :orders
  
  def setup
    setup_db
    load_fixtures
  end
  
  def teardown
    teardown_db
  end
  
  def test_register_conditions
    Searchgasm::Search::Conditions.register_condition(Searchgasm::Search::ConditionTypes::KeywordsCondition)
    assert [Searchgasm::Search::ConditionTypes::KeywordsCondition], Searchgasm::Search::Conditions.conditions
    
    Searchgasm::Search::Conditions.register_condition(Searchgasm::Search::ConditionTypes::ContainsCondition)
    assert [Searchgasm::Search::ConditionTypes::KeywordsCondition, Searchgasm::Search::ConditionTypes::ContainsCondition], Searchgasm::Search::Conditions.conditions
    
  end
  
  def test_initialize
    conditions = Searchgasm::Search::Conditions.new(Account, :name_contains => "Binary")
    assert_equal conditions.klass, Account
    assert_equal conditions.name_contains, "Binary"
  end
  
  def test_conditions_added
    # test to make sure all of the proper methods were add, testing condition_names basically
  end
  
  def test_setting_conditions
    [Account, User, Order].each do |klass|
      conditions = klass.new_conditions
      conditions.condition_names.each do |condition_name|
        conditions.send("#{condition_name}=", 1)
        assert_equal 1, conditions.send(condition_name)
      end
    end
  end
  
  def test_accessible_protected_conditions
    #Account.conditions_accessible << :name_contains
    #conditions = Searchgasm::Search::Conditions.new(Account)
    #conditions.value = {:created_after => Time.now, :name_contains => "Binary"}
    #assert({:name_contains => "Binary"}, conditions.value)
  end
  
  def test_assert_valid_values
    conditions = User.new_conditions
    assert_raise(ArgumentError) { conditions.value = {:unknown => "blah"} }
    assert_nothing_raised { conditions.value = {:first_name => "blah"} }
    assert_nothing_raised { conditions.value = {:first_name_contains => "blah"} }
  end
  
  def test_setting_associations
    conditions = Searchgasm::Search::Conditions.new(Account, :users => {:first_name_like => "Ben"})
    assert_equal conditions.users.first_name_like, "Ben"
    
    conditions.users.last_name_begins_with = "Ben"
    assert_equal conditions.users.last_name_begins_with, "Ben"
  end
  
  def test_includes
    conditions = Searchgasm::Search::Conditions.new(Account)
    assert_equal conditions.includes, nil
    
    conditions.name_like = "Binary"
    assert_equal conditions.includes, nil
    
    conditions.users.first_name_like = "Ben"
    assert_equal conditions.includes, :users
    
    conditions.users.orders.description_like = "apple"
    assert_equal conditions.includes, {:users => :orders} 
  end
  
  def test_objects
    conditions = Searchgasm::Search::Conditions.new(Account)
    assert_equal conditions.objects, []
    
    conditions.name_contains = "Binary"
    assert_equal conditions.objects.size, 1
    
    conditions.users.first_name_contains = "Ben"
    assert_equal conditions.objects.size, 2
  end
  
  def test_reset
    conditions = Searchgasm::Search::Conditions.new(Account)
    
    conditions.name_contains = "Binary"
    assert_equal 1, conditions.objects.size
    
    conditions.reset_name_contains!
    assert_equal [], conditions.objects
    
    conditions.users.first_name_like = "Ben"
    assert_equal 1, conditions.objects.size
    
    conditions.reset_users!
    assert_equal [], conditions.objects
    
    conditions.name_begins_with ="Binary"
    conditions.users.orders.total_gt = 200
    assert_equal 2, conditions.objects.size
    
    conditions.reset_name_begins_with!
    assert_equal 1, conditions.objects.size
    
    conditions.reset_users!
    assert_equal [], conditions.objects
  end
  
  def test_sanitize
    conditions = Searchgasm::Search::Conditions.new(Account)
    conditions.name_contains = "Binary"
    conditions.id_gt = 5
    now = Time.now
    conditions.created_after = now
    assert_equal conditions.sanitize, ["(\"accounts\".\"name\" LIKE ?) AND (\"accounts\".\"id\" > ?) AND (\"accounts\".\"created_at\" > ?)", "%Binary%", 5, now]
    
    # test out associations
    conditions.users.first_name_like = "Ben"
    conditions.users.id_gt = 10
    conditions.users.orders.total_lt = 500
    assert_equal conditions.sanitize, ["(\"accounts\".\"name\" LIKE ?) AND (\"accounts\".\"id\" > ?) AND (\"accounts\".\"created_at\" > ?) AND ((\"users\".\"first_name\" LIKE ?) AND (\"users\".\"id\" > ?) AND (\"orders\".\"total\" < ?))", "%Binary%", 5, now, "%Ben%", 10, 500]
  end
  
  def test_value
    conditions = Searchgasm::Search::Conditions.new(Account)
    now = Time.now
    v = {:name_contains => "Binary", :created_at_greater_than => now}
    conditions.value = v
    assert_equal v, conditions.value
    
    scope = "id in (1,2,3,4)"
    conditions.value = scope
    assert_equal v, conditions.value, v
    assert_equal scope, conditions.scope
    
    v2 = {:id_less_than => 5, :name_begins_with => "Beginning of string"}
    conditions.value = v2
    assert_equal v.merge(v2), conditions.value
    
    scope2 = "id > 5 and name = 'Test'"
    conditions.value = scope2
    assert_equal scope2, conditions.scope
  end
  
  def test_searching
    conditions = Searchgasm::Search::Conditions.new(Account)
    conditions.name_contains = "Binary"
    assert_equal Account.find(1, 3), conditions.all
    assert_equal Account.find(1, 3), conditions.find(:all)
    assert_equal Account.find(1), conditions.first
    assert_equal Account.find(1), conditions.find(:first)
    assert_equal 2, conditions.average('id')
    assert_equal 2, conditions.calculate(:avg, 'id')
    assert_equal 3, conditions.calculate(:max, 'id')
    assert_equal 2, conditions.count
    assert_equal 3, conditions.maximum('id')
    assert_equal 1, conditions.minimum('id')
    assert_equal 4, conditions.sum('id')
  end
  
  def test_protection
    assert_raise(ArgumentError) { Account.new_conditions("(DELETE FROM users)") }
    assert_nothing_raised { Account.build_conditions!("(DELETE FROM users)") }
    
    account = Account.first
    
    assert_raise(ArgumentError) { account.users.build_conditions("(DELETE FROM users)") }
    assert_nothing_raised { account.users.build_conditions!("(DELETE FROM users)") }
  end
end
