# -*- coding: utf-8 -*-
require 'test_helper'
require 'json'

class CollectionsControllerTest < ActionController::TestCase

  def setup
    @controller = CollectionsController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end

  def test_index
    get :index, { :app_id => clients(:one).id, :format => 'json' }, { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_not_nil assigns["collections"]
    json = JSON.parse(@response.body)
    assert_not_nil json["entry"]

    # Should only return collections relevant to this client
    for collection in assigns["collections"]
      assert_equal(collection.client, clients(:one))
    end

    # Should not crash on a nonexistent client
    get :index, { :app_id => -1, :format => 'json' }
    assert_response :forbidden
    assert_nil assigns["collection"]
  end

  def test_show

    # Should not show without logging in
    get :show, { :app_id => clients(:two).id, :id => collections(:one).id, :format => 'json' }

    assert_response :forbidden
    assert_nil assigns["collection"]


    # Should show a collection belonging to the client
    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }

    assert_response :success
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]

    # Should not show a collection belonging to another client
    get :show, { :app_id => clients(:two).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session2).id }

    assert_response :forbidden
    assert_nil assigns["collection"]

    # Should not show a private collection belonging to another user
    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session2).id }

    assert_response :forbidden
    assert_nil assigns["collection"]

    # Should show a private collection belonging to a connection of the user
    get :show, { :app_id => clients(:one).id, :id => collections(:three).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }

    assert people(:valid_person).contacts.include?(collections(:three).owner)
    assert_response :success
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]

    # Should not show a private collection beloning to a requested connection
    get :show, { :app_id => clients(:one).id, :id => collections(:four).id, :format => 'json' },
               { :client => clients(:one).id, :user => people(:valid_person) }

    assert_response :forbidden
    assert_nil assigns["collection"]

    # Should not crash on a nonexistent collection
    get :show, { :app_id => clients(:one).id, :id => 2340982349078, :format => 'json' },
               { :client => clients(:one).id }
    assert_response 404
    assert_nil assigns["collection"]

    # Should not crash on a nonexistent client
    get :show, { :app_id => -1, :id => 2340982349078, :format => 'json' }
    assert_response 403
    assert_nil assigns["collection"]

  end

  def test_showing_collection_references
    # should not show reference to a non-readable collection
    get :show, { :app_id => clients(:one).id, :id => collections(:six).id, :format => 'json' },
               { :cos_session_id => sessions(:session6).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)
    entry = json["entry"]['entry']
    assert_equal(json['entry']["totalResults"], entry.size)
    entry.each do |item|
      assert_not_equal(collections(:three).id, item["id"])
    end

    # should show reference to a readable collection
    get :show, { :app_id => clients(:one).id, :id => collections(:six).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)
    entry = json["entry"]['entry']
    assert_equal(json['entry']["totalResults"], entry.size)
    found_ref = false
    entry.each do |item|
      found_ref = true if item["id"] == collections(:three).id
    end
    assert(found_ref, "Existing collection reference was not shown.")
  end

  def test_create
    # With an owner and a client
    post :create, { :app_id => clients(:one).id, :format => 'json', :collection => {:owner_id => people(:valid_person).guid }},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :created
    assert_not_nil assigns["collection"]
    assert_equal(assigns["collection"].owner, people(:valid_person))
    assert_equal(assigns["collection"].client, clients(:one))
    json = JSON.parse(@response.body)
    assert_not_nil json["entry"]["id"]
  end

  def test_create_with_client
    # With only a client
    post :create, { :app_id => clients(:one).id, :format => 'json', :collection => {:title => "test-collection"}},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :created
    assert_not_nil assigns["collection"]
    assert_nil assigns["collection"].owner
    assert_equal(assigns["collection"].client, clients(:one))
    json = JSON.parse(@response.body)
    assert_not_nil json["entry"]["id"]
    assert_not_nil json["entry"]["title"]
    assert_equal("test-collection", json["entry"]["title"])
  end

  def test_create_with_owner
    # With only an owner
    post :create, { :app_id => '2', :format => 'json', :owner_id => people(:valid_person).id },
                  { :cos_session_id => sessions(:session1).id }
    assert_response :forbidden
  end

  def test_create_without_owner
    # With neither
    post :create, { :app_id => '2', :owner_id => '3', :format => 'json' }, {:cos_session_id => sessions(:session1).id}
    assert_response :forbidden
  end

  def test_delete
    # Should delete a collection belonging to the client
    delete :delete, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
                    { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)

    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :not_found

    # Should not delete a collection belonging to another client
    delete :delete, { :app_id => '2', :id => collections(:two).id, :format => 'json' },
                    { :cos_session_id => sessions(:session1).id }
    assert_response :forbidden

    # Should not delete a collection belonging to another user
    delete :delete, { :app_id => '2', :id => collections(:two).id, :user => people(:valid_person).id, :format => 'json' },
                    { :cos_session_id => sessions(:session2).id }
    assert_response :forbidden

    # Should not delete a collection belonging to a friend
    delete :delete, { :app_id => clients(:one).id, :id => collections(:three).id, :format => 'json' },
                    { :client => collections(:three).client.id, :user => people(:valid_person).id }

    assert people(:valid_person).contacts.include?(collections(:three).owner)
    assert_response :forbidden

    # Should remove reference to a deleted collection, textitems that were in deleted collection and references to those items
    # but a referenced collection should not be deleted

    # check situation before delete
    assert_not_equal( [], Ownership.find(:all, :conditions => {:parent_id => collections(:six).id, :item_id => collections(:three).id }))
    assert_equal(3, Ownership.find(:all, :conditions => {:parent_id => collections(:three).id, :item_type => "TextItem" }).size)
    assert_not_nil(TextItem.find_by_id(text_items(:one).id))
    assert_not_nil(Collection.find_by_id(collections(:four).id))
    assert_not_nil(Ownership.find(:first, :conditions => {:parent_id => collections(:three).id, :item_id => collections(:four).id}))

    delete :delete, { :app_id => clients(:one).id, :id => collections(:three).id, :format => 'json' },
                    { :cos_session_id => sessions(:session4).id  }
    assert_response :success, @response.body

    # check situation after delete
    assert_equal( [], Ownership.find(:all, :conditions => {:parent_id => collections(:six).id, :item_id => collections(:three).id }))
    assert_equal(0, Ownership.find(:all, :conditions => {:parent_id => collections(:three).id, :item_type => "TextItem" }).size)
    assert_nil TextItem.find_by_id(text_items(:one).id)
    assert_not_nil(Collection.find_by_id(collections(:four).id))
    assert_nil(Ownership.find(:first, :conditions => {:parent_id => collections(:three).id, :item_id => collections(:four).id}))
  end

  def test_add_text
    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    old_item_count = assigns["collection"].items.count
    json = JSON.parse(@response.body)

    # Should be able to add to a collection belonging to the client
    post :add, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                 :item => {:title => "The Engine", :content_type => "text/plain", :body => "Lorem ipsum dolor sit amet." }},
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_equal(old_item_count+1, assigns["collection"].items.count)
    json = JSON.parse(@response.body)
  end

  def test_add_unauthorized
    # Should be able to add to a collection belonging to the client
    post :add, { :app_id => clients(:one).id, :id => collections(:seven).id, :format => 'json',
                 :title => "The Engine", :content_type => "text/plain", :body => "Lorem ipsum dolor sit amet." },
               { :cos_session_id => sessions(:session1).id }
    assert_response :forbidden
    json = JSON.parse(@response.body)
  end


  # def test_add_image
  #   get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
  #              { :cos_session_id => sessions(:session1).id }
  #   assert_response :success
  #   old_item_count = assigns["collection"].items.count
  #   json = JSON.parse(@response.body)

  #   # Should be able to add to a collection belonging to the client
  #   post :add, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
  #                :item => {:file => fixture_file_upload("Bison_skull_pile.png","image/png") }},
  #              { :cos_session_id => sessions(:session1).id }
  #   assert_response :success
  #   assert_equal(old_item_count+1, assigns["collection"].items.count)
  #   json = JSON.parse(@response.body)
  # end

  def test_add_collection_reference
    # add
    post :add, { :app_id => clients(:one).id, :format => 'json', :id => collections(:one).id, :item => {
                 :content_type => "collection", :collection_id => collections(:three).id }},
               { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)

    #check
