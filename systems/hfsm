
#region		<HFSM>

function fireEvent(fsm, eventName)
{
	// add a return to state identifier like: return_state
	
	
	var showDebug = false;
	
	if showDebug show_debug_message($"Firing Event: {eventName}");
	
    var state = fsm.currentState;
    var subState = state.currentSubState;
    var transitions = state.transitions;
	

    for (var i = 0; i < array_length(transitions); i++)
    {
        var t = transitions[i];

        // Check if the event matches
        if (t.event != eventName) continue;

        // Handle 'from' being a string, array, or "*"
        var fromMatch = false;

        if (t.from == "*")
		{
            fromMatch = true;
        }
        else if (is_array(t.from))
		{
            fromMatch = array_contains(t.from, subState.name);
        }
        else
		{
            fromMatch = (subState.name == t.from);
        }

        if (fromMatch)
        {
            // Change state if needed
            if (fsm.currentState.name != t.toState)
            {
                fsm.changeState(t.toState);
            }

            // Change substate
            var nextSubState = struct_get(fsm.currentState.subStates, t.toSubState);
            fsm.currentState.changeSubState(nextSubState);
			
			if showDebug show_debug_message($"Found a transition from: {subState.name}");
			
            return true;
        }
		
    }

	//show_debug_message($"Cannot Find the transition to: {transitions}");
	if showDebug show_debug_message($"Cannot find a transition from: {subState.name}");

    return false;
}



function transitionHFSM(_event, _from, _toState, _toSubState) constructor
{
	
	//event: "jump_pressed",
    //from: ["walk"],
    //toState: "Air",
    //toSubState: "jump"
	
	event = _event;
	from = _from; // array
	toState = _toState;
	toSubState = _toSubState;
	
	//if !is_array(from) show_debug_message($"Transition: {self}. from is wrong it needs to be a array.");
	
	
	
	
	toString = function()
	{
		return $"(Event: {event})";
	}
	
}



function controllerHFSM(_name="Controller") constructor
{
	name = _name;
	showDebug = false;
	
	states = {};
	currentState = undefined;
	defaultState = undefined;
	
	
	addState = function(_state, _defaultState=false)
	{
		var _stateName = _state.name;
		
		if struct_exists(states, _stateName) return;
		
		struct_set(states, _stateName, _state);
		
		if showDebug show_debug_message($"Added State [{_stateName}] to {name} FSM.");
		
		
		if (_defaultState) 
		{
			
			defaultState = _state;
			currentState = defaultState;
			
			if showDebug show_debug_message($"Default State for {name} FSM is {_stateName}");
		}
		
	}
	
	
	addStatesByArray = function(_stateArray, _defaultStateIndex=0)
	{
		for(var i=0; i<array_length(_stateArray); i++)
		{
			var _state = _stateArray[i];
			
			if (_defaultStateIndex == i)
			{
				addState(_state, true);
				
			} else {
				addState(_state);
			}
			
		}
		
	}
	
	
	changeState = function(_newState)
	{
		
		
		if is_struct(_newState)
		{
			if showDebug show_debug_message($"Changing the current sub state in State: {name}  [from: {currentState.name} to: {_newState.name}].");
			currentState = _newState;
		}
		
		if is_string(_newState)
		{
			var _state = struct_get(states, _newState)
			
			if is_undefined(_state)
			{
				
				if showDebug show_debug_message($"Cant find the sub state: {_newState}");
			}
			
			if showDebug show_debug_message($"Changing the current sub state in State: {name}  [from: {currentState.name} to: {_newState}].");
			
			currentState = _state;
		}
	}
	
	inState = function(_stateName)
	{
		if currentState == undefined return undefined;
		
		return (currentState.name == _stateName);
		
	}
	
	step = function()
	{
		if (currentState != undefined)
		{
			// State-level logic (optional - if you add onUpdateCallback to stateFSMs later)
			if (!is_undefined(currentState.onUpdateCallback))
			{
				currentState.onUpdateCallback(); 
				
			}
			

			// Substate-level logic
			if (currentState.currentSubState != undefined)
			{
				var _sub = currentState.currentSubState;

				if (!is_undefined(_sub.onUpdateCallback))
				{
					_sub.onUpdateCallback();
					
				}
			}
		} else {
			show_debug_message("CURRENT STATE IS UNDEFINED");
		}
	}


	print = function()
	{
		var _stateNames = struct_get_names(states);
		
		for(var i=0; i<array_length(_stateNames); i++)
		{
			var _stateName = _stateNames[i];
			
			var _state = struct_get(states, _stateName);
			
			_state.printInfo();
		}
		
	}
	
}


