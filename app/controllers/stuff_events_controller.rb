class StuffEventsController < ApplicationController

  before_filter :login_required, :except => [:show]
  before_filter :log_new_feature_visiting_status
  after_filter  :log_last_visiting_time

  def show
    @site_title = 'Activities from others'
    @subscribed_restaurants = []
    @user_log = nil
    conditions = nil

    if current_user
      @subscribed_restaurants = current_user.subscribed_restaurants.
          find(:all, :group => 'restaurants.id')
      @user_log = current_user.user_logs.by_topic(@topic.id).first
      conditions = [
          'restaurant_id IN (?) AND user_id != ?',
          @subscribed_restaurants.collect{|r| r.id},
          current_user.id]
    else
      conditions = []
    end

    @stuff_events = StuffEvent.paginate(
        :include => [:restaurant, :review, :review_comment],
        :conditions => conditions,
        :order => 'created_at DESC',
        :page => params[:page])

    load_module_preferences
    @left_modules = [
        :render_topic_box,
        :render_tagcloud,
        :render_most_lovable_places,
        :render_recently_added_places]
    @breadcrumbs = [['All', root_url]]
  end
end