#    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
#               { :cos_session_id => sessions(:session1).id }
#    assert_response :success, @response.body
#    json = JSON.parse(@response.body)
#    assert_equal(collections(:three).id, json["entry"]["id"])

    #delete
    try_to_delete_item(collections(:three).id, sessions(:session1).id, true, collections(:one).id)

    #check
    get :show, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)
    assert_nil json["entry"][0]

    # when deleting collection reference, don't destroy the target object
    get :show, { :app_id => clients(:one).id, :id => collections(:three).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)

  end

  def test_metadata
    post :create, { :app_id => clients(:one).id, :format => 'json',
                    :collection => {:metadata => { :created => "right now", :is_nice => "truly" } }},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :created
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["metadata"]
    assert_equal("right now", json['entry']["metadata"]["created"])
    assert_equal("truly", json['entry']["metadata"]["is_nice"])

    put :update, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                   :collection => {:metadata => { :foo => "bar", :bar => "Foobar" } }},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("bar", json['entry']["metadata"]["foo"])
    assert_equal("Foobar", json['entry']["metadata"]["bar"])

    put :update, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                   :collection => {:metadata => { :foo2 => "bar", :bar => "foo" } }},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("bar", json['entry']["metadata"]["foo2"])
    assert_equal("bar", json['entry']["metadata"]["foo"], "Old metadata key was lost while updating")
    assert_equal("foo", json['entry']["metadata"]["bar"])

    # Try to update the collection's id and owner
    put :update, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                   :collection => { :id => "9999", :owner_id => "9999" } },
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body #succeeds but doesn't change anything
    json = JSON.parse(@response.body)
    assert_not_equal("9999", json['entry']["id"])

    # Try to update metadata for a collection belonging to another user
    put :update, { :app_id => clients(:one).id,
                   :id => collections(:two).id,
                   :format => 'json',
                    :metadata => { :foo2 => "bar", :bar => "foo" } },
                 { :cos_session_id => sessions(:session1).id }
    assert_response :forbidden
  end

  def test_tags
    post :create, { :app_id => clients(:one).id, :format => 'json',
                    :collection => {:tags => "nice, test"}},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :created
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["tags"]
    assert_equal("nice, test", json['entry']["tags"])

    put :update, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                   :collection => {:tags => "important" }},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("important", json['entry']["tags"])
  end

  def test_delete_item
    # should delete in own collection
    try_to_delete_item(text_items(:one).id, sessions(:session4).id, true)

    # should not delete item without write access (readonly)
    try_to_delete_item(text_items(:three).id, sessions(:session4).id, false)

    # should not delete in a collection with write access but not owned
    try_to_delete_item(text_items(:four).id, sessions(:session4).id, false)

  end

  def test_indestructible
    #create indfestructible and try to delete
    post :create, { :app_id => clients(:one).id, :collection => {:indestructible => "true"}, :format => 'json'},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :created
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]

    delete :delete, { :app_id => clients(:one).id, :id => json['entry']["id"], :format => 'json' },
                    { :cos_session_id => sessions(:session1).id }
    assert_response :forbidden

    #try to create indestructible with an owner
    post :create, { :app_id => clients(:one).id, :format => 'json', :collection => {:indestructible => "true", :owner_id => people(:valid_person).id }},
                  { :cos_session_id => sessions(:session1).id, :client => clients(:one).id }
    assert_response :bad_request
  end

  def test_read_only
    get :show, { :app_id => clients(:one).id, :id => collections(:read_only).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    old_item_count = assigns["collection"].items.count
    json = JSON.parse(@response.body)

    # Should not be able to add to a read_only collection belonging to other (non-friend)  user
    post :add, { :app_id => clients(:one).id, :id => collections(:read_only).id, :format => 'json',
                 :item => {:title => "The Engine", :content_type => "text/plain", :body => "Lorem ipsum dolor sit amet." }},
               { :cos_session_id => sessions(:session3).id }
    assert_response :forbidden

    #check that item count didn't change
    get :show, { :app_id => clients(:one).id, :id => collections(:read_only).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_equal(old_item_count, assigns["collection"].items.count)

    #test changing read_only
    put :update, { :app_id => clients(:one).id, :format => 'json', :id => collections(:read_only).id, :collection => {
                   :read_only => "false"}},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal(false, json['entry']["read_only"] )
    put :update, { :app_id => clients(:one).id, :id => collections(:read_only).id, :format => 'json',
                   :collection => {:read_only => "true"}},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal(true, json['entry']["read_only"] )

  end

  def test_error_reporting
    post :add, { :app_id => clients(:one).id, :id => collections(:one).id, :format => 'json',
                 :item => {:file => fixture_file_upload("collections.yml","image/png"),
                 :full_image_size => '240x300'}},
               { :cos_session_id => sessions(:session1).id }
    assert_response :bad_request

    get :show, { :app_id => clients(:one).id, :id => collections(:one).id + "eoscrh", :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :not_found
  end

  def test_update_title
    testcollection = collections(:one)
    assert_nil(testcollection.title)
    put :update, { :app_id => clients(:one).id, :id => testcollection.id, :format => 'json',
                   :collection => {:title => "first" }},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("first", json['entry']["title"])

    put :update, { :app_id => clients(:one).id, :id => testcollection.id, :format => 'json',
                   :collection => {:title => "second" }},
                 { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("second", json['entry']["title"])

    put :update, { :app_id => clients(:one).id, :id => testcollection.id, :format => 'json',
                   :collection => {:title => "" }}, { :cos_session_id => sessions(:session1).id }
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal("", json['entry']["title"])
  end

  def test_pagination_and_visibility

    #test without pagination, check that one friends-only collection ref is not shown
    get :show, { :app_id => clients(:one).id, :id => collections(:three).id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]
    assert_equal(Collection.find_by_id(collections(:three).id).items.count - 1, json["entry"]['entry'].size)
    assert_nil(json['entry']["itemsPerPage"])
    assert_equal(0, json['entry']["startIndex"])
    assert_equal(3, json['entry']["totalResults"])

    #test with pagination
    get :show, { :app_id => clients(:one).id, :id => collections(:three).id, :count => 2,  :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]
    assert_equal(2, json['entry']["entry"].size)
    assert_equal(2, json['entry']["itemsPerPage"])
    assert_equal(0, json['entry']["startIndex"])
    assert_equal(3, json['entry']["totalResults"])

    #get the remaining "page"
    get :show, { :app_id => clients(:one).id, :id => collections(:three).id, :count => 2, :startIndex => 3,  :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success
    assert_not_nil assigns["collection"]
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]
    assert_equal(1, json['entry']["entry"].size)
    assert_equal(2, json['entry']["itemsPerPage"])
    assert_equal(3, json['entry']["startIndex"])
    assert_equal(3, json['entry']["totalResults"])

  end

  def test_routing
    app_id = "Aajfalhr3q3DSF"
    item_id = "asdaltbgsuif"
    with_options :controller => "collections", :format => "json" do |test|
      test.assert_routing({ :method => "delete", :path => "/appdata/#{app_id}/@collection_items/#{item_id}" },
        { :action => "delete_item", :app_id => app_id, :item_id => item_id })
      test.assert_routing({ :method => "delete", :path => "/appdata/#{app_id}/@collections/asdf/@items/#{item_id}" },
        { :action => "delete_item", :app_id => app_id, :item_id => item_id, :id => "asdf" })
    end
  end

  def try_to_delete_item(item_id, cos_session_id, should_success=true, collection_id=nil)

    delete_parameters = {}  # add colle
    delete_parameters.merge!({:id => collection_id }) if collection_id

    collection_id = Ownership.find_by_item_id(item_id).parent.id if collection_id.nil?
    # first get original item count
    get :show, { :app_id => clients(:one).id, :id => collection_id, :format => 'json' },
               { :cos_session_id => cos_session_id }
    assert_response :success
    json = JSON.parse(@response.body)
    old_item_count = assigns["collection"].items.count
    assert(old_item_count > 0 , "The test collection doesn't contain any item to delete.")

    delete_parameters.merge!({ :app_id => clients(:one).id, :item_id => item_id, :format => 'json' })

    delete :delete_item, delete_parameters, { :cos_session_id => cos_session_id }

    if should_success
      assert_response :success
    else
      assert_response :forbidden
    end
    json = JSON.parse(@response.body)

    # check item count after
    get :show, { :app_id => clients(:one).id, :id => collection_id, :format => 'json' },
               { :cos_session_id => cos_session_id }
    assert_response :success
    json = JSON.parse(@response.body)
    new_item_count = assigns["collection"].items.count
    if should_success
      assert_equal(old_item_count - 1, new_item_count , "The item count in collection was not 1 less after delete")
      assert_nil(TextItem.find_by_id(item_id))
    else
      assert_equal(old_item_count , new_item_count , "The item count in collection was change although delete was forbidden")
      assert_not_nil(TextItem.find_by_id(item_id))
    end
  end

  def test_creating_a_collection_with_predefined_id
    test_id = "test_id_with_randomnes"

    post :create, { :app_id => clients(:one).id, :format => 'json', :collection => { :title => "test-collection", :id => test_id} },
                  { :client => clients(:one).id, :cos_session_id => sessions(:session1).id }
    assert_response :created, @response.body
    assert_not_nil assigns["collection"]
    assert_nil assigns["collection"].owner
    assert_equal(assigns["collection"].client, clients(:one))
    json = JSON.parse(@response.body)
    assert_not_nil json['entry']["id"]
    assert_not_nil(json['entry']["title"])
    assert_equal("test-collection", json['entry']["title"])
    assert_equal(test_id, json['entry']["id"])

    #test that the id of the created collection was set right
    get :show, { :app_id => clients(:one).id, :id => test_id, :format => 'json' },
               { :cos_session_id => sessions(:session1).id }
    assert_response :success, @response.body
    json = JSON.parse(@response.body)
    assert_equal(test_id, json['entry']["id"])

    # Test that can't make an other collection with same id
     post :create, { :app_id => clients(:one).id, :format => 'json', :title => "test-collection", :id => test_id},
                    { :client => clients(:one).id, :cos_session_id => sessions(:session1).id }
    assert_response :bad_request, @response.body
    json = JSON.parse(@response.body)
    assert(json.to_s.match(/is already taken/), "No message about the id being already taken")

    # Test that can't make with too short ID
     post :create, { :app_id => clients(:one).id, :format => 'json', :title => "shortID", :id => test_id},
                    { :client => clients(:one).id, :cos_session_id => sessions(:session1).id }
    assert_response :bad_request, @response.body

    # Test that can't make with too long ID
     post :create, { :app_id => clients(:one).id, :format => 'json', :title => "over_22_chars_long_id12", :id => test_id},
                    { :client => clients(:one).id, :cos_session_id => sessions(:session1).id }
    assert_response :bad_request, @response.body

    # Test that can't make id with illegal characters
     post :create, { :app_id => clients(:one).id, :format => 'json', :title => "id_with_€%&_spice", :id => test_id},
                    { :client => clients(:one).id, :cos_session_id => sessions(:session1).id }
    assert_response :bad_request, @response.body

  end
end