// States i.e. ground (running, idle, walk), air (jumping, fall), 
function stateHFSM(_name) constructor
{
	name = _name;
	showDebug = false;
	
	subStates = {};
	currentSubState = undefined;
	defaultSubState = undefined;
	
	transitions = [];
	
	onUpdateCallback = undefined;
	
	setUpdateCallback = function(_callback)
	{
		onUpdateCallback = _callback;
	}
	
	
	addSubState = function(_state, _defaultState=false)
	{
		var _stateName = _state.name;
		
		if struct_exists(subStates, _stateName) return;
		
		struct_set(subStates, _stateName, _state);
		
		if showDebug show_debug_message($"Added Sub State: [{_stateName}] to {name} State.");
		
		
		if (_defaultState) 
		{
			
			defaultSubState = _state;
			currentSubState = defaultSubState;
			
			
			//currentSubState.onEnterCallback();
			
			if showDebug show_debug_message($"Default State for Sub State: {name} is {_stateName} now.");
		}
		
	}
	
	
	addSubStatesByArray = function(_stateArray, _defaultStateIndex=0)
	{
		for(var i=0; i<array_length(_stateArray); i++)
		{
			var _state = _stateArray[i];
			
			if (_defaultStateIndex == i)
			{
				addSubState(_state, true);
				
			} else {
				addSubState(_state);
			}
			
			
		}
		
	}
	
	
	addTransition = function(_eventName, _from, _toState, _toSubState)
	{
		
		var _t = new transitionHFSM(_eventName, _from, _toState, _toSubState);
		
		if !array_contains(transitions, _t)
		{
			array_push(transitions, _t);
			
			if showDebug show_debug_message($"Transition: {_t.event} added to {name} State.");
			
		} else {
			if showDebug show_debug_message($"Transition {_t.event} already exists.");
		}
		
	}
	
	addBidirectionalTransition = function(_eventName, _from, _toState, _toSubState)
	{
		//addTransition();
		//addTransition();
	}
	
	
	
	inSubState = function(_stateName)
	{
		if currentSubState == undefined return undefined;
		
		return (currentSubState.name == _stateName);
		
	}
	
	
	changeSubState = function(_newState)
	{
		//show_debug_message(string(currentSubState));
	    // Call exit on the old one
	    if (currentSubState != undefined && !is_undefined(currentSubState.onExitCallback)) currentSubState.onExitCallback();

	    // Swap in the new one
	    var next = is_struct(_newState)
	        ? _newState
	        : struct_get(subStates, _newState);

	    currentSubState = next;

	    // Call enter on the new one
	    if (!is_undefined(currentSubState.onEnterCallback)) 
		{
			if showDebug show_debug_message($"Doing On Enter Callback for sub-state: {currentSubState.name}");
			currentSubState.onEnterCallback();
		}
	}


    printInfo = function()
    {
        show_debug_message("--- State Info ---");
        show_debug_message($"State Name: {name}");

        if (currentSubState != undefined) {
            show_debug_message($"Current Substate: {currentSubState.name}");
        } else {
             show_debug_message("Current Substate: None");
        }

        show_debug_message("Transitions:");
        if (array_length(transitions) == 0)
		{
            show_debug_message("  No transitions defined.");
        } else {
            for (var i = 0; i < array_length(transitions); i++)
			{
                var t = transitions[i];

                // --- Modified formatting for 'from' array ---
                var from_str = "";
                if (is_array(t.from))
				{
                    from_str = "[";
                    for (var j = 0; j < array_length(t.from); j++)
					{
                        from_str += string(t.from[j]); // Manually stringify each element
                        if (j < array_length(t.from) - 1)
						{
                            from_str += ", "; // Add separator
                        }
                    }
                    from_str += "]";
                } else {
                    from_str = string(t.from); // Handle non-array 'from' values
                }
                // -------------------------------------------
				show_debug_message("");
                show_debug_message($"  ~ Event: {t.event}\n" +
                                   $"	  From: {from_str}\n" +
                                   $"	  To State: {t.toState}\n" +
                                   $"	  To Substate: {t.toSubState}");
            }
        }


        show_debug_message("Substate Tree:");
        var substate_names = struct_get_names(subStates);
        if (array_length(substate_names) == 0) {
             show_debug_message("  No substates defined.");
        } else {
            for (var i = 0; i < array_length(substate_names); i++) {
                var sub_name = substate_names[i];
                var prefix = (sub_name == currentSubState.name) ? "* " : "- "; // Mark current substate
                show_debug_message($"  {prefix}{sub_name}");
            }
        }
         show_debug_message("------------------");
    }
    // -----------------------------

	
	
}


// Actual Behaviors
function subStateHFSM(_name) constructor
{
	name = _name;
	onEnterCallback = undefined;
	onUpdateCallback = undefined;
	onExitCallback = undefined;
	
	setEnterCallback = function(_callback)
	{
		onEnterCallback = _callback;
		//show_debug_message($"Set onEnterCallback for Sub-State: {name}");
	}
	
	setUpdateCallback = function(_callback)
	{
		onUpdateCallback = _callback;
	}
	
	setExitCallback = function(_callback)
	{
		onExitCallback = _callback;
	}
}

#endregion
