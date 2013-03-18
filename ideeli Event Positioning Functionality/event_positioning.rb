# Rail 2.9 

class EventPositioning < ActiveRecord::Base

  has_many :scheduled_events , :dependent => :delete_all
  
  default_scope :order => "start_at"
  after_create :create_scheduled_event_for_existing_events
  named_scope :in_time_range, lambda{|start_at, end_at| {:conditions => ["start_at >= ? and start_at <=?", start_at, end_at]}}  
  named_scope :without_hep, :conditions => {:hep => false}
  named_scope :with_hep, :conditions => {:hep => true}
  
  #find events for a particular channel('men','women','kids')
  def events_for_channel(channel_id)
    channel = Channel.find_by_id(channel_id)
    scheduled_events = ScheduledEvent.find_ordered_by_position_and_start_at(self, channel)
    returning events = [] do
      if live?
        scheduled_events.each {|e| events << e.event_positioning_item if e.event_positioning_item.live?(channel, self) }
      else
        scheduled_events.each {|e| events << e.event_positioning_item }
      end    
    end  
  end

  def live?(ep_type = nil)
    if ep_type == :default
      self == EventPositioning.live_event_positioning
    elsif ep_type == :hep
      self == EventPositioning.live_event_positioning(:hep)
    else
      EventPositioning.find(:all, :conditions =>["start_at <= ?", Time.now], :limit => 2, :order => "start_at DESC").include?(self)
    end  
  end
  
  #returns live EP depending upon ep_type
  def self.live_event_positioning(ep_type = :default)
    find(:first, :conditions =>["start_at <= ? and hep = ?", Time.now, (ep_type == :hep ? true : false)], :order => "start_at DESC")
  end  
  
  def create_scheduled_event_for_existing_events
    just_previous_ep = EventPositioning.find(:first, :conditions =>["start_at < ? and hep = ?", start_at, hep], :order => 'start_at DESC')
    ScheduledEvent.include_continuing_events_from_previous_ep(just_previous_ep, self) if just_previous_ep
  end  
  
  def self.delete_ep_if_empty(eps)
    eps.each do |ep|
      ep.destory if ep.scheduled_events.blank?
    end  
  end
  
  def self.replicate_order(ep, copy_type)
    all_channel_id = Channel.find_by_name('all').id
    if copy_type == 'default'
      copy_from_ep = EventPositioning.find(:first, :conditions => {:start_at => ep.start_at, :hep => false})
      copy_from_channel_id = Channel.find_by_name('women').id
      copy_to_channel_id = all_channel_id
      ep.ordered = true
      ep.save
    else
      copy_from_ep = ep
      copy_from_channel_id = all_channel_id
      copy_to_channel_id = Channel.find_by_name(copy_type).id
    end        
    ScheduledEvent.copy_order_from_channel(ep, copy_from_ep, copy_to_channel_id, copy_from_channel_id)
  end  
  
  def self.remove_invalid_eps(ep_start_at)    
    eps = EventPositioning.find(:all, :conditions => {:start_at => ep_start_at})
    if eps.present?
      eps.each do |ep|
        ep.scheduled_events.each do |sc|
          if (sc.event_positioning_item.start_at - ShoppingEvent.lead_in_period) == ep.start_at && sc.event_positioning_item_type == 'ShoppingEvent'
            return true 
          end     
        end  
        ep.destroy
      end  
    end  
  end
  
end
