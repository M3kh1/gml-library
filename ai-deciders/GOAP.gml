

// When creating goap actions think:
/*
	GOAP gets you to the party.
	The party handles itself.
	
	GOAP is about getting into the right context.

	The agent doesn’t plan every bite of food with GOAP —
	It just planned to get to the fridge.


	Add These:
	
	one thing im thinking is 
	setTimer
	setTargetPosition() or setTargetObject()
	for animations maybe a animation manager?
	
*/

randomize();


function structToArray(_struct)
{
	var _finalArray = [];
		
	var _keys = struct_get_names(_struct);
		
	for(var i=0; i<array_length(_keys); i++)
	{
		array_push(_finalArray, _struct[$ _keys[i]]);
	}
		
	return _finalArray;
		
}
	

function hashState(_state)
{
	//var keys = struct_get_names(_state);
	//array_sort(keys, true); // VERY IMPORTANT: Sort keys alphabetically
	//var str = "{";
	//for (var i = 0; i < array_length(keys); i++)
	//{
	//    var key = keys[i];
	//    var value = _state[$ key];
	//    str += string(key) + ":" + string(value); // Convert key and value to string consistently
	//    if (i < array_length(keys) - 1)
	//	{
	//        str += ",";
	//    }
	//}
	//str += "}"; // Add delimiters to the start/end for clarity
	//return str;
	
	return string(_state);
}


function brainGOAP() constructor
{
	actions = {};
	goals = {};
	sensors = {};
	
	targetGoal = undefined;
	
	Log = new Logger("GOAP/Brain", true, [LogLevel.debug, LogLevel.warning]);
	
	planner = new plannerGOAP(actions); 
	plan = [];
	currentActionIndex = 0;  // init action index
	
	
	
	#region		- Primary User Functions -
	
	addAction = function(_action)
	{
		
		var _name = _action.name;
		
		if struct_exists(actions, _name)
		{
			Log.logWarning($"Action ({_name}) Exists Already.");
			return;
		}
		
		struct_set(actions, _name, _action);
		
	}
	
	addActionsByArray = function(_actions)
	{
		for(var i=0; i<array_length(_actions); i++)
		{
			var _a = _actions[i];
			addAction(_a);
		}
	}
	
	addGoal = function(_goal)
	{
		
		var _name = _goal.name;
		
		if struct_exists(goals, _name)
		{
			Log.logWarning($"Goal ({_name}) Exists Already.");
			return;
		}
		
		struct_set(goals, _name, _goal);
		
	}
	
	addGoalsByArray = function(_goals)
	{
		for(var i=0; i<array_length(_goals); i++)
		{
			var _g = _goals[i];
			addGoal(_g);
		}
	}
	
	registerSensor = function(_name, _func)
	{
		
		if struct_exists(sensors, _name)
		{
			Log.logWarning($"Sensor ({_name}) Exists Already.");
			return;
		}
		
		struct_set(sensors, _name, _func);
		
	}
	
	getSensorData = function(_name)
	{
		var _sensor = struct_get(sensors, _name);
		
		if _sensor == undefined
		{
			Log.logWarning($"Sensor: {_name} DNE.");
			return false;
		}
		
		return _sensor();
		
	}
	
	setTargetGoal = function(_goalName)
	{
		
		//show_debug_message("Goals: "+string(goals));
		
		if !struct_exists(goals, _goalName)
		{
			Log.logWarning("Set target goal failed. Goal DNE.");
			return;
		}
		
		targetGoal = struct_get(goals, _goalName);
		
	}
	

	#endregion

	#region		[Base Helper Functions]
	
	
	initPlan = function(_plan=[])
	{
		plan = _plan;
		currentActionIndex = 0;
	}
	
	
	generatePlan = function()
	{
	    var _startTime = current_time;
    
	    var current_state = captureSensorSnapshot();
	    var goal_state = targetGoal.conditions;
	    var available_actions = actions;
		
		
	    var new_plan = planner.createPlan(current_state, goal_state);
		
	    var plan_valid = (array_length(new_plan) > 0);

	    if (!plan_valid)
	    {
			Log.logDebug("No valid plan could be generated.");
			
	        return false;
	    }

	    initPlan(new_plan); // Update plan with the new one

	    var _endTime = (current_time - _startTime);
		
		
		Log.logDebug($"New plan: ({array_length(new_plan)}) generated successfully in ({_endTime} ms | {_endTime/1000} s) so abt. ({round(_endTime/(16.67))} frames).");
		
		printPlan();
		
	    return true;
	}
	
	captureSensorSnapshot = function()
	{
		var _snap = {};
		
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _name = _sensor_names[i];
			
			var _val = struct_get(sensors, _name);
			
			var _funct_ran = _val();
			
			struct_set(_snap, _name, _funct_ran);
		}
		
		return _snap;
		
	}

	printPlan = function()
	{
		var _len = array_length(plan);
		
		if (_len <= 0)
		{
			show_debug_message("Print Plan - Plan is empty.");
			return;
		}
		
		show_debug_message($"({_len}) ~ Printing Plan:");
		
		//show_debug_message(string(plan));
		
		for(var a=0; a<_len; a++)
		{
			
			var _act = plan[a];
			show_debug_message($"{a+1}: {_act}");
			
		}
		
	}
	

	drawSensors = function(_x, _y)
	{
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _sensor = _sensor_names[i];
			var _val = struct_get(sensors, _sensor);
			
			draw_text(_x, (_y-(20*i)), $"Sensor: {_sensor} ~ {_val()}");
			
		}
		
	}
	
	#endregion
	
	#region		<Run the Plan>
	
	LogPlanExe = new Logger("GOAP/Brain/Plan-Executor", true, [LogLevel.warning]);
	
	checkReactionDelta = function(startState, endState, expectedChanges)
	{
	    var keys = struct_get_names(expectedChanges);

	    for (var i = 0; i < array_length(keys); i++)
	    {
	        var key = keys[i];

	        if (!struct_exists(startState, key) || !struct_exists(endState, key))
	        {
	            show_debug_message("Missing key: " + key);
	            return false;
	        }

	        var expected = expectedChanges[$ key];
	        var startVal = startState[$ key];
	        var endVal = endState[$ key];

	        // If expected is bool, just compare directly
	        if (is_bool(expected))
	        {
	            if (endVal != expected) return false;
	        }
	        else
	        {
	            var delta = endVal - startVal;
	            if (delta != expected && endVal != expected) return false;
	        }
	    }

	    return true;
	}
	
	goalComplete = function()
	{
	    //show_debug_message("[GOAP] Goal complete!");
		LogPlanExe.logInfo($"Plan Completed For Goal: {targetGoal.name}");
	    generatePlan();
	}

	handleFailure = function()
	{
	    //show_debug_message("[GOAP] Plan failed.");
	    generatePlan();
		
	}

	handleInterruption = function()
	{
	    //show_debug_message("[GOAP] Plan interrupted. Replanning...");
	    generatePlan();
	}
	
	
	hasReachedTarget = function(target)
	{
	    var target_x, target_y;
		var tolerance = 0;

	    // Handle both object and position input
	    if (instance_exists(target))
	    {
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to hasReachedTarget()");
	        return true;
	    }

	    var dist = point_distance(x, y, target_x, target_y);
	    return (dist <= tolerance); // Adjust tolerance as needed
	}

	
	moveTowardTarget = function(target, spd = 2)
	{
	    var target_x, target_y;

	    if (instance_exists(target))
	    {
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to moveTowardTarget()");
	        return;
	    }

	    var angle = point_direction(x, y, target_x, target_y);
	    x += lengthdir_x(spd, angle);
	    y += lengthdir_y(spd, angle);
	}


	doPlan = function()
	{
	    // 1. Is the Goal Already Achieved?
	    if (planner.checkKeysMatch(targetGoal.conditions, captureSensorSnapshot()))
	    {
			LogPlanExe.logInfo($"Target Goal: {targetGoal.name} Already Completed.");
	        return; // No plan needed
	    }

	    // 2. Is There a Valid Plan?
	    if (plan == undefined || array_length(plan) == 0)
	    {
			LogPlanExe.logWarning("Plan isnt valid.");
	        generatePlan();
	        return;
	    }

	    // 3. Are we done with the plan?
	    if (currentActionIndex >= array_length(plan))
	    {
	        goalComplete(); // Plan success
	        return;
	    }

	    // 4. Get the Current Action
	    var _actionName = plan[currentActionIndex];

	    if (!struct_exists(actions, _actionName))
	    {
			LogPlanExe.logWarning($"Action '{_actionName}' does not exist.");
	        handleFailure(); // Exit or replan
	        return;
	    }

	    var _action = actions[$ _actionName];

	    // 5. Preconditions must hold
	    if (!planner.checkKeysMatch(_action.conditions, captureSensorSnapshot()))
	    {
			LogPlanExe.logDebug($"Preconditions failed for '{_actionName}'. Replanning...");
	        generatePlan();
	        return;
	    }


		// 6. Target: handle MoveBeforePerforming gate
	    if (_action.targetMode == actionTargetMode.MoveBeforePerforming)
	    {
	        if (!hasReachedTarget(_action.target))
	        {
	            moveTowardTarget(_action.target);
	            return; // Don't execute until we arrive
	        }
	    }
	    else if (_action.targetMode == actionTargetMode.PerformWhileMoving)
	    {
	        moveTowardTarget(_action.target);
	    }

	    // 6. If action hasn't started, take snapshot
	    _action.startSnapshot = captureSensorSnapshot();
	    
		

	    // 7. Execute the action 
		_action.execute();
		

		// 8. Check for completion first
		if (checkReactionDelta(_action.startSnapshot, captureSensorSnapshot(), _action.reactions))
		{
			LogPlanExe.logInfo($"[GOAP] '{_actionName}' completed.");
		    currentActionIndex++;

		    // Optional: clear snapshot so action resets if reused
		    _action.startSnapshot = undefined;

		    if (currentActionIndex >= array_length(plan))
		    {
		        goalComplete();
		    }

		    return; // Exit early so no interruption is falsely detected
		}

		// 9. Then check for interruption
		if (_action.isInterruptible && !planner.checkKeysMatch(_action.conditions, captureSensorSnapshot()))
		{
			LogPlanExe.logInfo($"[GOAP] '{_actionName}' was interrupted.");
		    handleInterruption();
		    return;
		}

	}


	#endregion
	
	

}



