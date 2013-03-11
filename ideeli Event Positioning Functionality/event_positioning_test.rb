require File.dirname(__FILE__) + '/../test_helper'

class EventPositioningTest < ActiveSupport::TestCase
  fixtures :all
  
  def setup
    UserNotificationProcessor.any_instance.stubs(:notify).returns(nil)
    MiscInstanceMethodQueue.any_instance.stubs(:enqueue_method_call).returns(nil)
  end

  def test_create_scheduled_event_for_existing_events_no_previous_ep
    user = users(:user1)
    se_start_at = 5.day.ago
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    assert !ep
    se1 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se_start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se1.channels << channels('men')
    se1.save
    se1.reload
    
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)    
    assert ep
    assert ep.scheduled_events.collect(&:event_positioning_item_id).include?(se1.id)
  end
  
  def test_create_scheduled_event_for_existing_events_with_no_overlapping_events_from_previous_ep
    user = users(:user1)
    se_start_at = 1.day.ago
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    assert !ep
    se1 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se_start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se1.channels << channels('men')
    se1.save
    se1.reload
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    assert ep
    assert ep.scheduled_events.size, 1
    assert ep.scheduled_events.collect(&:event_positioning_item_id).include?(se1.id)
  end
  
  def test_create_scheduled_event_for_existing_events_with_overlapping_events_from_previous_ep
    user = users(:user1)
    se_start_at = 1.day.from_now
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    assert !ep
    se1 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se_start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se1.channels << channels('men')
    se1.save
    se1.reload
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    assert ep
    assert ep.scheduled_events.size, 1
    assert ep.scheduled_events.collect(&:event_positioning_item_id).include?(se1.id)
    
    se2_start_at = se_start_at + 1.day
    ep2 = EventPositioning.find_by_start_at(se2_start_at - ShoppingEvent.lead_in_period)
    assert !ep2
    se2 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se2_start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se2.channels << channels('men')
    se2.save
    se2.reload
    ep2 = EventPositioning.find_by_start_at(se2_start_at - ShoppingEvent.lead_in_period)
    assert ep2
    
    #ep2 should contain se1 as well cause its end_at > ep2.start_at
    assert ep2.scheduled_events.size, 2
    assert ep2.scheduled_events.collect(&:event_positioning_item_id).include?(se1.id)
    assert ep2.scheduled_events.collect(&:event_positioning_item_id).include?(se2.id)
  end
  
  def test_live_event_positioning
    live_ep = event_positionings(:live)
    assert_equal EventPositioning.live_event_positioning, live_ep
    new_live_ep = EventPositioning.create(:start_at => 1.minute.ago)
    assert_equal EventPositioning.live_event_positioning, new_live_ep
  end  
  
  def test_live?
    live_ep = event_positionings(:live)
    assert_equal EventPositioning.live_event_positioning, live_ep
    assert live_ep.live?
    ep = event_positionings(:first)
    assert !ep.live?
  end

  def test_events_for_channel_for_live_ep
    user = users(:user1)
    live_ep = event_positionings(:live)
    se = shopping_events(:drawing_now)
    cp = generate(:channel_placeholder_event, :start_at => (live_ep.start_at - 10.minutes), :end_at => (live_ep.start_at + 10.days))
    cp.channel_ids = [channels('men').id]
    cp.save
    cp.reload
    assert se.live?(se.channels.first, live_ep)
    assert cp.live?(cp.channels.first, live_ep)
    assert_equal live_ep.scheduled_events.size , 2
    assert live_ep.scheduled_events.collect(&:event_positioning_item).include?(se)
    assert live_ep.events_for_channel(se.channels.first).include?(se)
    assert live_ep.events_for_channel(se.channels.first).include?(cp)
    
    se2 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => (live_ep.start_at - 1.day), :start_at => live_ep.start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se2.channels << channels('men')
    se2.save
    se2.reload
    live_ep.reload
    
    #events_for_channel for any live_ep will not contain any se which is not live right now
    assert !se2.live?(se2.channels.first, live_ep)
    assert_equal live_ep.scheduled_events.size , 3
    assert live_ep.scheduled_events.collect(&:event_positioning_item).include?(se2)
    assert !live_ep.events_for_channel(se.channels.first).include?(se2)
  end  
  
  def test_events_for_channel_for_non_live_ep
    user = users(:user1)
    ep = event_positionings(:first)
    se = shopping_events(:drawing_now)
    se.update_attributes(:start_at => ep.start_at ,:end_at => ep.start_at + 1.day)
    se.reload
    cp = generate(:channel_placeholder_event, :start_at => (ep.start_at - 10.minutes), :end_at => (ep.start_at + 10.days))
    cp.channel_ids = [channels('men').id]
    cp.save
    cp.reload
    ep.reload
    assert !se.live?(se.channels.first, ep)
    assert_equal ep.scheduled_events.size , 2
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(se)
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(cp)
    assert ep.events_for_channel(se.channels.first).include?(se)
    assert ep.events_for_channel(se.channels.first).include?(cp)
    
    se2 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => (ep.start_at - 1.day), :start_at => ep.start_at, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se2.channels << channels('men')
    se2.save
    se2.reload
    ep.reload
    
    assert !se2.live?(se2.channels.first, ep)
    assert_equal ep.scheduled_events.size , 3
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(se2)
    assert ep.events_for_channel(se.channels.first).include?(se)
    assert ep.events_for_channel(se.channels.first).include?(se2)
    assert ep.events_for_channel(se.channels.first).include?(cp)
  end  
  
  def test_remove_invalid_eps
    user = users(:user1)
    se_start_at = Time.now
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    
    assert !ep
    se1 = ShoppingEvent.create(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => se_start_at, :start_at => se_start_at + 1.day, :end_at => 5.days.from_now,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1,:channel_ids => [channels('men').id] )
    se1.save
    se1.reload
    
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    
    se1.update_attributes(:start_at => se_start_at + 2.days , :end_at => se_start_at + 3.days )
    
    ep = EventPositioning.find_by_start_at(se_start_at - ShoppingEvent.lead_in_period)
    ep1 = EventPositioning.find_by_start_at((se_start_at + 2.days) - ShoppingEvent.lead_in_period)
    
    assert ep1
    assert !ep
    
    se2 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => se_start_at, :start_at => se_start_at + 3.days, :end_at => se_start_at + 5.day,
                              :buyer_id => user.id, :owner_id => user.id, :assistant_buyer_id => user.id, :publish_to_site => 1 )
    se2.channels << channels('men')
    se2.save
    se2.reload
    
    ep3 = EventPositioning.find_by_start_at((se_start_at + 3.days) - ShoppingEvent.lead_in_period)
    assert ep3
    
    se2.update_attributes(:start_at => se_start_at + 6.days , :end_at => se_start_at + 8.days )
    ep4 = EventPositioning.find_by_start_at((se_start_at + 3.days) - ShoppingEvent.lead_in_period)
    assert !ep4
    
    ep5 = EventPositioning.find_by_start_at((se_start_at + 6.days) - ShoppingEvent.lead_in_period)
    assert ep5
  end

  def test_replicate_order
    @user = users(:user1)
    
    channel1 = Channel.create(:name => "women", :tab_name => "WOMEN")
    channel2 = Channel.create(:name => "all", :tab_name => "ALL")
    
    se1_start_at = Time.now 

    se1 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se1_start_at, :end_at => se1_start_at + 5.days,
                              :buyer_id => @user.id, :owner_id => @user.id, :assistant_buyer_id => @user.id, :publish_to_site => 1, :channel_ids => [channel1.id, channel2.id, channels('men').id] )
    se1.save
    
    se2 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se1_start_at - 10.minutes, :end_at => se1_start_at + 5.days,
                              :buyer_id => @user.id, :owner_id => @user.id, :assistant_buyer_id => @user.id, :publish_to_site => 1, :channel_ids => [channel1.id, channel2.id, channels('men').id] )
    se2.save
    
    se3 = ShoppingEvent.new(:brand => "Gucci",:brand_line1 => "Gucci",:enter_coming_soon_at => Time.now, :start_at => se1_start_at - 10.minutes, :end_at => se1_start_at + 5.days,
                              :buyer_id => @user.id, :owner_id => @user.id, :assistant_buyer_id => @user.id, :publish_to_site => 1, :channel_ids => [channel1.id, channel2.id, channels('men').id])
    se3.save
    
    se1.reload
    se2.reload
    se3.reload
    
    hep_ep = EventPositioning.find(:first, :conditions => ["start_at = ? and hep is true", se1_start_at - ShoppingEvent.lead_in_period])
    
    assert hep_ep.scheduled_events.collect(&:event_positioning_item).include?(se1)
    assert hep_ep.scheduled_events.collect(&:event_positioning_item).include?(se2)
    assert hep_ep.scheduled_events.collect(&:event_positioning_item).include?(se3)
    
    hep_ep_se1 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se1.id, channel2.id])
    hep_ep_se2 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se2.id, channel2.id])
    hep_ep_se3 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se3.id, channel2.id])
    assert 0, hep_ep_se1.position
    assert 0, hep_ep_se2.position
    assert 0, hep_ep_se3.position

    hep_ep_se12 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se1.id, channels('men').id])
    hep_ep_se22 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se2.id, channels('men').id])
    hep_ep_se32 = hep_ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se3.id, channels('men').id])
    assert 0, hep_ep_se12.position
    assert 0, hep_ep_se22.position
    assert 0, hep_ep_se32.position
    
    ep = EventPositioning.find_by_start_at(se1_start_at - ShoppingEvent.lead_in_period)
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(se1)
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(se2)
    assert ep.scheduled_events.collect(&:event_positioning_item).include?(se3)
    
    ep_se1 = ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se1.id, channel1.id])
    ep_se2 = ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se2.id, channel1.id])
    ep_se3 = ep.scheduled_events.find(:first, :conditions => ["event_positioning_item_id =? and channel_id =? and event_positioning_item_type = 'ShoppingEvent'", se3.id, channel1.id])
    
    ep_se1.update_attribute('position',3)
    ep_se2.update_attribute('position',1)
    ep_se3.update_attribute('position',2)
    
    EventPositioning.replicate_order(hep_ep, 'default')
    assert 3, hep_ep_se12.position
    assert 1, hep_ep_se22.position
    assert 2, hep_ep_se32.position
    
    assert 0, hep_ep_se1.position
    assert 0, hep_ep_se2.position
    assert 0, hep_ep_se3.position
    
    EventPositioning.replicate_order(hep_ep, 'men')
    assert 3, hep_ep_se1.position
    assert 1, hep_ep_se2.position
    assert 2, hep_ep_se3.position
  end
    
end
