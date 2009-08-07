class MessagesController < ApplicationController

  before_filter :get_channel
  before_filter :ensure_can_read_channel, :only => [ :index, :create, :show ]
  before_filter :get_message, :only => [ :delete, :edit, :show ]

  def index
    if params[:search]
      @messages = Message.search( params[:search],
                                  :per_page => params[:per_page],
                                  :page => params[:page],
                                  :with => { :channel_id => @channel.id})
      size = @messages.total_entries
    else
      options = {}
      if params[:per_page]
        options[:limit] = params[:per_page].to_i
        if params[:page] && params[:page].to_i >= 1
          options[:offset] = params[:per_page].to_i * (params[:page].to_i-1)
        end
      end
      options[:conditions] = {:channel_id => @channel.id }
      sort_order = 'DESC'
      if params[:sort_order]
        if params[:sort_order] == 'ascending'
          sort_order = 'ASC'
        elsif params[:sort_order] == 'descending'
          sort_order = 'DESC'
        end
      end
      options[:order] = 'updated_at ' + sort_order
      @messages = Message.all(options)
      size = Message.count(:conditions => options[:conditions])
    end
    render_json :entry => @messages, :size => size and return
  end

  def create
    @message = Message.new(params[:message].except(:reference_to))
    if params[:message][:reference_to]
      ref = Message.find_by_guid( params[:message][:reference_to] )
      if !ref
        render :status => :bad_request and return
      end
      @message.reference_to = ref.id
    end
    @message.channel = @channel
    @message.poster = @user
    if !@message.save
      render_json :status => :bad_request,
                  :messages => @message.errors.full_messages and return
    end
    render_json :status => :created, :entry => @message and return
  end

  def show
    render_json :entry => @message
  end

  def edit

  end

  def delete
    if ensure_same_as_logged_person(@message.poster.guid)
      @message.delete
      render :status => :ok and return
    elsif ensure_same_as_logged_person(@channel.owner.guid)
      @message.delete
      render :status => :ok and return
    end
    render :status => :forbidden and return
  end

  private

  def get_message
    @message = Message.find_by_guid(params[:msg_id])
    if !@message
      render :status => :not_found and return
    end
  end

end