function plannerGOAP(_allActions) constructor
{
	planLog = new Logger("GOAP/Planner", true, [LogLevel.info, LogLevel.warning, LogLevel.profile]);
	
    plan_cache = {};			// Cache for previously generated plans
	heuristic_cache = {};
	simulation_cache = {};
	
	allActions = _allActions;
	
	conditionGraph = undefined;	// init ONCE
	reactionGraph = undefined; // init ONCE
	
	actionCostData = undefined; // init ONCE
	
	
	#region	--- Helper Functions ---


	setupActionData = function()
	{
		if (is_undefined(conditionGraph) and is_undefined(reactionGraph))
		{
			var _graphs = planLog.doProfile("buildDependencyMaps",buildDependencyMaps);
			conditionGraph = _graphs.con;
			reactionGraph = _graphs.react;
			
			actionCostData = calculateMinActionCostsHeuristicData();
		}
		
	}
	
	
	
	checkKeysMatch = function(_conditions_or_reactions, _state_to_check) // Renamed parameters for clarity
	{
	    var _keys = struct_get_names(_conditions_or_reactions); // Iterate keys from the conditions/reactions set
	    for (var i = 0; i < array_length(_keys); i++)
	    {
	        var _key = _keys[i];
	        // Call keyMatches with STATE first, then CONDITIONS/REACTIONS
	        if (!keyMatches(_state_to_check, _conditions_or_reactions, _key)) 
	        { 
	            return false; // If ANY key doesn't match, the whole set doesn't match
	        }
	    }
	    return true; // If all keys matched, the whole set matches
	}

	
	
	keyMatches = function(_state_to_check, _target_struct, _key_to_check)
	{
	    // Check if the key exists in the state we are checking against
	    if (!struct_exists(_state_to_check, _key_to_check))
	    {
	        // If the key isn't in the state, the condition isn't met.
	        // planLog.logDebug($"keyMatches: Key '{_key_to_check}' not found in state."); // Optional debug
	        return false;
	    }

	    var state_value = _state_to_check[$ _key_to_check];
	    var condition_definition = _target_struct[$ _key_to_check]; // Get the condition definition from the target struct (either goal or action conditions)


	    // --- Handle Numerical Conditions (Condition definition is a struct with comparison and value) ---
	    if (is_struct(condition_definition))
	    {
	        var operator = condition_definition.comparison;
	        var target_value = condition_definition.value;

	        // Ensure both state value and target value are numeric for numerical comparison
	        if (!is_numeric(state_value) || !is_numeric(target_value))
	        {
	            // If either isn't numeric, the condition can't be numerically matched.
	            planLog.logWarning($"keyMatches: Numerical comparison for key '{_key_to_check}' requires numeric values. State is '{string(state_value)}', Target is '{string(target_value)}'.");
	            return false;
	        }

	        var result = false; // Initialize the boolean result for the comparison

	        // Perform the numerical comparison based on the operator string
	        switch (operator)
	        {
	            case ">=": result = state_value >= target_value; break;
	            case "<=": result = state_value <= target_value; break;
	            case ">":  result = state_value > target_value; break;
	            case "<":  result = state_value < target_value; break;
	            case "=":  result = state_value == target_value; break;

	            default:
	                planLog.logWarning($"keyMatches: Unknown comparison operator '{operator}' for key '{_key_to_check}'.");
	                return false; // An unknown operator means the condition is not met
	        }
			
			if (!result)
			{
				//show_debug_message("keyMatches: Numeric condition failed for key '" + string(_key_to_check) + "'. State: " + string(state_value) + " " + string(operator) + " " + string(target_value));
			}
			
	        return result; // Return the actual boolean result of the numerical comparison
	    }
	    // --- Handle Simple Boolean/Value Conditions (Condition definition is a direct value) ---
	    else
	    {
	        var condition_value = condition_definition;

	        // For simple conditions, the state value must exactly match the condition value.
	        // We already checked if the key exists in the state.
	        return state_value == condition_value;
	    }
	}
	
	
	
	// Generate a unique cache key for a given start state and goal conditions.
	// This key is used to store and retrieve plans from the plan_cache.
	generateCacheKey = function(_startState, _goalConditions)
	{
		// Combine the hash of the start state and the hash of the goal conditions.
		// Ensure goal conditions are also hashed consistently (e.g., sort keys).
		var start_state_hash = hashState(_startState);
		var goal_conditions_hash = hashState(_goalConditions); // Assuming goal conditions are a struct

		return start_state_hash + "|" + goal_conditions_hash; // Use a separator that won't appear in hashes
	}
	
	
	
	// --- Simulate applying an action's reactions to a state ---
    simulateReactions = function(_state, _reactions)
    {
		//show_debug_message("simulating");
		
        var new_state = variable_clone(_state); // Start with a copy of the current state
        var reaction_keys = struct_get_names(_reactions);

        for (var i = 0; i < array_length(reaction_keys); i++)
        {
            var key = reaction_keys[i];
            var reaction_value = _reactions[$ key];

            // Check if the state variable exists before attempting to modify it
            // If the reaction is to add a new state variable, add it.
            if (!struct_exists(new_state, key))
			{
                 new_state[$ key] = reaction_value;
                 planLog.logDebug($"Simulating Reaction: Added new key '{key}' with value '{string(reaction_value)}'");
                 continue; // Move to the next reaction
            }

            // --- CORRECTED LOGIC FOR APPLYING REACTIONS ---
            // Prioritize setting boolean values if the reaction value is a boolean.
            if (is_bool(reaction_value))
            {
                 new_state[$ key] = reaction_value; // Direct assignment for booleans
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to boolean '{string(reaction_value)}'.");
            }
            // Handle numerical changes (+N, -N) ONLY if the reaction value is numeric AND the state value is numeric
            else if (is_numeric(reaction_value) && is_numeric(new_state[$ key]))
            {
                new_state[$ key] += reaction_value; // Apply the numerical change (add or subtract)
                planLog.logDebug($"Simulating Reaction: Key '{key}' numerical change by {string(reaction_value)}. New value: {string(new_state[$ key])}");
            }
            // For all other cases (strings, or numbers for non-numeric state properties, or direct number assignments),
            // treat it as a direct SET value.
            else
            {
                 new_state[$ key] = reaction_value; // Direct assignment
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to '{string(reaction_value)}'.");
            }


        }
        return new_state;
    }
	
	
	simulatePositiveReactions = function(_state, _reactions)
	{
	    var new_state = variable_clone(_state); // Start with a copy of the current state
	    var reaction_keys = struct_get_names(_reactions);

	    for (var i = 0; i < array_length(reaction_keys); i++)
	    {
	        var key = reaction_keys[i];
	        var reaction_value = _reactions[$ key];

	        // --- Logic to define and apply "positive" reactions only ---

	        // 1. Adding a new key (always considered positive if it's being added)
	        if (!struct_exists(new_state, key))
	        {
	            new_state[$ key] = reaction_value;
	            planLog.logDebug($"Simulating Positive Reaction: Added new key '{key}' with value '{string(reaction_value)}'.");
	            continue;
	        }

	        // 2. Boolean values: Only apply if setting to 'true'
	        if (is_bool(reaction_value))
	        {
	            if (reaction_value == true) // Only apply if the reaction is to set to true
	            {
	                new_state[$ key] = reaction_value;
	                planLog.logDebug($"Simulating Positive Reaction: Key '{key}' set to boolean 'true'.");
	            }
	            else
	            {
	                planLog.logDebug($"Simulating Positive Reaction: Ignored setting key '{key}' to boolean 'false' (not positive).");
	            }
	        }
	        // 3. Numeric values: Only apply if increasing (positive change)
	        else if (is_numeric(reaction_value) && is_numeric(new_state[$ key]))
	        {
	            if (reaction_value > 0) // Only apply if the reaction is a positive numeric change
	            {
	                new_state[$ key] += reaction_value;
	                planLog.logDebug($"Simulating Positive Reaction: Key '{key}' numerical increase by {string(reaction_value)}. New value: {string(new_state[$ key])}.");
	            }
	            else
	            {
	                planLog.logDebug($"Simulating Positive Reaction: Ignored numerical change for key '{key}' as it's not positive ({string(reaction_value)}).");
	            }
	        }
	        // 4. Other types (e.g., strings): Treat as positive if a new value is being set (or if you have specific positive string changes)
	        // For simplicity, we'll treat any direct assignment for non-boolean/non-numeric as "positive" if it's changing the value.
	        // You might refine this further if "positive" has a different meaning for strings.
	        else
	        {
	             // If the value is changing to something new, consider it positive.
	             // You might need more specific rules here depending on your game's logic.
	            if (new_state[$ key] != reaction_value)
				{
	                new_state[$ key] = reaction_value;
	                planLog.logDebug($"Simulating Positive Reaction: Key '{key}' set to new value '{string(reaction_value)}'.");
	            } else {
	                planLog.logDebug($"Simulating Positive Reaction: Key '{key}' already has value '{string(reaction_value)}', no change applied.");
	            }
	        }
	    }
	    return new_state;
	}
	
	getPlanActionNames = function(_plan)
	{
		var _temp = [];
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _name = _act.name;
			
			array_push(_temp, _name);
		}
		
		return _temp;
	}
	
	
	getPlanCost = function(_plan)
	{
		var _total = 0;
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _cost = _act.cost;
			//var _name = _act.name;
			
			_total += _cost;
		}
		
		return _total;
	}
	

	array_slice = function(_array, _start, _length)
	{
	    var _result = [];
	    var _end = _start + _length;
	    var _count = array_length(_array);
    
	    // Clamp the end to array bounds
	    if (_start < 0) _start = 0;
	    if (_end > _count) _end = _count;

	    for (var i = _start; i < _end; i++)
		{
	        array_push(_result, _array[i]);
	    }

	    return _result;
	}

	
	anyKeysMatch = function(_keysA, _keysB)
	{ 
		
		_keysA = struct_get_names(_keysA);
		_keysB = struct_get_names(_keysB);
		
	    for (var i = 0; i < array_length(_keysA); i++)
		{
	        var _keyA = _keysA[i];
	        for (var j = 0; j < array_length(_keysB); j++)
			{
	            var _keyB = _keysB[j];
	            if (_keyA == _keyB)
				{
	                return true; // Found a match, no need to check further
	            }
	        }
	    }
	    return false; // No common keys found after checking all combinations
	}

	
	buildActionDependencyGraph = function()
	{
	    var _allActs = structToArray(allActions);
	    var _forwardGraph = {};
	    var _backwardGraph = {};

	    for (var i = 0; i < array_length(_allActs); i++)
	    {
	        var _actA = _allActs[i];
	        var _forwardList = [];

	        for (var j = 0; j < array_length(_allActs); j++)
	        {
	            var _actB = _allActs[j];

	            //if (checkKeysMatch(_actB.conditions, _actA.reactions))
	            if (anyKeysMatch(_actB.conditions, _actA.reactions))
	            {
	                // Forward: A -> B
	                array_push(_forwardList, _actB.name);

	                // Backward: B <- A
	                if (!struct_exists(_backwardGraph, _actB.name))
	                {
	                    _backwardGraph[$ _actB.name] = [];
	                }
	                array_push(_backwardGraph[$ _actB.name], _actA.name);
	            }
	        }

	        _forwardGraph[$ _actA.name] = _forwardList;

	        // Ensure all nodes exist in both graphs, even if empty
	        if (!struct_exists(_backwardGraph, _actA.name))
	        {
	            _backwardGraph[$ _actA.name] = [];
	        }
	    }

	    return {
	        forward: _forwardGraph,
	        backward: _backwardGraph
	    };
	}


	buildDependencyMaps = function()
	{
		var _allActions = structToArray(allActions);
	    var preMap = {};
	    var effMap = {};

	    for (var k = 0; k < array_length(_allActions); k++)
		{
	        var act = _allActions[k];

	        var condKeys = struct_get_names(act.conditions);
	        for (var i = 0; i < array_length(condKeys); i++)
			{
	            var key = condKeys[i];
	            if (!struct_exists(preMap, key)) preMap[$ key] = [];
	            array_push(preMap[$ key], act.name);
	        }

	        var effectKeys = struct_get_names(act.reactions);
	        for (var i = 0; i < array_length(effectKeys); i++)
			{
	            var key = effectKeys[i];
	            if (!struct_exists(effMap, key)) effMap[$ key] = [];
	            array_push(effMap[$ key], act.name);
	        }
	    }

	    return {con: preMap, react: effMap};
	}
	
	// Find Actions That Depend On the Current Action
	getDependentActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var dependentActions = [];
	    var reactKeys = struct_get_names(action.reactions);

	    for (var i = 0; i < array_length(reactKeys); i++)
	    {
	        var key = reactKeys[i];
	        var consumers = reactionGraph[$ key]; // <- actions that consume this key
	        if (consumers != undefined)
	        {
	            for (var j = 0; j < array_length(consumers); j++)
	            {
	                var actName = consumers[j];
	                if (!array_contains(dependentActions, actName))
					{
	                    array_push(dependentActions, actName);
					}
	            }
	        }
	    }

	    return dependentActions;
	}

	//  Find Actions That Enable the Current Action
	getEnablingActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var enablingActions = [];
	    var condKeys = struct_get_names(action.conditions);

	    for (var i = 0; i < array_length(condKeys); i++)
	    {
	        var key = condKeys[i];
	        var producingActs = conditionGraph[$ key]; // <- actions that produce this key
	        if (producingActs != undefined)
	        {
	            for (var j = 0; j < array_length(producingActs); j++)
	            {
	                var actName = producingActs[j];
	                if (!array_contains(enablingActions, actName))
	                    array_push(enablingActions, actName);
	            }
	        }
	    }

	    return enablingActions;
	}

	
	
	// non-explicit + explicit keys
	getUnmetConditionsIterative = function(_conditions, _state)
	{
	    var unmetConditions = {}; // Use a dictionary/object to store unique unmet keys
	    var visitedKeys = [];
	    var queue = [];

	    // Initialize the queue with the initial conditions
	    var initialKeys = struct_get_names(_conditions);
	    for (var i = 0; i < array_length(initialKeys); i++)
	    {
	        var key = initialKeys[i];
	        if (!keyMatches(_state, _conditions, key))
	        {
	            // Only add to queue and unmetConditions if it's genuinely unmet
	            // and not already visited.
	            if (!array_contains(visitedKeys, key)) {
	                array_push(queue, key);
	                array_push(visitedKeys, key);
	                unmetConditions[$ key] = true; // Mark as unmet
	            }
	        }
	    }

	    while (array_length(queue) > 0)
	    {
	        var currentKey = array_shift(queue); // Dequeue the first item

	        var producingActs = conditionGraph[$ currentKey];
	        if (producingActs != undefined)
	        {
	            for (var j = 0; j < array_length(producingActs); j++)
	            {
	                var actName = producingActs[j];
	                var action = allActions[$ actName];
	                if (action != undefined && action.conditions != undefined)
	                {
	                    var actionConditionsKeys = struct_get_names(action.conditions);
	                    for (var k = 0; k < array_length(actionConditionsKeys); k++)
	                    {
	                        var conditionKey = actionConditionsKeys[k];

	                        // Check if this condition is unmet and not yet visited
	                        if (!keyMatches(_state, action.conditions, conditionKey))
	                        {
	                            if (!array_contains(visitedKeys, conditionKey))
	                            {
	                                array_push(queue, conditionKey);
	                                array_push(visitedKeys, conditionKey);
	                                unmetConditions[$ conditionKey] = true; // Mark as unmet
	                            }
	                        }
	                    }
	                }
	            }
	        }
	    }

	    // Convert the unmetConditions object keys into an array
	    var resultKeys = struct_get_names(unmetConditions);
	    var out = [];

	    // Filter to ensure only truly unmet conditions from the original state are included
	    for (var i = 0; i < array_length(resultKeys); i++)
		{
	        var key = resultKeys[i];
	        if (!keyMatches(_state, _conditions, key))
			{
	            array_push(out, key);
	        }
	    }

	    return out;
	}

	
	// explicit keys 
	getUnmetConditions = function(_conditions, _state)
	{
		var unmet = [];
		var _keys = struct_get_names(_conditions);

		for (var i = 0; i < array_length(_keys); i++)
		{
			var _key = _keys[i];

			if (!keyMatches(_state, _conditions, _key))
			{
				array_push(unmet, _key);
			}
		}
	
		return unmet;
	}


	// non-explicit keys
	getUnmetNonExplicitConditions = function(_goal, _state)
	{
	    var allUnmet = {};
	    var visitedKeys = [];
	    var queue = [];

	    var explicitKeys = struct_get_names(_goal);
	    var initialUnmetExplicit = [];

	    // Gather initial unmet explicit keys
	    for (var i = 0; i < array_length(explicitKeys); i++) {
	        var key = explicitKeys[i];
	        if (!keyMatches(_state, _goal, key)) {
	            array_push(initialUnmetExplicit, key);
	            array_push(queue, key);
	            array_push(visitedKeys, key);
	            allUnmet[$ key] = true;
	        }
	    }

	    // BFS through condition graph
	    while (array_length(queue) > 0) {
	        var currentKey = array_shift(queue);
	        var producers = conditionGraph[$ currentKey];
	        if (producers == undefined) continue;

	        for (var j = 0; j < array_length(producers); j++) {
	            var actName = producers[j];
	            var action = allActions[$ actName];
	            if (action == undefined || action.conditions == undefined) continue;

	            var preKeys = struct_get_names(action.conditions);
	            for (var k = 0; k < array_length(preKeys); k++) {
	                var preKey = preKeys[k];

	                if (!keyMatches(_state, action.conditions, preKey)) {
	                    if (!array_contains(visitedKeys, preKey)) {
	                        array_push(queue, preKey);
	                        array_push(visitedKeys, preKey);
	                    }
	                    allUnmet[$ preKey] = true;
	                }
	            }
	        }
	    }

	    // Remove initial unmet explicit keys from allUnmet keys
	    var allUnmetKeys = struct_get_names(allUnmet);
	    var nonExplicitUnmet = [];

	    for (var i = 0; i < array_length(allUnmetKeys); i++)
		{
	        var key = allUnmetKeys[i];
	        if (!array_contains(initialUnmetExplicit, key))
			{
	            array_push(nonExplicitUnmet, key);
	        }
	    }

	    return nonExplicitUnmet;
	}

	
	
	trimActionsToUnmet = function(relevantActions, unmetKeys)
	{
		var actionSet = {};
	
		// For each unmet condition key, look up actions that can produce it
		for (var i = 0; i < array_length(unmetKeys); i++)
		{
			var key = unmetKeys[i];
		
			if (reactionGraph[$ key] != undefined)
			{
				var producers = reactionGraph[$ key];
			
				for (var j = 0; j < array_length(producers); j++)
				{
					var act = producers[j];
					struct_set(actionSet, act, act);
				}
			}
		}
	
		// Only include relevant actions that appear in the producer set
		var trimmed = [];
		for (var i = 0; i < array_length(relevantActions); i++)
		{
			var actName = relevantActions[i];
			if (struct_exists(actionSet, actName))
			{
				array_push(trimmed, actName);
			}
		}
		
		//show_debug_message($"Trimmed to {array_length(trimmed)} <- from: {array_length(relevantActions)}, Relevant actions: {trimmed}");
		return trimmed;
	}



	state_meets_goal = function(sim_state, goal_state)
	{
	    var _goal_keys = struct_get_names(goal_state);
	    for (var i = 0; i < array_length(_goal_keys); i++)
		{
	        var _key = _goal_keys[i];
	        if (!keyMatches(sim_state, goal_state, _key))
			{
	            return false; // Early exit if any condition fails
	        }
	    }
	    return true; // All conditions passed
	}


	// Eats up Time during planning(ms)
	ancestorHasState = function(node, new_state)
	{
	    var new_key = hashState(new_state);
		//show_debug_message("----------------------------------");
	    while (node != undefined && node != noone)
	    {
	        var node_key = hashState(node.state);
			
			//show_debug_message($"New Key: {new_key}");
			//show_debug_message($"Node Key: {node_key}");
			
	        if (node_key == new_key)
	        {
	            return true;
	        }
	        node = node.parent;
	    }

	    return false;
	}
	
	
	
	// Reconstructs the plan from the goal node by walking back through parents
	reconstructPlan = function(_node)
	{
		var plan = [];
		while (_node.parent != undefined)
		{
			array_insert(plan, 0, _node.action); // insert action at beginning
			_node = _node.parent;
		}
		return plan;
	}

	
	
	getAverageActionCost = function()
	{
	    var _actions = structToArray(allActions);
	    var _count = array_length(_actions);

	    if (_count == 0) return 0; // Avoid divide by zero

	    var _totalCost = 0;
	    for (var i = 0; i < _count; i++)
	    {
	        var _act = _actions[i];
	        _totalCost += _act.cost;
	    }

	    var _avg = _totalCost / _count;
	    //show_debug_message("Average action cost: " + string(_avg));

	    return _avg;
	}



	/// @description Calculates and stores the minimum cost per unit for numerical keys and minimum cost to achieve specific states for direct keys, using the reactionGraph.
	calculateMinActionCostsHeuristicData = function()
	{
	    var MinCostPerKey = {};      // Stores { "key_name": min_cost_per_key_value, ... }
	    var MinCostToAchieve = {};   // Stores { "key_name": { "target_value_string": min_cost, ... }, ... }


	    var _reactionKeys = struct_get_names(reactionGraph);

	    for (var i = 0; i < array_length(_reactionKeys); i++)
	    {
	        var _reactionKey = _reactionKeys[i]; // e.g., "Ammo", "HasWeapon", "Scrap"
	        var _affectingActionNames = reactionGraph[$ _reactionKey]; // Array of action names that react to this key

	        for (var j = 0; j < array_length(_affectingActionNames); j++)
	        {
	            var action_name = _affectingActionNames[j];
	            var _action = allActions[$ action_name]; // Get the full action definition
	            var _action_cost = _action.cost;

	            // Now, examine the specific reaction for this action and key
	            var _reactionEffect = _action.reactions[$ _reactionKey];
				
				if is_undefined(_reactionEffect) continue;
				
				
				// --- Logic for Populating Heuristic Tables ---
            
	            // 1. Populate MinCostPerKey (for numerical quantities that are NOT booleans 0/1)
	            // This is for resources like "Ammo", "Scrap", "Wood" where you want a cost per incremental unit.
	            // Exclude 0 and 1 as they typically represent boolean true/false states in your system.
	            if (is_numeric(_reactionEffect) && _reactionEffect != 0 && _reactionEffect != 1)
	            {
	                var cost_per_unit = _action_cost / abs(_reactionEffect); // Cost per unit of magnitude change
                
	                // Update MinCostPerKey for this key if this action is cheaper per unit
	                if (!struct_exists(MinCostPerKey, _reactionKey) || cost_per_unit < MinCostPerKey[$ _reactionKey])
	                {
	                    MinCostPerKey[$ _reactionKey] = cost_per_unit;
	                }
	            }
            
	            // 2. Populate MinCostToAchieve (for all specific target states: booleans, strings, and exact numbers)
	            // This is for states like "HasWeapon: true", "Location: Town", "Ammo: 0", "Health: 100".
	            // All values (numbers, booleans, strings) are converted to strings for consistent lookup keys.
	            var target_value_str = string(_reactionEffect); // Convert to string for keying

	            if (!struct_exists(MinCostToAchieve, _reactionKey))
	            {
	                MinCostToAchieve[$ _reactionKey] = {};
	            }
	            // If this is the first time we've seen this target value for this key, or if this action is cheaper
	            if (!struct_exists(MinCostToAchieve[$ _reactionKey], target_value_str) || _action_cost < MinCostToAchieve[$ _reactionKey][$ target_value_str])
	            {
	                MinCostToAchieve[$ _reactionKey][$ target_value_str] = _action_cost;
	            }


	        }
	    }
		
		

	    // Optional: Log the results for debugging
	    show_debug_message("Calculated Min Heuristic Costs:");
	    show_debug_message(" ~ MinCostPerKey: " + string(MinCostPerKey));
	    show_debug_message(" ~ MinCostToAchieve: " + string(MinCostToAchieve));
		
		return {
			MinCostPerKey: MinCostPerKey,
			MinCostToAchieve: MinCostToAchieve,
		}
	}
	
	
	
	
	getConditionGap = function(_state_value, _target_condition_value, _key_name = "unknown_key")
	{
	    var _avg_cost = getAverageActionCost(); // Still a useful fallback
		var _minCostPerKey = actionCostData.MinCostPerKey;
		var _minCostToAchieve = actionCostData.MinCostToAchieve;
		
	    // --- Handle Numerical Conditions (e.g., Ammo >= 100) ---
	    if (is_struct(_target_condition_value)) // Indicates a numerical comparison (e.g., {comparison:">=", value:10})
	    {
	        var operator = _target_condition_value.comparison;
	        var target_numeric_value = _target_condition_value.value;

	        if (!is_numeric(_state_value))
	        {
	            // If the current state value isn't numeric but the goal expects a numeric comparison,
	            // it's an impossible gap for this path (or a very high cost).
	            return infinity;
	        }

	        // Use global.GOAP_MinCostPerUnit_Data for numerical quantities
	        var cost_per_unit = _avg_cost; // Default fallback
	        if (struct_exists(_minCostPerKey, _key_name))
	        {
	            cost_per_unit = _minCostPerKey[$ _key_name];
	        }
	        if (cost_per_unit <= 0) 
			{
				//show_debug_message("Using avg. cost");
				cost_per_unit = _avg_cost; // Defensive: ensure non-zero/positive cost
			}

	        switch (operator)
	        {
	            case ">=":
	                var needed = max(0, target_numeric_value - _state_value);
	                return needed * cost_per_unit;

	            case "<=":
	                var excess = max(0, _state_value - target_numeric_value);
	                return excess * cost_per_unit;

	            case ">":
	                return max(0, (target_numeric_value - _state_value) + 1) * cost_per_unit;

	            case "<":
	                return max(0, (_state_value - target_numeric_value) + 1) * cost_per_unit;

	            case "=":
	                return (_state_value == target_numeric_value) ? 0 : abs(_state_value - target_numeric_value) * cost_per_unit;

	            default:
	                planLog.logWarning($"getConditionGap: Unknown comparison operator '{operator}' for key '{_key_name}'.");
	                return 999999999;
	        }
	    }
	    // --- Handle Simple Boolean/Value Conditions (e.g., HasWeapon: true, Location: "Town") ---
	    else // target_condition_value is a direct value (e.g., true/false, "item_name", 0/1)
	    {
	        var target_simple_value = _target_condition_value;

	        if (_state_value == target_simple_value)
	        {
	            return 0; // Condition already met
	        }
	        else
	        {
	            var min_cost_for_value = _avg_cost; // Fallback to average cost
				
	            var target_value_str = string(target_simple_value); // Convert to string for lookup
				//show_debug_message($"AVG COST: {min_cost_for_value}");
				
	            if (struct_exists(_minCostToAchieve, _key_name))
	            {
	                if (struct_exists(_minCostToAchieve[$ _key_name], target_value_str))
	                {
	                    min_cost_for_value = _minCostToAchieve[$ _key_name][$target_value_str];
	                }
	            }
				
				//show_debug_message($"AVG COST: {min_cost_for_value}");
				
	            return min_cost_for_value;
	        }
	    }
	}
	
	
	collectRelevantActions = function(_conditionsToMeet)
	{
	    // Use a struct to track all unique actions encountered during the traversal.
	    // The keys of this struct will be the unique action names.
	    var _collectedActions = {};

	    // Use an array to simulate a queue for conditions that we need to find actions for.
	    var _conditionsQueue = [];

	    // Initialize the queue with the starting conditions that need to be met.
	    for (var i = 0; i < array_length(_conditionsToMeet); i++)
	    {
	        array_push(_conditionsQueue, _conditionsToMeet[i]);
	    }

	    var head = 0; // This acts as a pointer to the front of our queue

	    // Loop as long as there are conditions in the queue to process
	    while (head < array_length(_conditionsQueue))
	    {
	        var _keyToMeet = _conditionsQueue[head++]; // Dequeue the next condition key

	        // Find actions that *produce* this _keyToMeet (i.e., whose reactions contain this key)
	        if (struct_exists(reactionGraph, _keyToMeet))
	        {
	            var _producingActions = reactionGraph[$ _keyToMeet];

	            // Iterate through each action that can produce this key
	            for (var j = 0; j < array_length(_producingActions); j++)
	            {
	                var _actName = _producingActions[j];

	                // If this action has not already been added to our collected list
	                if (!struct_exists(_collectedActions, _actName))
	                {
	                    struct_set(_collectedActions, _actName, true); // Mark this action as collected (add to struct)

	                    var _act = allActions[$ _actName]; // Get the full action object

	                    // If the action exists and has preconditions
	                    if (_act != undefined && struct_exists(_act, "conditions"))
	                    {
	                        var _actConditionsKeys = struct_get_names(_act.conditions);

	                        // Enqueue all preconditions of this action for further processing
	                        // This ensures we find actions needed for *this action's* conditions
	                        for (var k = 0; k < array_length(_actConditionsKeys); k++)
	                        {
	                            array_push(_conditionsQueue, _actConditionsKeys[k]);
	                        }
	                    }
	                }
	            }
	        }
	    }

	    // After processing all conditions and their related actions,
	    // convert the keys of the _collectedActions struct into a final array to return.
	    return struct_get_names(_collectedActions);
	}


	filterActionsByNegativeEffects = function(_actions, _currentState, _unmetGoalKeys, _goalState)
	{
	    var _filteredActions = [];

	    for (var i = 0; i < array_length(_actions); i++)
	    {
	        var _actName = _actions[i];
	        var _act = allActions[$ _actName];
	        if (_act == undefined) continue;

	        var _hasUndesirableEffect = false;
        
	        for (var j = 0; j < array_length(_unmetGoalKeys); j++)
	        {
	            var _unmetKey = _unmetGoalKeys[j];
            
	            if (!struct_exists(_act.reactions, _unmetKey)) continue;

	            var _reactionValue = _act.reactions[$ _unmetKey];
	            var _currentValue = _currentState[$ _unmetKey];
            
	            var _goalDefinition = undefined;
	            if (struct_exists(_goalState, _unmetKey)) {
	                _goalDefinition = _goalState[$ _unmetKey];
	            } else {
	                continue; 
	            }

	            // Numerical Goals (e.g., Ammo: {comparison: ">=", value: 10})
	            if (is_struct(_goalDefinition) && struct_exists(_goalDefinition, "comparison") && is_numeric(_reactionValue))
	            {
	                var _operator = _goalDefinition.comparison;
	                var _targetValue = _goalDefinition.value;

	                switch (_operator)
	                {
	                    case ">=": 
	                        if (_reactionValue < 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "<=": 
	                        if (_reactionValue > 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case ">": 
	                        if (_reactionValue <= 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "<": 
	                        if (_reactionValue >= 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "=": 
	                        if (_reactionValue != 0) {
	                            var _newValue = _currentValue + _reactionValue;
	                            if ((_currentValue == _targetValue && _newValue != _targetValue) ||
	                                (abs(_newValue - _targetValue) > abs(_currentValue - _targetValue)))
	                            {
	                                _hasUndesirableEffect = true;
	                            }
	                        }
	                        break;
	                }
	            }
	            // Boolean/Enum/Direct Value Goals (e.g., HasWeapon: true, Status: "idle")
	            else if (!is_struct(_goalDefinition)) 
	            {
	                if (_goalDefinition != _reactionValue) {
	                    _hasUndesirableEffect = true;
	                }
	            }

	            if (_hasUndesirableEffect) break; 
	            
	        }

	        if (!_hasUndesirableEffect)
			{
	            array_push(_filteredActions, _actName);
	        }
	    }
    
	    // Return a struct containing both the filtered actions and the count
	    return _filteredActions;
	    
	}



	getConditionsToSatisfyKey = function(key, _state, visited)
	{
	    if (visited == undefined) visited = [];

	    var requiredConditions = {};

	    // Stop if already satisfied in the current state
	    if (keyMatches(_state, {key: true}, key)) return requiredConditions;

	    // Avoid cycles
	    if (array_contains(visited, key)) return requiredConditions;
	    array_push(visited, key);

	    var producers = conditionGraph[$ key];
	    if (producers == undefined) return requiredConditions;

	    for (var i = 0; i < array_length(producers); i++) {
	        var actName = producers[i];
	        var action = allActions[$ actName];
	        if (action == undefined || action.conditions == undefined) continue;

	        var condKeys = struct_get_names(action.conditions);
			
	        for (var j = 0; j < array_length(condKeys); j++)
			{
	            var condKey = condKeys[j];

	            if (!keyMatches(_state, action.conditions, condKey))
				{
	                // Add this unmet condition
	                requiredConditions[$ condKey] = action.conditions[$ condKey];

	                // Recursively collect sub-conditions
	                var subReqs = getConditionsToSatisfyKey(condKey, _state, visited);
	                var subKeys = struct_get_names(subReqs);
	                for (var s = 0; s < array_length(subKeys); s++)
					{
	                    var subKey = subKeys[s];
	                    requiredConditions[$ subKey] = subReqs[$ subKey];
	                }
	            }
	        }

	        // Assume first producer is enough for now
	        break;
	    }

	    return requiredConditions;
	}

	
	sortActionsByScore = function(_collectedActs, _goalState)
	{
		var action_scores = [];

		for (var i = 0; i < array_length(_collectedActs); ++i)
		{
			var action = _collectedActs[i];
				
			var _act = allActions[$ action];
				
			var effects = _act.reactions; // Assume this is a ds_map

			var _score = 0;
			var keys = struct_get_names(effects);
			for (var k = 0; k < array_length(keys); ++k)
			{
			    var key = keys[k];

			    // Exact match (key and value) is best
			    if (struct_exists(_goalState, key))// && struct_get(_goalState, key) == struct_get(effects, key))
				{
			        _score += 3;
			    }
			    // Partial match (key only) is still useful
			    else if (struct_exists(_goalState, key))
				{
			        _score += 1;
			    }
			}

			if (_score >= 0)
			{
				array_push(action_scores, { name: action, score: _score });
				//show_debug_message($"Sorted: {action} , Score: {_score}");
			}
				
			//array_push(action_scores, {name: action, score: _score});
		}


		array_sort(action_scores, function(a,b)
		{
			return (a.score < b.score);
			
		});
			
		//show_debug_message($"action_scores: {action_scores}");
			
		var _tempActs = [];
		for(var i=0; i<array_length(action_scores); i++)
		{
			var _act = action_scores[i];
			array_push(_tempActs, _act.name);
		}
		
		return _tempActs;
			
	}


	#endregion
	
	
	
	goalHeuristic = function(_currentState, _goalState)
	{
		var _startMS = current_time;
		
	    var _totalHeuristicCost = 0;
	    var _unmetConditions = getUnmetConditionsIterative(_goalState, _currentState); 
		
		//_unmetConditions = planLog.doProfile("getUnmetConditionsIterative", getUnmetConditionsIterative, [_goalState, _currentState]);
		
		var _minCostPerKey = actionCostData.MinCostPerKey;
		var _minCostToAchieve = actionCostData.MinCostToAchieve;

	    var _avg_cost = getAverageActionCost(); // Still a useful fallback

	    for (var i = 0; i < array_length(_unmetConditions); i++)
	    {
	        var _key = _unmetConditions[i];

        
	        var _goalDefinition = _goalState[$ _key]; 

	        // --- NEW/UPDATED LOGIC: Handle missing keys using calculated heuristic data ---
	        if (!struct_exists(_currentState, _key))
	        {
	            var cost_for_missing_key = _avg_cost/10; // Default fallback if no specific data is found

	            if (is_struct(_goalDefinition)) // It's a numerical comparison goal (e.g., {comparison:">=", value:10})
	            {
	                // Estimate the cost to get to the required amount from zero, using cost_per_unit
	                var needed_amount = _goalDefinition.value;
                
	                // Use global.GOAP_MinCostPerUnit_Data if available, otherwise fallback to average
	                var cost_per_unit = struct_exists(_minCostPerKey, _key) ? _minCostPerKey[$ _key] : _avg_cost;
                
	                cost_for_missing_key = needed_amount * cost_per_unit;
	                if (cost_for_missing_key <= 0) cost_for_missing_key = _avg_cost; // Ensure minimum if goal value is 0 or less
	            }
	            else // It's a simple boolean/value goal (e.g., true, "item_name", or 0/1)
	            {
	                var target_value_str = string(_goalDefinition);
                
	                // Use global.GOAP_MinCostToAchieve_Data for direct lookup
	                if (struct_exists(_minCostToAchieve, _key) && struct_exists(_minCostToAchieve[$ _key], target_value_str))
	                {
	                    cost_for_missing_key = _minCostToAchieve[$ _key][target_value_str];
	                }
	            }
            
	            _totalHeuristicCost += cost_for_missing_key;
	            continue; // Move to the next unmet condition
	        }

	        // --- Existing logic for keys that exist but don't meet the goal ---
	        var _currentValue = _currentState[$ _key];

	        // Now, use the getConditionGap function, which will also be updated to use the new data
	        // We'll pass the global heuristic data to getConditionGap
	        var _val = getConditionGap(_currentValue, _goalDefinition, _key);
	        _totalHeuristicCost += _val;
	    }


		//show_debug_message($"Goal Heuristic MS: {current_time - _startMS}");

	    return _totalHeuristicCost;
	}
	
	
	calculateHeuristic  = function(_currentState, _goalState, _stateHash, _goalStateHash)
	{
		var _key = _stateHash + "|" + _goalStateHash;
		
		if (struct_exists(heuristic_cache, _key))
		{
			var _data = struct_get(heuristic_cache, _key);
			
			//show_debug_message("Heuristic cache hit.");
			
			return _data;
		}
		
		var _h = goalHeuristic(_currentState, _goalState);
	    struct_set(heuristic_cache, _key, _h);
		
	    return _h;
	}
	
	
	#region		---[ Node Data Collection ]---
	
	nodeData = {
		pruned: 0,
		expanded: 0,
		stale: 0,
		actionsTried: 0,
		accumulatedHeuristic: 0,
	}


	resetNodeData = function()
	{
		nodeData.pruned = 0;
		nodeData.expanded = 0;
		nodeData.stale = 0;
		nodeData.actionsTried = 0;
		nodeData.accumulatedHeuristic = 0;
	}


	reportNodeData = function(_planLength, _bestGoalNode)
	{
		
		
		/*
			Summary of all Node DATA
			
				If Prune Ratio goes up, you’re cutting out more useless nodes early, which is good.
				If Efficiency (expanded/total) increases, you’re expanding a higher portion of relevant nodes, also good.
				If Branching Factor drops, your planner is focusing more tightly on promising paths.
				If Goal Efficiency improves, more of your expansions are actually contributing to the final plan.
		*/
		
		var _showData = true;
		var _showSimpleData = true;
		
		
		if !_showData return;
		
		var _truePruned = nodeData.pruned;
		var _totalNodes = _truePruned + nodeData.expanded;

		var _pruneRatio = 0;
		var _expansionEfficiency = 0;
		var _branchingFactor = 0;
		var _goalEfficiency = 0;
		var _reExpansionRate = 0;
		var _avgHeuristicRate = 0;		// the average hCost of the nodes that A* expanded.
		var _planGCost = _bestGoalNode.gCost;
		
		var _optimalPathNodes = _planLength + 1;
		var _extraExpandedNodes = nodeData.expanded - _optimalPathNodes
		
		var _expansionOverheadRatio = 0;	// for every 1 node on the optimal path, your A* had to expand nearly # nodes
		
		/*
		
			A ratio closer to 1 (or within a reasonable range) suggests the average heuristic value is a good proportion of the total cost.
			A very low ratio might suggest an under-informed heuristic (if _planGCost is high).
			A very high ratio might suggest an overly optimistic or aggressive heuristic
			(though still admissible, it might mean the hCost values are large compared to the actual path cost increments).
		
		*/
		
		var _heuristicCostRatio = 0;

		if (_totalNodes > 0)
		{
			_pruneRatio = _truePruned / _totalNodes;
			_expansionEfficiency = nodeData.expanded / _totalNodes;
		}

		if (_planLength > 0)
		{
			_branchingFactor = nodeData.actionsTried / nodeData.expanded;
		}

		if (nodeData.expanded > 0)
		{
			_goalEfficiency = 1 - ((nodeData.expanded - _planLength) / nodeData.expanded);
			_reExpansionRate = nodeData.stale / nodeData.expanded;
			_avgHeuristicRate = nodeData.accumulatedHeuristic / nodeData.expanded; 
			
		}
		
		if (_planGCost > 0)
		{
			_heuristicCostRatio = _avgHeuristicRate / _planGCost;
		}
		
		
		if (_optimalPathNodes > 0)
		{
			_expansionOverheadRatio = _extraExpandedNodes / _optimalPathNodes;
		}
		
		
		
		
		if _showSimpleData
		{
			show_debug_message($"Node Data: [Total: {_totalNodes}, Pruned: {_truePruned}, Expanded: {nodeData.expanded}, Stale: {nodeData.stale}, Prune Ratio: {_pruneRatio}]");
		    show_debug_message($"Node Data: [Efficiency: {_expansionEfficiency}, Branching: {_branchingFactor}, Goal Efficiency: {_goalEfficiency}]");
		    show_debug_message($"Node Data: [Re-Expansion Rate: {_reExpansionRate}, Average Heuristic Rate: {_avgHeuristicRate}, Plan G-Cost: {_planGCost}]");
			show_debug_message($"Node Data: [Heuristic Cost Ratio: {_heuristicCostRatio}, Extra Nodes Expanded: {_extraExpandedNodes}, Excess Node Expansion Ratio: {_expansionOverheadRatio}]");
		}
		else
		{
			// --- Debug Messages (Sentence Format) ---
		    
	        show_debug_message("--- GOAP Planner Performance Report ---");
	        show_debug_message($"Total nodes considered (including pruned and expanded): {_totalNodes}.");
	        show_debug_message($"Nodes effectively pruned (conditions not met or inferior path): {_truePruned}.");
	        show_debug_message($"Nodes expanded for search: {nodeData.expanded}.");
	        show_debug_message($"Nodes that were stale (re-expanded via a better path): {nodeData.stale}.");
	        show_debug_message($"The prune ratio is {string_format(_pruneRatio, 0, 2)}. (This means {string_format(_pruneRatio * 100, 0, 0)}% of nodes were discarded early).");
	        show_debug_message($"The search efficiency is {string_format(_expansionEfficiency, 0, 2)}. (Meaning {string_format(_expansionEfficiency * 100, 0, 0)}% of considered nodes were expanded).");
	        show_debug_message($"The average branching factor (actions considered per expanded node) is {string_format(_branchingFactor, 0, 2)}.");
	        show_debug_message($"Goal efficiency (how much expanded nodes directly contributed to path) is {string_format(_goalEfficiency, 0, 4)}. (Meaning {string_format(_goalEfficiency * 100, 0, 1)}% of expanded nodes were on the optimal path).");
	        show_debug_message($"The re-expansion rate is {string_format(_reExpansionRate, 0, 2)}. (This highlights {string_format(_reExpansionRate * 100, 0, 0)}% wasted work due to re-expanding states).");
	        show_debug_message($"The average heuristic estimate for expanded nodes was {string_format(_avgHeuristicRate, 0, 2)}.");
	        show_debug_message($"The final plan's total G-Cost is {_planGCost}.");
	        show_debug_message($"The Heuristic Cost Ratio is {string_format(_heuristicCostRatio, 0, 2)}. (This indicates your heuristic's estimate strength is {string_format(_heuristicCostRatio * 100, 0, 0)}% of the total plan cost).");
	        show_debug_message($"The number of nodes on the optimal path (including start) is {_optimalPathNodes}.");
	        show_debug_message($"Extra nodes expanded (not on the optimal path) are: {_extraExpandedNodes}.");
	        show_debug_message($"The Excess Node Expansion Ratio is {string_format(_expansionOverheadRatio, 0, 2)}. (For every optimal node, {string_format(_expansionOverheadRatio, 0, 2)} extra nodes were expanded).");
	        show_debug_message("-------------------------------------");
			
		}
		
		
		resetNodeData();
	}



	#endregion	
	
	function astarNode(_state, _action, _parent, _gCost, _hCost) constructor
	{
		state = _state;
		action = _action;
		parent = _parent;
		gCost = _gCost;
		hCost = _hCost;
		fCost = gCost + hCost;
	}
	
	
	buildSubGoal = function(_startState, _goalState)
	{
		var _unmet = getUnmetNonExplicitConditions(_goalState, _startState);
		show_debug_message($"Non-Explicit Keys: {_unmet}");

		var _mergedSubGoal = {};

		for (var i = 0; i < array_length(_unmet); i++)
		{
			var _key = _unmet[i];
			var _con = getConditionsToSatisfyKey(_key, _startState);

			var _keys = struct_get_names(_con);
			for (var j = 0; j < array_length(_keys); j++)
			{
				var _condKey = _keys[j];

				// Optional: Prevent overwriting if key already exists
				if (!struct_exists(_mergedSubGoal, _condKey))
				{
					_mergedSubGoal[$ _condKey] = _con[$ _condKey];
				}
			}
		}

		show_debug_message("Merged Sub Goal:");
		show_debug_message(_mergedSubGoal);

		// Return or use mergedSubGoal as needed
		return _mergedSubGoal;
	}


	findPlan = function(_startState, _goalState)
	{
		
		#region	<Init Vars>
		
		var _startMS = current_time;
		
		
		// cached data
		var _visitedNodes = {};				// stateHash -> best node
		var _stateActionsMap = {};			// track actions tried on each state (state hash -> struct of action names)
		
		var _relevantActionsCache = {};  // cacheKey -> filtered actions array
		
		
		var _nonDeterministic = false;		// can lower speed of the planner
		
		var _open = ds_priority_create();
		
		var _bestFSoFar = infinity; // Large initial value
		var _bestGoalNode = noone;
		
		
		var _finalPlan = [];
		
		
		var _startHash = hashState(_startState);
		var _goalStateHash = hashState(_goalState);
		var _startNode = new astarNode(_startState, undefined, undefined, 0, calculateHeuristic(_startState, _goalState, _startHash, _goalStateHash));
		
		
		struct_set(_visitedNodes, _startHash, _startNode);
		ds_priority_add(_open, _startNode, _startNode.fCost);

		
		
		#endregion
		
		var _printEvery = false;
		
		show_debug_message($"Goal State: {_goalState}");
		show_debug_message($"Start State: {_startState}");
		
		
		// A* Pathfinding from _startState -> _goalState
		while (!ds_priority_empty(_open))
		{
			
			#region		--- Init ---
			
			var _node = ds_priority_delete_min(_open);
			
			
			// Early termination: if best goal found and next node's fCost is >= best goal fCost, break
		    if (_bestGoalNode != noone && _node.fCost >= _bestFSoFar) break; // no better solution 
			
			
			var _currentState = _node.state;
			var _currentAction = _node.action;
			var _stateHash = hashState(_currentState);
			
			#endregion
			
			
			var _bestOldNode = _visitedNodes[$ _stateHash];
			if (_bestOldNode != _node) continue;
			
			
			nodeData.expanded++;
			

			//if !is_undefined(_currentAction) and (_printEvery) show_debug_message($"Trying Action: {_currentAction.name}");
			
			#region		--- Dynamic Action Filtering ---
			
			
			var _startFil = current_time;
			
			var _unmetGoalKeys = getUnmetConditionsIterative(_goalState, _currentState);
			var _collectedActs;
			
			// Same unmet goal patterns should produce same relevant actions
			var _goalPatternKey = string(_unmetGoalKeys); // Convert array to string
			
			if (struct_exists(_relevantActionsCache, _goalPatternKey))
			{
				//show_debug_message("Cache Hit for Relevant Actions.");
			    _collectedActs = _relevantActionsCache[$ _goalPatternKey];
			} else {
			    _collectedActs = collectRelevantActions(_unmetGoalKeys);
			    _collectedActs = trimActionsToUnmet(_collectedActs, _unmetGoalKeys);
			    struct_set(_relevantActionsCache, _goalPatternKey, _collectedActs);
			}
			
			_collectedActs = filterActionsByNegativeEffects(_collectedActs, _currentState, _unmetGoalKeys, _goalState);
			
			//show_debug_message($"Filtered Actions ({array_length(_collectedActs)}): {_collectedActs}");
			
			_collectedActs = sortActionsByScore(_collectedActs, _goalState);
			
			
			var _endTimeFil = current_time - _startFil;
			if (_printEvery) and (_endTimeFil > 0) show_debug_message($"Filter Actions: {_endTimeFil} ms");
			
			#endregion
			
			nodeData.accumulatedHeuristic += _node.hCost;
			
			
			#region		--- Expand all relavant actions ---
			
			var _startExp = current_time;
			
			
			for (var i = 0; i < array_length(_collectedActs); i++)
			{
				var _actName = _collectedActs[i];
				var _act = allActions[$ _actName];
				if (_act == undefined) continue;

				nodeData.actionsTried++; // Count every applicable action per node
				
				//show_debug_message($"Trying Action: {_actName}");
				
				#region			--- Pruning Before Simulating State ---
				
				
				if (!checkKeysMatch(_act.conditions, _currentState))
				{
					if (_printEvery) show_debug_message($"Action ({_actName}) conditions not met.");
					nodeData.pruned++;
					continue;
				}
				
				
				
				#endregion
				
				
				var _simState = simulateReactions(_currentState, _act.reactions);
				//_simState = planLog.doProfile("simulateReactions", simulateReactions, [_currentState, _act.reactions])
				var _simHash = hashState(_simState);
				
				
				//var _simCacheKey = hashState(_currentState) + "::" + _actName + ":" + string(_act.reactions);
				//var _simState;

				//if (struct_exists(simulation_cache, _simCacheKey))
				//{
				//    _simState = simulation_cache[$ _simCacheKey];
				//} else {
				//    _simState = simulateReactions(_currentState, _act.reactions);
				//    struct_set(simulation_cache, _simCacheKey, _simState);
				//}

				//var _simHash = hashState(_simState);
				
				#region			--- Pruning After Simulating State ---
				
				
				
				var _hAfter = calculateHeuristic(_simState, _goalState, _simHash, _goalStateHash);
				
				// Apply heuristic consistency correction
				var _correctedH = max(_hAfter, _node.hCost - _act.cost);
			
				// move this below everything so ur not wastefully creating structs for the garbage collectors
				var _newNode = new astarNode(_simState,_act,_node, (_node.gCost + _act.cost), _correctedH);
				
				
				// Optional: Diagnostic output
				if (_newNode.hCost != _hAfter)
				{
					
					/*
					
						"Hey, this action cost more than you thought
						it would get us closer to the goal,
						so I'm pretending the goal is still a bit further away."
					
					*/
					
					//show_debug_message("Heuristic corrected: " + string(_hAfter) + " -> " + string(_newNode.hCost));
					
				}
				
				
				// --- Move deduplication check here ---
				var enqueueNode = false;
				if (struct_exists(_visitedNodes, _simHash))
				{
				    var _existingOldNode = _visitedNodes[$ _simHash];
    
				    if (_newNode.gCost >= _existingOldNode.gCost)
					{
				        nodeData.pruned++;
				        continue;
				    }
    
				    // Better path found
				    nodeData.stale++;
					
					// Stale check passed — better path found
					//show_debug_message("Stale node detected: Better path to same state");
					
				    enqueueNode = true;
				} else {
				    enqueueNode = true;
				}

				if (!enqueueNode) continue;

				// --- Now do action-set tracking (after pruning) ---
				if (!struct_exists(_stateActionsMap, _simHash))
				{
				    struct_set(_stateActionsMap, _simHash, {});
				}
				
				var _actionSet = _stateActionsMap[$ _simHash];
				if (struct_exists(_actionSet, _actName))
				{
				    nodeData.pruned++;
				    continue;
				}

				// Enqueue node only after passing dedup + action check
				struct_set(_visitedNodes, _simHash, _newNode);
				var priority = _newNode.fCost + (_newNode.hCost * 0.0001);
				ds_priority_add(_open, _newNode, priority);
				struct_set(_actionSet, _actName, true);

				// Goal check
				if (state_meets_goal(_simState, _goalState))
				{
				    var _f = _newNode.gCost + _newNode.hCost;
				    if (_f < _bestFSoFar)
					{
				        _bestFSoFar = _f;
				        _bestGoalNode = _newNode;
				    }
				}
				
				
				
				#endregion
				
				//show_debug_message($"Action Made it: {_actName}");
				//show_debug_message($"[{current_time-_startMS} ms] Expanding ({_expanded}): g={_newNode.gCost}, h={_newNode.hCost}, f={_newNode.fCost}");
				//show_debug_message("--------------------------------------------------");
				
			}
			
			var _endTimeExp = current_time - _startExp;
			if (_printEvery) and (_endTimeExp > 0) show_debug_message($"Expand Relevant Actions: {_endTimeExp} ms");
			
			
			#endregion
			
		}
		
		
		
		// Goal Found.
		if (_bestGoalNode != noone)
		{
			var _plan = reconstructPlan(_bestGoalNode);
			var _pnames = getPlanActionNames(_plan);
			_finalPlan = _pnames;
			var _pLen = array_length(_finalPlan);
			
			// Debugging stuff
			reportNodeData(_pLen, _bestGoalNode);
			
		}
		
		
		
		
		
		return _finalPlan;
	}
	
	
	createPlan = function(_startState, _goalState)
	{
		
		show_debug_message("Create Plan started...");
		
	    setupActionData(); // find a better place to put this ltr.

		// --- Check Plan Cache ---
		var cache_key = generateCacheKey(_startState, _goalState);
		if (struct_exists(plan_cache, cache_key))
		{
			var cached_plan = struct_get(plan_cache, cache_key);
			planLog.logInfo($"Plan found in cache for state/goal: {cache_key}. Using cached plan.");
			return cached_plan; // Return the cached plan immediately
		}
		
		
		
		var _subGoalState = buildSubGoal(_startState, _goalState);
		
		//show_debug_message($"Sub Goal Target State: {_subGoalState}");
		//show_debug_message($"Main Goal Target State: {_goalState}");
		
		
		//var _subGoalPlan = findPlan(_startState, _subGoalState);
		
		//var _finalPlan = findPlan(_startState, _goalState);
		
		//var _subGoalPlan = planLog.doProfile("_subGoalPlan", findPlan, [_startState, _subGoalState]);
		//show_debug_message($"Sub Goal Plan: {_subGoalPlan}");
		
		var _finalPlan = planLog.doProfile("_finalPlan", findPlan, [_startState, _goalState]);
		//show_debug_message($"Full Goal Plan: {_finalPlan}");
		
		
		
		return _finalPlan;	//	return a array with names of the actions as strings
	}

	
	
}



#region Node Stuff


function nodeGOAP(_name) constructor
{
	//uuid = "node_"//+generateUUID(8);
	
	name = _name;
	
	conditions = {};
	
	
	showDebug = false; 
	
	
	addCondition = function(_name, _comp, _val)
	{
		if (struct_exists(conditions, _name))
		{
			if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
			return;
		}
		
		struct_set(conditions, _name, {comparison: _comp , value: _val});
		
	}
	
	addSimpleCondition = function(_name, _val)
	{
		if (struct_exists(conditions, _name))
		{
			if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
			return;
		}
		
		struct_set(conditions, _name, _val);
	}
	
	addEualToCondition = function(_name, _val) { addCondition(_name, "=", _val); }
	addGreaterThanCondition = function(_name, _val) { addCondition(_name, ">", _val); }
	addGreaterThanOrEqualToCondition = function(_name, _val) { addCondition(_name, ">=", _val); }
	addLessThanCondition = function(_name, _val) { addCondition(_name, "<", _val); }
	addLessThanOrEqualToCondition = function(_name, _val) { addCondition(_name, "<=", _val); }
	
	
}


enum actionStatus
{
	idle,
	running,
	success,
	failure,
}

enum actionTargetMode
{
	none,
	MoveBeforePerforming,
	PerformWhileMoving,
}



function actionGOAP(_name, _cost) : nodeGOAP(_name) constructor
{
	cost = _cost;
	reactions = {};
	isInterruptible = false;
	
	target = undefined;
	targetMode = actionTargetMode.none;
	
	status = actionStatus.idle; //idle, running, success, failure
	
	executeFunction = undefined;
	
	
	#region		--- Public User Functions
	
	addReaction = function(_name, _val)
	{
		if (struct_exists(reactions, _name))
		{
			if showDebug show_debug_message($"Reaction ({_name}) Exists Already.");
			return;
		}
		
		
		struct_set(reactions, _name, _val);
	}
	
    setExecuteFunction = function(_func)
	{
        executeFunction = _func;  // Set the function that executes the action
    }
	
	
	setTarget = function(_target, _mode=actionTargetMode.MoveBeforePerforming)
	{
		target = _target;
		targetMode = _mode;
	}
	
	
    
	canBeInterrupted = function(_val)
	{
		isInterruptible = _val;
	}

	#endregion	
	
    // Function to execute the action
    execute = function()
	{
        if (executeFunction != undefined)
		{
            executeFunction();  // Call the function to execute the action
        }
        
    }
	
	
	isRunning = function()
	{
		return (status == actionStatus.running);
	}
	
}


function goalGOAP(_name) : nodeGOAP(_name) constructor
{
	
	
	
}


#endregion



#region --- Example

/*


// --- Real World State Variables for the AI ---
// These are the actual stats/flags the AI instance holds
real_has_weapon = false;
real_ammo = 0;
real_scrap = 0; // Start with 0 scrap
real_weapon_needs_repair = false; // Weapon is NOT broken if we don't have one


// Create an instance of the GOAP brain
goap_brain = new brainGOAP();

// --- Define and Register Sensors ---
// Sensor for HasWeapon (boolean)
goap_brain.registerSensor("HasWeapon", function()
{
    return real_has_weapon; // Read the actual boolean stat
});

// Sensor for Ammo (numerical)
goap_brain.registerSensor("Ammo", function()
{
    return real_ammo; // Read the actual numerical stat
});

// Sensor for Scrap (numerical)
goap_brain.registerSensor("Scrap", function()
{
    return real_scrap; // Read the actual numerical stat
});

// Sensor for WeaponNeedsRepair (boolean)
goap_brain.registerSensor("WeaponNeedsRepair", function()
{
    return real_weapon_needs_repair; // Read the actual boolean stat
});


// --- Define Goal ---
// Goal: Have a weapon, enough ammo, and the weapon is NOT broken
var goal_armed_and_ready = new goalGOAP("ArmedAndReady");
// Goal conditions using numerical and simple formats
goal_armed_and_ready.addSimpleCondition("HasWeapon", true);
goal_armed_and_ready.addGreaterThanOrEqualToCondition("Ammo", 10);
goal_armed_and_ready.addSimpleCondition("WeaponNeedsRepair", false); // Goal is NOT needing repair

// Add the goal to the brain
goap_brain.addGoal(goal_armed_and_ready);


// Action: Find Weapon (Cost 10)
var action_find_weapon = new actionGOAP("FindWeapon", 10);
action_find_weapon.addSimpleCondition("HasWeapon", false);
// Reactions: Gain weapon, and it needs repair
action_find_weapon.addReaction("HasWeapon", true);
action_find_weapon.addReaction("WeaponNeedsRepair", true);
// onEntry: Change the real world state
action_find_weapon.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is finding a weapon...");
    real_has_weapon = true;
    real_weapon_needs_repair = true;
	show_debug_message("AI is has a weapon");
});


// Action: Collect Scrap (Cost 5)
var action_collect_scrap = new actionGOAP("CollectScrap", 5);
// Conditions: None for simplicity in this example
//action_collect_scrap.addLessThanCondition("Scrap", 50);
// Reaction: Gain 15 scrap
action_collect_scrap.addReaction("Scrap", +15);
// onEntry: Change the real world state
action_collect_scrap.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is collecting scrap...");
    real_scrap += 15; // Add scrap to the real AI stat
    show_debug_message("AI collected scrap. Total scrap: " + string(real_scrap));
});


// Action: Craft Ammo (Cost 8)
var action_craft_ammo = new actionGOAP("CraftAmmo", 8);
// Conditions: Need enough scrap, and need a weapon
action_craft_ammo.addGreaterThanOrEqualToCondition("Scrap", 5);
action_craft_ammo.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 5 scrap, gain 10 ammo
action_craft_ammo.addReaction("Scrap", -5);
action_craft_ammo.addReaction("Ammo", +10);
// onEntry: Change the real world state
action_craft_ammo.setExecuteFunction(function()
{
    show_debug_message("AI is crafting ammo...");
    real_scrap -= 5; // Deduct scrap from real AI stat
    real_ammo += 10; // Add ammo to real AI stat
	show_debug_message($"AI crafting ammo: Scrap: {real_scrap}, Ammo: {real_ammo}");
    show_debug_message("AI crafted ammo. Scrap: " + string(real_scrap) + ", Ammo: " + string(real_ammo));
});


// Action: Repair Weapon (Cost 12)
var action_repair_weapon = new actionGOAP("RepairWeapon", 12);
// Conditions: Weapon needs repair, need enough scrap, need a weapon
action_repair_weapon.addSimpleCondition("WeaponNeedsRepair", true);
action_repair_weapon.addGreaterThanOrEqualToCondition("Scrap", 10);
action_repair_weapon.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 10 scrap, weapon no longer needs repair
action_repair_weapon.addReaction("Scrap", -10);
action_repair_weapon.addReaction("WeaponNeedsRepair", false);
// onEntry: Change the real world state
action_repair_weapon.setExecuteFunction(function()
{
    show_debug_message("AI is repairing weapon...");
    real_scrap -= 10; // Deduct scrap from real AI stat
    real_weapon_needs_repair = false; // Set weapon as repaired
    show_debug_message("AI repaired weapon. Scrap: " + string(real_scrap) + ", Needs Repair: " + string(real_weapon_needs_repair));
});


// Add actions to the brain
goap_brain.addActionsByArray([
    action_find_weapon,
    action_collect_scrap,
    action_craft_ammo,
    action_repair_weapon
]);


// --- Set the Target Goal ---
goap_brain.setTargetGoal("ArmedAndReady");

show_debug_message("Starting GOAP brain with 'Get Armed' goal...");
goap_brain.generatePlan();
// In your Step event, you would then call goap_brain.runPlan();

*/

#endregion


