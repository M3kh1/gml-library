

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


function brainGOAP() constructor
{
	
	
	actions = {};
	goals = {};
	sensors = {};
	
	targetGoal = undefined;
	
	Log = new Logger("GOAP/Brain", true, [LogLevel.debug, LogLevel.warning]);
	
	planner = new plannerGOAP(); 
	plan = [];
	currentActionIndex = 0;  // init action index
	
	
	#region Primary User Functions
	
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

	#region --- Base Helper Functions ---
	
	
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
		
		var pruned_actions = pruneActionsByGoal(available_actions, goal_state);
	    var new_plan = planner.createPlan(current_state, goal_state, available_actions);
	    var plan_valid = (array_length(new_plan) > 0);

	    if (!plan_valid)
	    {
			Log.logDebug("No valid plan could be generated.");
			
	        return false;
	    }

	    initPlan(new_plan); // Update plan with the new one

	    var _endTime = (current_time - _startTime);
		
		
		Log.logDebug($"New plan generated in ({string_format(_endTime, 0, 2)} ms) successfully.");
		
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
	
	
	pruneActionsByGoal = function(actions, goal_state)
	{
	    var pruned_actions = {};
	    var goal_keys = struct_get_names(goal_state);

	    var action_names = struct_get_names(actions);
	    for (var i = 0; i < array_length(action_names); i++)
		{
	        var action_name = action_names[i];
	        var action = actions[$ action_name];
        
	        // Check if action.effects change any key relevant to the goal
	        var effects_keys = struct_get_names(action.reactions); // Assuming 'reactions' holds effects
        
	        var relevant = false;
			
	        for (var k = 0; k < array_length(effects_keys); k++)
			{
	            var effect_key = effects_keys[k];
            
	            if (array_contains(goal_keys, effect_key))
				{
	                // If the effect value is different from goal, it's relevant
	                if (action.reactions[$ effect_key] != goal_state[$ effect_key])
					{
	                    relevant = true;
	                    break;
	                }
	            }
	        }
        
	        if (relevant) pruned_actions[$ action_name] = action;
	        
	    }
	    return pruned_actions;
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



function plannerGOAP() constructor
{
	planLog = new Logger("GOAP/Planner", true, [LogLevel.info]);
	
    heuristic_cache = {};   // Cache for heuristic values
    plan_cache = {};        // Cache for previously generated plans
	
	best_solution = undefined;
	
    nextID = 1;
	
	astarLog = {
	    nodes_opened: 0,
	    nodes_failed: 0,
		failure_rate: 0,
	    nodes_processed: 0,
		time_took: 0,
	}
	
	// best node heuristic + cost
	best_f = infinity;
	
	
	default_log = variable_clone(astarLog);
	
	resetLog = function()
	{
		astarLog = variable_clone(default_log);
		
		//show_debug_message("Restarting A* Log");
	}
	
	printLog = function()
	{
		show_debug_message("--------------------------");
		show_debug_message($"Log: {astarLog}");
		show_debug_message("----- A* Log of DATA -----");
		
		var _vals = struct_get_names(astarLog);
		
		for(var i=0; i<array_length(_vals); i++)
		{
			var _name = _vals[i];
			var _logVal = struct_get(astarLog, _name);
			
			if string(_name) == "time_took" _logVal = string_format(_logVal, 0, 5);
			
			show_debug_message($"{_name}: {_logVal}");
		}
		show_debug_message("--------------------------");
	}
	
	endAstarLog = function()
	{
		astarLog.failure_rate = astarLog.nodes_failed / (astarLog.nodes_failed + astarLog.nodes_processed);
		
		printLog();
	}
	
	
	#region	--- Helper Functions ---

	
	checkKeysMatch = function(_conditions_or_reactions, _state_to_check) // Renamed parameters for clarity
	{
	    var _keys = struct_get_names(_conditions_or_reactions); // Iterate keys from the conditions/reactions set
	    for (var i = 0; i < array_length(_keys); i++)
	    {
	        var _key = _keys[i];
	        // Call keyMatches with STATE first, then CONDITIONS/REACTIONS
	        if (!keyMatches(_state_to_check, _conditions_or_reactions, _key)) // <-- Swap parameters here!
	        { 
	            return false; // If ANY key doesn't match, the whole set doesn't match
	        }
	    }
	    return true; // If all keys matched, the whole set matches
	}

	reconstructPath = function(goal_node) // goal_node is the final astarNode
	{
	    var actions = []; // This array will store ACTION NAMES (strings)
	    // Start from the goal node and walk back through parents
	    var current = goal_node; // 'current' should be an astarNode

	    if (current == undefined)
		{
	        //show_debug_message("reconstructPath: Started with undefined goal_node!"); // Should not happen if a path was found
	        return [];
	    }

	    // While current node is valid and has a parent (i.e., not the start node)
	    while (current != undefined && current.parent != undefined) // <-- Error is reported on this line
		{
	        array_push(actions, current.action); // Collect the action NAME (string)
	        current = current.parent; // Move up to the parent node
	    }

	    // The actions are collected in reverse order, so reverse them for correct sequence
	    actions = array_reverse(actions); // Array of strings

	    return actions; // Returns array of action names
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
	    if (is_struct(condition_definition) && struct_exists(condition_definition, "comparison") && struct_exists(condition_definition, "value"))
	    {
	        var operator = condition_definition.comparison;
	        var target_value = condition_definition.value;

	        // Ensure both state value and target value are numeric for numerical comparison
	        if (!is_numeric(state_value) || !is_numeric(target_value))
	        {
	            // If either isn't numeric, the condition can't be numerically matched.
	            planLog.logError($"keyMatches: Numerical comparison for key '{_key_to_check}' requires numeric values. State is '{string(state_value)}', Target is '{string(target_value)}'.");
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
	                planLog.logError($"keyMatches: Unknown comparison operator '{operator}' for key '{_key_to_check}'.");
	                return false; // An unknown operator means the condition is not met
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
	
	
	// --- Simulate applying an action's reactions to a state ---
    simulateReactions = function(_state, _reactions)
    {
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
	
	
	initStartNode = function(start_state, goal_state)
	{
	    var h = heuristicScore(start_state, goal_state);
	    return new astarNode(0, start_state, "", 0, h, undefined);
	}
	
	statesNearlyEqual = function(_a, _b, _tolerance)
	{
	    var keys_a = struct_get_names(_a);
	    var keys_b = struct_get_names(_b);

	    if (array_length(keys_a) != array_length(keys_b)) return false;

	    for (var i = 0; i < array_length(keys_a); i++)
	    {
	        var key = keys_a[i];

	        if (!struct_exists(_b, key)) return false;

	        var val_a = _a[$ key];
	        var val_b = _b[$ key];

	        if (is_numeric(val_a) && is_numeric(val_b))
	        {
	            if (abs(val_a - val_b) > _tolerance) return false;
	        }
	        else if (val_a != val_b)
	        {
	            return false;
	        }
	    }

	    return true;
	}

	
	
	doesSatisfyGoal = function(current_state, goal_state)
	{
		var keys = struct_get_names(goal_state);
		
		for(var i=0; i<array_length(keys); i++)
		{
			var key = keys[i];
			
	        if (!current_state[$ key] || current_state[$ key] != goal_state[$ key])
			{
	            return false;
	        }
	    }
	    return true;
	}

	
	
	heuristicScore = function(_state, _goal)
	{		
	    var error = 0;


	    // Penalty constants
	    var BASE_BOOLEAN_PENALTY = 30;
	    var MISSING_KEY_PENALTY = 30;
	    var INVALID_NUMERIC_PENALTY = 50;
		

	    var goalKeys = struct_get_names(_goal);
    
	    for (var i = 0; i < array_length(goalKeys); i++)
		{
			
	        var key = goalKeys[i];
	        var conditionData = _goal[$ key];
	        var stateValue = struct_exists(_state, key) ? _state[$ key] : undefined;


	        // Handle numerical comparisons
	        if (is_struct(conditionData))
			{
	            var operator = conditionData.comparison;
	            var targetValue = conditionData.value;

	            if (stateValue == undefined)
				{
	                error += MISSING_KEY_PENALTY;
	                continue;
	            }

	            if (is_numeric(stateValue) && is_numeric(targetValue))
				{
	                var gap = 0;
                
	                switch (operator)
					{
						
	                    case ">=": gap = max(targetValue - stateValue, 0); break;
	                    case "<=": gap = max(stateValue - targetValue, 0); break;
	                    case ">":  gap = stateValue <= targetValue ? (targetValue - stateValue) + 1 : 0; break;
	                    case "<":  gap = stateValue >= targetValue ? (stateValue - targetValue) + 1 : 0; break;
	                    case "=":  gap = abs(targetValue - stateValue); break;
	                    default: error += INVALID_NUMERIC_PENALTY; break;
						
	                }

	                //error += power(gap, 1.1);
	                //error += 1;
	                //error += gap;
					
					if (gap == 0) continue;
					
					show_debug_message($"Gap: {gap}");
					var factor = (gap < 3) ? 1 : 1;
					error += power(gap, factor);

					
	            }
				else {
	                planLog.logWarning($"heuristicScore: Invalid numeric comparison at key '${key}'. State='${string(stateValue)}', Target='${string(targetValue)}'");
	                error += INVALID_NUMERIC_PENALTY;
	            }
				
	        } else {
				
				// Handle simple value conditions
				 
	            var expectedValue = conditionData;

	            if (stateValue == undefined)
				{
	                error += MISSING_KEY_PENALTY;
	                continue;
	            }

	            if (stateValue != expectedValue)
				{
	                error += BASE_BOOLEAN_PENALTY;
	            }
				
	        }
			
			
	    }

	    return error;
	}


	calculateHeuristic = function(state, goal)
	{
	    var key = hashState(state);
	    if (struct_exists(heuristic_cache, key))
		{
	        
			var _data = struct_get(heuristic_cache, key);
			
			planLog.logDebug($"Heuristic cache found: {heuristic_cache}");
	        return _data;
	    }
		
	    var h = heuristicScore(state, goal);
	    struct_set(heuristic_cache, key, h);
	    return h;
	}


	ancestorHasState = function(node, new_state)
	{
	    var new_key = hashState(new_state);

	    while (node != undefined && node != noone)
	    {
	        var node_key = hashState(node.state);
	        if (node_key == new_key)
	        {
	            return true;
	        }
	        node = node.parent;
	    }

	    return false;
	}
	

	worsensState = function(new_state, current_state, goal_state)
	{
	    var new_h = heuristicScore(new_state, goal_state);
	    var current_h = heuristicScore(current_state, goal_state);
	    return new_h > current_h;
	}
	

	hashState = function(_state)
	{
	    var keys = struct_get_names(_state);
	    array_sort(keys, true); // VERY IMPORTANT: Sort keys alphabetically
	    var str = "{";
	    for (var i = 0; i < array_length(keys); i++)
		{
	        var key = keys[i];
	        var value = _state[$ key];
	        str += string(key) + ":" + string(value); // Convert key and value to string consistently
	        if (i < array_length(keys) - 1)
			{
	            str += ",";
	        }
	    }
	    str += "}"; // Add delimiters to the start/end for clarity
	    return str;
	}
	
	
	
	expandNode = function(current, goal_state, actions, open_queue, visited_nodes)
	{
		var keys = array_shuffle(struct_get_names(actions));
	    //var keys = struct_get_names(actions);
		
	    var scored_actions = [];

		for (var i = 0; i < array_length(keys); i++)
		{
		    var action_name = keys[i];
		    var action = actions[$ action_name];

			
		    if (!checkKeysMatch(action.conditions, current.state))
			{
				//show_debug_message("Keys dont match");
		        astarLog.nodes_failed++;
		        continue; // Discard this action: conditions not met
		    }
			
			
		    var new_state = simulateReactions(current.state, action.reactions);
			
			
			//if (ancestorHasState(current, new_state))
			//{
			//	//show_debug_message("Ancestor has state - in loop.");
			//	astarLog.nodes_failed++;
			//	continue;
			//}
			
			
			if doesSatisfyGoal(new_state, goal_state)
			{
				
				show_debug_message("Simulated State meets GOAL.");
				
				return;
			}
			
			
			if (worsensState(new_state, current.state, goal_state)) 
			{
				//show_debug_message("Worsens the state");
		        astarLog.nodes_failed++;
		        continue; // prune this action early
		    }
			
			
			if (statesNearlyEqual(new_state, current.state, 2))
			{
				//show_debug_message("Sates are too similar, pruning this node.");
				astarLog.nodes_failed++;
				continue;
			}
			
			
		    var heuristic = heuristicScore(new_state, goal_state);
			
			
			if (heuristic > best_f || heuristic > current.h)
		    {
				show_debug_message("Heuristic did not improve — pruning.");
		        astarLog.nodes_failed++;
		        continue;
		    }
			
			
		    array_push(scored_actions, { name: action_name, state: new_state, heuristic: heuristic, action: action });
		}

		// Sort by heuristic (lower is better)
		array_sort(scored_actions, function(a, b) { return (a.heuristic - b.heuristic); });
		

		// Now insert into queue
		for (var i = 0; i < array_length(scored_actions); i++)
		{
		    var entry = scored_actions[i];
		    var g2 = current.g + entry.action.cost;
		    var f2 = g2 + entry.heuristic;
			

	        // PRUNE: skip nodes worse than best known solution
			//show_debug_message($"f2:{f2} >= best_f:{best_f}");
	        if (f2 >= best_f)
			{
				show_debug_message($"Pruned Node cus f2:{f2} >= best_f:{best_f}");
				astarLog.nodes_failed++;
	            continue;
			}
			
		    var new_key = hashState(entry.state);
		    if (struct_exists(visited_nodes, new_key))
			{
		        var existing = visited_nodes[$ new_key];
				//show_debug_message("Alrdy Visited the node b4.");
				astarLog.nodes_failed++;
		        if (existing.g <= g2) continue; // Discard if a cheaper or equal-cost path already visited
		    }

		    var new_node = new astarNode(nextID++, entry.state, entry.name, g2, entry.heuristic, current);
		    ds_priority_add(open_queue, new_node, new_node.f);
		    struct_set(visited_nodes, new_key, { g: g2, f: f2, node: new_node });
		    astarLog.nodes_opened++;
		}

	}
	
	
	processPlanningLoop = function(start_state, open_queue, visited_nodes, goal_state, actions)
	{
		var MAX_PLANNING_STEPS = 10000; //If it hits 10,000 nodes then the search space is too large.
	    while (!ds_priority_empty(open_queue) && astarLog.nodes_processed < MAX_PLANNING_STEPS)
	    {
	        var current = ds_priority_delete_min(open_queue); // Get the best node
	        astarLog.nodes_processed++;

	        var goal_check_result = checkKeysMatch(goal_state, current.state);
	        // If goal is reached
	        if (goal_check_result)
	        {
				
				// Update best_f to this solution's f-value
				var current_f = current.g + current.h;  // or current.f if you have it
				if (current_f < best_f)
				{
				    best_f = current_f;
				    //show_debug_message($"Setting best_f to {best_f}");
				}

				
	            //show_debug_message($"--- GOAL REACHED! State ID {current.ID} ---"); // Add success log
	            astarLog.time_took = current_time - astarLog.time_took;
	            ds_priority_destroy(open_queue);
				
				var _str_names;
				
				//if best_solution != undefined
				//{
				//	_str_names = reconstructPath(best_solution);
				//} else {
				//	_str_names = reconstructPath(current); // Pass the goal node to reconstructPath
				//}

				
				_str_names = reconstructPath(current); // Pass the goal node to reconstructPath
				
				
				// --- Cache the found plan ---
				var cache_key = generateCacheKey(start_state, goal_state); // Use the GOAL state for caching
				struct_set(plan_cache, cache_key, _str_names);
				planLog.logInfo($"Plan cached for state/goal: {cache_key}");

	            return _str_names; // Return array of action names
	        }

	        // If goal not reached, expand the current node
	        //expandNode(current, goal_state, actions, open_queue, visited_nodes);
			
			planLog.doProfile("expandNode", expandNode, [current, goal_state, actions, open_queue, visited_nodes]);
			
	    }
		
	    // If the loop finishes (queue is empty and goal not found)
	    ds_priority_destroy(open_queue); // Destroy the queue here too if loop finishes naturally
		planLog.logWarning($"No valid plan could be generated within limits (Processed: {astarLog.nodes_processed}, Explored: {astarLog.nodes_opened}).");

	    //show_debug_message("Process Planning Loop finished without finding a plan.");
	    return []; // Return an empty plan
	}


	
	#endregion
	
	
	function astarNode(_id, _state, _action, _g, _h, _parent) constructor
	{
	    ID      = _id;                    // unique numeric
	    state   = variable_clone(_state);    // 
	    action  = _action;                // string name
	    g       = _g;                     // accumulated cost
	    h       = _h;                     // heuristic
	    f       = _g + _h;                // total score
	    parent  = _parent;                // link to another astarNode
	}
	
	
	createPlan = function(_start_state, _goal_state, _actions)
	{
	    resetLog();
	    astarLog.time_took = current_time;

		// --- Check Plan Cache ---
		var cache_key = generateCacheKey(_start_state, _goal_state);
		if (struct_exists(plan_cache, cache_key))
		{
			var cached_plan = struct_get(plan_cache, cache_key);
			planLog.logInfo($"Plan found in cache for state/goal: {cache_key}. Using cached plan.");
			astarLog.time_took = current_time - astarLog.time_took; // Calculate time for cache lookup
			//printLog(); // Print log even for cached plans
			return cached_plan; // Return the cached plan immediately
		}

	    var open_queue = ds_priority_create();
	    var visited_nodes = {};

	    var start_node = initStartNode(_start_state, _goal_state);
	    ds_priority_add(open_queue, start_node, start_node.f);
		
	    struct_set(visited_nodes, hashState(_start_state), { g: start_node.g, f: start_node.f, node: start_node });

	    //var _finalPlan = processPlanningLoop(_start_state, open_queue, visited_nodes, _goal_state, _actions);
		var _finalPlan = planLog.doProfile("processPlanningLoop", processPlanningLoop, [_start_state, open_queue, visited_nodes, _goal_state, _actions]);

		endAstarLog();
		
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


