class GamesController < ApplicationController

  layout false
  ensure_application_is_installed_by_facebook_user
  layout 'facebook'

  def index
    @randomly_selected_friends = select_friends(12)
    @restaurant = @topic.restaurants.first(
        :include => [:images, :other_images],
        :conditions => 'related_images.id <> 0 OR contributed_images.id <> 0',
        :order => 'RAND()')
    @selected_tab_index = 0
  end

  def treat_me
    @restaurant = Restaurant.find(params[:restaurant_id].to_i)

    if params[:friend_ids].nil?
      flash[:notice] = 'You haven\'t selected any friend yet!'
    else
      @friends = @facebook_session.fql_query("SELECT uid, name FROM user WHERE uid IN (#{params[:friend_ids].join(',')})");
      comment = params[:comment]

      if @restaurant
        @friends.each do |friend|
          treat_request = TreatRequest.create(
              :topic_id => @topic.id,
              :restaurant_id => @restaurant.id,
              :uid => @facebook_session.user.uid,
              :requested_uid => friend.uid
          )

          begin
            publish_wall_post(@facebook_session, friend, treat_request, @restaurant, comment)
          rescue => $e
            logger.error($e)
            flash[:notice] = $e;
          end
        end
        flash[:success] = "Weee! your request has been posted on your friend's wall! <fb:name uid='#{friend.uid}' firstnameonly='true' linked='true' />"
      else
        flash[:notice] = 'Sorry, we couldn\'t update anything'
      end
    end

    redirect_to "#{Facebooker.facebook_path_prefix}/"
  end

  def accept_request
    @treat_request = TreatRequest.find(params[:id].to_i)
    friends = @facebook_session.fql_query("SELECT uid, name FROM user WHERE uid IN (#{@treat_request.uid}, #{@treat_request.requested_uid})");
    @friend = friends.first
    @requested_to = friends.last

    if @treat_request.requested_uid == @facebook_session.user.uid
      if @treat_request.update_attribute(:accepted, true)
        flash[:success] = "Great! you have confirmed that you gonna treat #{@friend.name} @ #{@treat_request.restaurant.name}"
      else
        flash[:notice] = 'Such a pain in aaa... (amazon)!'
      end
    else
      flash[:notice] = "Hi, we understand you can treat, but this time it was asked from <fb:name uid='#{@requested_to.uid}' firstnameonly='true' linked='true'/>"
    end

    redirect_to "#{Facebooker.facebook_path_prefix}/"
  end

  def my_requests
    @selected_tab_index = 1
    @title = 'My already sent treat requests!'

    @treat_requests = TreatRequest.paginate(
        :conditions => {
            :topic_id => @topic.id,
            :uid => @facebook_session.user.uid
        },
        :include => [:restaurant],
        :page => params[:page])
  end

  def accepted_my_request
    @treat_requests = TreatRequest.paginate(
        :conditions => {
            :topic_id => @topic.id,
            :uid => @facebook_session.user.uid,
            :accepted => true
        },
        :include => [:restaurant],
        :page => params[:page])
    @selected_tab_index = 2
    @title = 'My accepted requests!'
  end

  private

    def publish_wall_post(session, friend, treat_request, restaurant, comment)
      restaurant_url = restaurant_long_url(
          :canvas => false,
          :name => (restaurant.name || '').parameterize.to_s,
          :id => restaurant.id)

      message = %{asked for your treat @ #{restaurant.name}}
      attached_images = attach_images(restaurant_url, restaurant)
      
      session.user.publish_to(friend,  :message => message,
        :attachment => {
          :name => "#{restaurant.name} @ #{restaurant.address}",
          :href => restaurant_url,
          :description => comment || restaurant.description,
          :media => attached_images
        },

        :action_links => [{
            :text => 'Yes, i will treat!',
            :href => "accept_request/#{treat_request.id}"
          }]
      )
    end

    def attach_images(restaurant_url, restaurant)
      attached_images = []
      images = restaurant.images
      images = restaurant.other_images if images.empty?

      if images && !images.empty?
        images.shuffle.each do |image|
          attached_images << {
              :type => 'image',
              :src => "#{root_url(:canvas => false)[0..root_url(:canvas => false).length - 2]}#{image.public_filename(:large)}",
              :title => "#{image.caption}",
              :href => restaurant_url
          }
        end
      end

      attached_images << {
          :type => 'image',
          :src => "http://maps.google.com/maps/api/staticmap?center=#{restaurant.lat},#{restaurant.lng}&zoom=14&size=280x300&sensor=false&markers=color:green|label:R|#{restaurant.lat},#{restaurant.lng}&key=#{MAP_API_KEY}",
          :title => "address: #{restaurant.address}",
          :href => "http://maps.google.com/maps?f=q&hl=en&geocode=&sll=#{restaurant.lat},#{restaurant.lng}"
          }

      attached_images
    end

    def select_restaurants(max)

    end

    def select_friends(max)
      # Load existing treat requests
      existing_requests = TreatRequest.all :conditions => {:uid => @facebook_session.user.uid}
      existing_requests = existing_requests.collect{|r| r.requested_uid}

      randomly_selected_friends = {}
      while (randomly_selected_friends.length < max)
        friend = @facebook_session.user.friends.rand
        if !existing_requests.include?(friend.uid.to_i) && !randomly_selected_friends.keys.include?(friend.uid)
          randomly_selected_friends[friend.uid] = friend
        end
      end

      randomly_selected_friends
    end
end