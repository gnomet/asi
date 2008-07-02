# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.



class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  layout 'default'

  before_filter :maintain_session_and_user

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '9c4bfc3f5c5b497cf9ce1b29fdea20f5'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password


  def index
  end


# FROM AUTHENTICATION MODULE

  def ensure_login
    unless @user
      flash[:notice] = "Please login to continue"
      logger.debug "NOT LOGGED IN:" + @user.inspect
      render :status => :unauthorized and return
    end
  end
 
  def ensure_logout
    if @user
      flash[:notice] = "You must logout before you can login or register"
      redirect_to(root_url)
    end
  end
 
  protected
 
  def maintain_session_and_user
    if session[:session_id]
      if @application_session = Session.find_by_id(session[:session_id])
        begin #Strange rescue-solution is because request.path_info acts strangely in tests
          path = request.path_info
        rescue NoMethodError => e
          path = "running/tests/no/path/available"
        end
        @application_session.update_attributes(:ip_address => request.remote_addr, :path => path)
        @user = @application_session.person
        @client = @application_session.client
      else
        session[:session_id] = nil
        redirect_to(root_url)
      end
    else
      #logger.debug "NO SESSION:" + session[:session_id]
    end
    
  end
end
