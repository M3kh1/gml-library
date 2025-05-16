/*



global.ebus = new PubSubSystem("MainEventBus");
#macro EBUS global.ebus 

DONT just make it a macro or it will count the new PubSubSystem as a seprate inst under the hood


*/



global.ebus = new PubSubSystem("MainEventBus");
#macro EBUS global.ebus 


function PubSubSystem(bus_name = "event_bus") constructor
{
	name = bus_name;
	event_listeners = {};
	event_queue = [];
	allow_debug = false; // Turn it off unless u want the Console to be flooded
	

	#region --- Primary Functions ---
	
	function publish(event_name, _event_data = {})
	{
		if (struct_exists(event_listeners, event_name))
		{
			var subscribers = event_listeners[$ event_name];
		
			for (var i = 0; i < array_length(subscribers); i++)
			{
				var listener = subscribers[i];
				listener.callback(_event_data);
			
				if (listener.once)
				{
					array_delete(subscribers, i, 1);
					i--;
					
					show_debug_message("pluh "+string(listener));
				}

				if (allow_debug) show_debug_message($"Publishing Event: -> ({event_name} | Data: {_event_data})");
			}
		}
		else
		{
			if (allow_debug) show_debug_message($"Publish Failed: {name} - {event_name} does not exist");
		}
	}

	function subscribe(event_name, callback_function, priority = 0, once = false)
	{
		if (!struct_exists(event_listeners, event_name))
		{
			struct_set(event_listeners, event_name, []);
		}

		var subscribers = struct_get(event_listeners, event_name);
		

		// Prevent duplicates
		for (var i = 0; i < array_length(subscribers); i++)
		{
			if (subscribers[i].callback == callback_function)
			{
				if (allow_debug) show_debug_message($"Already subscribed: {name} - {event_name}");
				return;
			}
		}

		var listener = {
			callback: callback_function,
			time_subscribed: current_time,
			priority: priority,
			once: once
		};

		array_push(subscribers, listener);
		
		
		// Ex: Sort by time added 1st in 1st out
		//array_sort(subscribers, function(a, b) {
		//	return a.time_subscribed < b.time_subscribed;
		//});
	
		// Sort by priority acending (higher runs first)
		array_sort(subscribers, function(a, b) {
			return a.priority > b.priority;
		});
		
		if (allow_debug) show_debug_message($"Subscribed: {name} - {event_name} | priority: {priority}");
	}

	#endregion

	#region -- Secondary Functions ---
	
	function unsubscribe(event_name, callback_function)
	{
		if (variable_struct_exists(event_listeners, event_name))
		{
			var subscribers = variable_struct_get(event_listeners, event_name);
			var index = array_get_index(subscribers, callback_function);

			if (index != -1)
			{
				array_delete(subscribers, index, 1);
				if (array_length(subscribers) == 0)
				{
					variable_struct_remove(event_listeners, event_name);
					if (allow_debug) show_debug_message($"Cleaned up event: {name} - {event_name}");
				}
				else
				{
					variable_struct_set(event_listeners, event_name, subscribers);
				}
			}
		}
	}

	function unsubscribeAll(event_name = undefined)
	{
		if (event_name == undefined)
		{
			event_listeners = {};
			if (allow_debug) show_debug_message($"Unsubscribed all events: {name}");
		}
		else if (struct_exists(event_listeners, event_name))
		{
			struct_remove(event_listeners, event_name);
			if (allow_debug) show_debug_message($"Unsubscribed all listeners for: {name} - {event_name}");
		}
	}
	
	#endregion

	#region - Helper Functions -
	
	function hasListeners(event_name)
	{
		var exists = struct_exists(event_listeners, event_name);
		if (allow_debug) show_debug_message($"[{name}] Event '{event_name}' has listeners? {exists}");
		return exists;
	}

	function debug_listeners()
	{
		var keys = struct_get_names(event_listeners);
		
		show_debug_message("== EventBus Subscriptions ==");
		for (var i = 0; i < array_length(keys); i++)
		{
			var key = keys[i];
			var listeners = struct_get(event_listeners, key);
			show_debug_message($"- {key}: {array_length(listeners)} listener(s)");
		}
	}
	
	#endregion
	
}


