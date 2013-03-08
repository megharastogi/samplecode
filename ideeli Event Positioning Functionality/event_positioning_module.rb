module EventPositioningModule

  def update_event_positioning
    if @was_new_record
      self.is_a?(ShoppingEvent) ? create_ep_for_new_event : find_ep_for_new_event
    else        
      if (start_at_changed? || end_at_changed?) && channels_modified
        event_channel_and_time_change_adjustment
      elsif (start_at_changed? || end_at_changed?) && !channels_modified
        event_time_change_adjustment
      elsif channels_modified && !(start_at_changed? || end_at_changed?)
        event_channel_change_adjustment
      end
    end        
  end

  def create_new_ep_if_start_at_distinct
    ep = EventPositioning.find_or_create_by_start_at(:start_at => event_visible_latest_time)
    ep_hep = EventPositioning.find_or_create_by_start_at_and_hep(:start_at => event_visible_latest_time, :hep => true)
  end

  def create_ep_for_new_event
    create_new_ep_if_start_at_distinct
    if channel_ids.present?
      ep_ids = find_ep_ids(self)
      ScheduledEvent.add_scheduled_events_for_eps_and_channel(ep_ids, id, channel_ids, self.class.to_s) if ep_ids.present?
    end  
  end  

  def find_ep_for_new_event
    if channel_ids.present?
      ep_ids = find_ep_ids(self)
      ep_ids.push(closest_ep(start_at)).compact!
      ep_ids.uniq!
      ScheduledEvent.add_scheduled_events_for_eps_and_channel(ep_ids, id, channel_ids, self.class.to_s) if ep_ids.present?
    end
  end

  def event_channel_and_time_change_adjustment
    previous_channels = scheduled_events.retrieve_column(:channel_id).uniq
    # remove event from ep's in which shopping event don't lie now and add event in ep's for which it does
    old_ep_ids = scheduled_events.retrieve_column(:event_positioning_id).uniq
    new_ep_ids = find_ep_ids(self)
    event_time_change_adjustment
    if self.is_a?(ChannelPlaceholderEvent)      
      new_ep_ids.push(closest_ep(start_at)).compact!
      new_ep_ids.uniq!
    end
    add_channels, remove_channels = add_remove_ids(previous_channels, channel_ids)
    # remove those channels which are not required now
    ScheduledEvent.remove_scheduled_events_for_channels(id, remove_channels, self.class.to_s) if remove_channels.present?
    # ep's which has not been changed 
    eps_need_new_channels = old_ep_ids & new_ep_ids
    # add new channels to ep's which has not been changed 
    ScheduledEvent.add_scheduled_events_for_eps_and_channel(eps_need_new_channels, id, add_channels, self.class.to_s) if (eps_need_new_channels.present? && add_channels.present?)
  end  

  def event_time_change_adjustment
    create_new_ep_if_start_at_distinct if start_at_changed? && self.is_a?(ShoppingEvent)
    EventPositioning.remove_invalid_eps(start_at_was - ShoppingEvent.lead_in_period) if start_at_changed? && self.is_a?(ShoppingEvent)
    old_ep_ids = scheduled_events.retrieve_column(:event_positioning_id).uniq
    new_ep_ids = find_ep_ids(self)
    if self.is_a?(ChannelPlaceholderEvent)      
      new_ep_ids.push(closest_ep(start_at)).compact!
      new_ep_ids.uniq!
    end
    add_ep_ids, remove_ep_ids = add_remove_ids(old_ep_ids, new_ep_ids)
    ScheduledEvent.remove_scheduled_events_for_eps(remove_ep_ids, id, self.class.to_s) if remove_ep_ids.present?
    ScheduledEvent.add_scheduled_events_for_eps_and_channel(add_ep_ids, id, channel_ids, self.class.to_s) if add_ep_ids.present? && channel_ids.present?
  end

  def event_channel_change_adjustment
    previous_channels = scheduled_events.retrieve_column(:channel_id).uniq
    ep_ids = scheduled_events.retrieve_column(:event_positioning_id).uniq
    #only in the case when ep created due to event which has no channels but we are adding channels now
    if ep_ids.blank?
      ep_ids = find_ep_ids(self)
      if self.is_a?(ChannelPlaceholderEvent)      
        ep_ids.push(closest_ep(start_at)).compact!
        ep_ids.uniq!
      end
    end
    add_channels, remove_channels = add_remove_ids(previous_channels, channel_ids)
    ScheduledEvent.add_scheduled_events_for_eps_and_channel(ep_ids, id, add_channels, self.class.to_s) if add_channels.present?
    ScheduledEvent.remove_scheduled_events_for_channels(id, remove_channels, self.class.to_s) if remove_channels.present?
  end  

  #in case of channel placeholder event it is finding a ep in which event is starting in
  def closest_ep(start_at)
    EventPositioning.find(:first, :conditions =>["start_at <= ? and hep = ?", start_at, hep], :order => "start_at DESC").try(:id)
  end  

  def add_remove_ids(old_ids, new_ids)
    remove_ids = old_ids - new_ids
    add_ids = new_ids - old_ids
    return add_ids,remove_ids
  end 
  
  def find_ep_ids(event)
    return EventPositioning.in_time_range(event_visible_latest_time, end_at).retrieve_column(:id) if event.is_a?(ShoppingEvent)
   
    # if event is not a ShoppingEvent means its a ChannelPlaceholderEvent  
    if hep
      EventPositioning.with_hep.in_time_range(start_at, end_at).retrieve_column(:id) 
    else
      EventPositioning.without_hep.in_time_range(start_at, end_at).retrieve_column(:id)
    end
  end
   
  def event_visible_latest_time
    (start_at - ShoppingEvent.lead_in_period)
  end  
  
end