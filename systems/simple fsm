#region		<Basic FSM (flat state machine)>

// Lowkey could just edit the HFSM to allow the states to be treated as 
// normal flat states but then you would have to define transitions this
// is if you don't feel like doing allat.

function state_fsmSYS(_name) constructor
{
	
	name = _name;
	onEnter = undefined;
	onUpdate = undefined;
	onExit = undefined;
	
	
	showDebug = false;
	
	
	if showDebug show_debug_message($"State created: {name}");
	
		
	setOnEnterCallback = function(_func)
	{
		onEnter = _func;
	}
		
	setOnUpdateCallback = function(_func)
	{
		onUpdate = _func;
	}
		
	setOnExitCallback = function(_func)
	{
		onExit = _func;
	}
	
	
	
	doOnEnterCallback = function()
	{
		if onEnter == undefined return;
		onEnter();
	}
	
	doOnUpdateCallback = function()
	{
		//show_debug_message("UPDATING 123");
		if onUpdate == undefined return;
		//show_debug_message("onUpdate");
		onUpdate();
		
	}
	
	doOnExitCallback = function()
	{
		if onExit == undefined return;
		onExit();
	}
	
}
	

function fsmSYS(_name="simple fsm") constructor
{
	
	name = _name;
	states = {};
	
	currentState = undefined;
	
	showDebug = false;
	
	addState = function(_state)
	{
		if struct_exists(states, _state.name) return;
		
		if showDebug show_debug_message($"Add State: {_state.name}");
		
		struct_set(states, _state.name, _state);
	}
	
	addStatesByArray = function(_states)
	{
		for(var i=0; i<array_length(_states); i++)
		{
			addState(_states[i]);
		}
	}
	
	setState = function(_stateName)
	{
		
		var _state = struct_get(states, _stateName);
		if _state == undefined return;
		
		if showDebug show_debug_message($"Set State to: {_stateName}");
		
		if currentState != undefined
		{
			currentState.doOnExitCallback();
		}
		
		currentState = _state;
		currentState.doOnEnterCallback();
		
	 	//if showDebug show_debug_message($"Setting the state to: {currentState.name}");
		
	}
	
	inState = function(_stateName)
	{
		if currentState == undefined return false;
		
		return (currentState.name == _stateName);
	}
	
	
	run = function()
	{
		if currentState == undefined return;
		
		currentState.doOnUpdateCallback();
	}
	
}

#endregion
