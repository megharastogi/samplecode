# Each EP has scheduled_events which represent Event in that particular EP
# EP are of two type "hep" and "default", There are always two copies of same EP but there type is different 
# Scheduled Events within an EP can be sorted
# EP of hep type can copy the scheduled events arrangement form EP of default type
module Admintools
  class EventPositioningsController < BaseController
    helper AdminHelper

    def index
      @event_positionings = EventPositioning.find(:all,:conditions => ["start_at >= ? and start_at <= ? ", Time.now, Time.now + 5.days], :order => 'start_at, hep')
      @event_positionings.insert(0,EventPositioning.live_event_positioning(:hep)) if EventPositioning.live_event_positioning(:hep)
      @event_positionings.insert(0,EventPositioning.live_event_positioning) if EventPositioning.live_event_positioning
    end

    def edit
      @event_positioning = EventPositioning.find_by_id(params[:id])
    end 
    
    #this method replicates the order of events from previous EP
    def replicate_order
      ep = EventPositioning.find_by_id(params[:id])
      if params[:copy_type]
        EventPositioning.replicate_order(ep, params[:copy_type]) 
        #if EP which is copying the position is a live EP then clear the cache
        sweep_event_data_feed if ep.live?(:hep)
      end  
      redirect_to edit_admin_event_positioning_path(ep)
    end  

    def sort_events      
      ep = EventPositioning.find_by_id(params[:id])
      channel = Channel.find_by_id(params[:channel_id])
      if params["channel_list_#{channel.id}"].present?
        channel_list = params["channel_list_#{channel.id}"] 
        render :update do |page|
          page.replace("save_channel_#{channel.id}", (link_to_remote  (ep.live?  ? 'Save/Publish': 'Save/Preview'), :url => sort_events_admin_event_positioning_path(:id => params[:id], :channel_id => channel.id),
          :with => "'channel_list_save_#{channel.id}=' + [#{channel_list.join(',')}]", :html => {:id => "save_channel_#{channel.id}"}))
        end
      else
        params["channel_list_save_#{channel.id}"].split(',').each_with_index do |id, index|  
          ScheduledEvent.update_all(["position = ?", index + 1], ["id = ? and channel_id = ?", id, channel.id])
        end
        ep.update_attribute('ordered',true) if params["channel_list_save_#{channel.id}"].present?        
        refresh_latest_for_channel(channel) if ep.live?(:default)
        sweep_event_data_feed if ep.live?(:hep)
        render :update do |page|
          page.replace_html("channel_list_#{channel.id}",:partial => "events_lists" , :locals => {:channel => channel,:event_positioning_id => params[:id]})
          page.replace("save_channel_#{channel.id}", (link_to_remote (ep.live? ? 'Save/Publish': 'Save/Preview'), :url => sort_events_admin_event_positioning_path(:id => params[:id], :channel_id => channel.id),
          :with => "'channel_list_save_#{channel.id}=' + []", :html => {:id => "save_channel_#{channel.id}"}))
          if ep.hep
            page << "window.open('#{preview_latest_hep_events_url(:event_positioning_id => params[:id],:channel_id => channel.id, :force_cache_write => 1)}','preview_channel_window');"
          else  
            page << "window.open('#{event_positioning_preview_events_url(:event_positioning_id => params[:id],:channel_id => channel.id, :force_cache_write => 1)}','preview_channel_window');"
          end
        end
      end 
    end  

  end  
end