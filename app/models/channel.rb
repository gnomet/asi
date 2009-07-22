require 'will_paginate'

class Channel < ActiveRecord::Base

  usesnpguid

  belongs_to :owner, :class_name => "Person"
  belongs_to :creator_app, :class_name => "Client"
  has_many :messages, :dependent => :destroy
  has_many :user_subscriptions, :dependent => :destroy 
  has_many :group_subscriptions, :dependent => :destroy 
  has_many :user_subscribers, :through => :user_subscriptions, :source => :person
  has_many :group_subscribers, :through => :group_subscriptions, :source => :group

  attr_accessible :name, :description, :channel_type, :owner, :creator_app
  attr_readonly :channel_type, :creator_app
  
  before_save :subscribe_owner
  before_validation_on_create :set_default_type
  
  validates_inclusion_of :channel_type, :in => %w( public friend group), :message => "must be public, friend or group."
  validates_presence_of :owner_id
  validates_presence_of :creator_app_id
  validates_presence_of :name
  validates_length_of :name, :minimum => 2
  validate :associations_must_exist
  
  define_index do
    indexes :name, :sortable => true
    indexes :description
    indexes messages(:body), :as => :posts
    indexes messages(:title), :as => :msg_title, :sortable => true
    has :guid
    has :created_at
    has :updated_at
  end

  def can_read?(user)
    if channel_type == "public"
      return true
    end 
    if user
      if channel_type == "friend"
        return true if user.contacts.include?(owner)
      end
      if channel_type == "group"
        group_subscribers.each do |subscription|
          return true if user.groups.include?(subscription)
        end
      end
    end
    return false 
  end

  def to_json(*a)
    hash = { :id => guid,
             :name => name,
             :description => description,
             :owner_id => owner_id,
             :owner_name => owner.name_or_username,
             :created_at => created_at,
             :updated_at => updated_at,
             :channel_type => channel_type
           }    
    return hash.to_json(*a)
  end
  
  private
  
  def set_default_type
    if !self.channel_type
      self.channel_type = "public"
    end
  end
  
  def subscribe_owner
    user_subscribers << owner rescue ActiveRecord::RecordInvalid
  end

  def associations_must_exist
    errors.add("Person #{owner.id} does not exist and cannot be channel owner.") if owner && !Person.exists?(owner.id)
    errors.add("Client #{creator_app.id} does not exist.") if creator_app && !Client.exists?(creator_app.id)
#    user_subscriber_ids.each do |subscriber|
#      errors.add("Person #{subscriber} does not exist and cannot be subscribed to channel.") if !Person.exists?(subscriber)
#    end
#    group_subscriber_ids.each do |subscriber|
#      errors.add("Group #{subscriber} does not exist and cannot be subscribed to channel.") if !Group.exists?(subscriber)
#    end
      
  end

end
