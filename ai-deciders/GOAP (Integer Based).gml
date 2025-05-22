

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
		
		
		Log.logDebug($"New plan generated successfully in ({_endTime} ms) so abt. ({round(_endTime/16.67)} frames).");
		
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
	
    plan_cache = {};        // Cache for previously generated plans
	
	
	allActions = _allActions;
	
	conditionGraph = undefined;	// init ONCE
	reactionGraph = undefined; // init ONCE
	
	#region	--- Helper Functions ---

	setActionGraph = function()
	{
		if (is_undefined(conditionGraph) and is_undefined(reactionGraph))
		{
			var _graphs = planLog.doProfile("buildDependencyMaps",buildDependencyMaps);
			conditionGraph = _graphs.con;
			reactionGraph = _graphs.react;
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


	getRelevantActionsForGoal = function(goalKeys)
	{
	    var relevantActions = [];
	    var visitedKeys = {};
	    var queue = variable_clone(goalKeys);
		var preMap = conditionGraph;
		var effMap = reactionGraph;
		

	    while (array_length(queue) > 0)
	    {
	        var key = queue[0];
	        array_delete(queue, 0, 1);

	        if (struct_exists(visitedKeys, key)) continue;
	        struct_set(visitedKeys, key, true);

	        if (struct_exists(effMap, key))
			{
	            var producingActions = effMap[$ key];
	            for (var i = 0; i < array_length(producingActions); i++)
				{
	                var actName = producingActions[i];
	                var act = allActions[$ actName];

	                if (!struct_exists(act.reactions, key))
					{
					    // Skip this action because it doesn't produce the key we're currently processing
					    continue;
					}
					
	                if (!struct_exists(act.conditions, key))
					{
					    // Skip this action because it doesn't produce the key we're currently processing
					    continue;
					}

	                if (!array_contains(relevantActions, actName))
					{
	                    array_push(relevantActions, actName);

	                    var preKeys = struct_get_names(act.conditions);
	                    for (var j = 0; j < array_length(preKeys); j++)
						{
	                        var preKey = preKeys[j];
	                        if (!struct_exists(visitedKeys, preKey))
							{
	                            array_push(queue, preKey);
	                        }
	                    }
	                }
	            }
	        }
	    }
		
		show_debug_message($"Relevant ACTIONS {array_length(relevantActions)}: {relevantActions}");
	    return relevantActions;
	}

	
	
	goalHeuristic = function(_state, _goalConditions)
	{
		var penalty = 0;
		var _goalKeys = struct_get_names(_goalConditions);

		for (var i = 0; i < array_length(_goalKeys); i++)
		{
			var key = _goalKeys[i];
			var data = _goalConditions[$ key];

			var op, target;

			if (is_struct(data))
			{
				if (!struct_exists(data, "comparison") || !struct_exists(data, "value"))
				{
					show_debug_message("Malformed goal condition: missing comparison/value");
					penalty += 1000;
					continue;
				}
				op = data.comparison;
				target = data.value;
			} else {
				// Fall back to strict equality if no operator given
				op = "=";
				target = data;
			}

			if (!struct_exists(_state, key))
			{
				penalty += 1;
				continue;
			}

			var actual = _state[$ key];

			if (is_numeric(actual) && is_numeric(target))
			{
				switch (op)
				{
					case ">=": if (actual < target) penalty += (target - actual); break;
					case "<=": if (actual > target) penalty += (actual - target); break;
					case ">":  if (actual <= target) penalty += (target - actual + 1); break;
					case "<":  if (actual >= target) penalty += (actual - target + 1); break;
					case "=":  penalty += abs(target - actual); break;
					default: penalty += 1000; break;
				}
				
				//show_debug_message($"Val Penn: {penalty}");
				
			} else {
				if (actual != target) penalty += 1;
			}
		}
		
		
		//show_debug_message($"Penn: {penalty}");
		return penalty;
	}


	scoreActionsByState = function(_actionNames, _stateKeys)
	{
	    var scored = [];
    
	    for (var i = 0; i < array_length(_actionNames); i++)
	    {
	        var name = _actionNames[i];
	        var act = allActions[$ name];
	        if (act == undefined) continue;

	        var conds = struct_get_names(act.conditions);
	        var _score = 0;

	        // Count matching conditions
	        for (var c = 0; c < array_length(conds); c++)
	        {
	            if (array_contains(_stateKeys, conds[c]))
	            {
	                _score += 1;
	            }
	        }
			
	        var conds = struct_get_names(act.reactions);
	        

	        // Count matching reactions
	        for (var c = 0; c < array_length(conds); c++)
	        {
	            if (array_contains(_stateKeys, conds[c]))
	            {
	                _score += 1;
	            }
	        }

	        array_push(scored, { name: name, score: _score });
			//show_debug_message($"Name: {name}, Score: {_score}");
	    }

	    return scored;
	}
	
	sortScoredActions = function(_scoredArray)
	{
	    array_sort(_scoredArray, function(a, b)
		{
	        return b.score - a.score; // Descending
	    });
	}
	
	getActionNamesFromScored = function(_scoredArray)
	{
	    var sortedNames = [];
	    for (var i = 0; i < array_length(_scoredArray); i++)
	    {
	        array_push(sortedNames, _scoredArray[i].name);
	    }
	    return sortedNames;
	}
	
	
	bettersState = function(currentState, resultState, goalState)
	{
	    var currentH = goalHeuristic(currentState, goalState);
	    var resultH  = goalHeuristic(resultState, goalState);
	    return resultH < currentH;
	}
	
	
	trimActionsToUnmet = function(relevantActions, unmetKeys)
	{
		var trimmed = [];
		
		var _relActLen = array_length(relevantActions);
		
		for (var i = 0; i < _relActLen; i++)
		{
			var actName = relevantActions[i];
			var act = allActions[$ actName];

			var effectKeys = struct_get_names(act.reactions);

			for (var j = 0; j < array_length(unmetKeys); j++)
			{
				var unmet = unmetKeys[j];
				if (array_contains(effectKeys, unmet))
				{
					array_push(trimmed, actName);
					break; // at least one match, keep the action
				}
			}
		}

		//show_debug_message($"Trimmed to {array_length(trimmed)} <- from: {_relActLen}, Relevant actions: {trimmed}");
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
	

	
	ancestorHasState = function(node, new_state, _actionName)
	{
	    var new_key = hashState(new_state)// + "|" + _actionName;

	    while (node != undefined && node != noone)
	    {
	        var node_key = hashState(node.state)// + "|" + _actionName;
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


	findPlan = function(_startState, _goalState)
	{
		
		/*
			Example:
			
			Sim State: { HasWeapon : 1, Ammo : 10, Scrap : -15, WeaponNeedsRepair : 0, HasSupplyCrate : 0 }
			Goal State: { HasWeapon : 1, Ammo : { comparison : ">=", value : 10 }, WeaponNeedsRepair : 0 }
			Expanding (13): g=35, h=0, f=35
		
		*/
		
		var _startMS = current_time;
		
		//var _relevantActions = getRelevantActionsForGoal(struct_get_names(_goalState));
		var _relevantActions = getPlanActionNames(structToArray(allActions)); // Dynamically Prune actions per node
		var _visitedNodes = {};				// stateHash -> best node
		
		var _nonDeterministic = false;
		
		var _open = [];
		
		
		var _finalPlan = [];
		
		var _startHash = hashState(_startState);
		var _startNode = new astarNode(_startState, undefined, undefined, 0, goalHeuristic(_startState, _goalState));

		struct_set(_visitedNodes, _startHash, _startNode);
		array_push(_open, _startNode);

		
		var _bestFSoFar = infinity; // Large initial value
		var _bestGoalNode = noone;
		
		
		var _expanded = 0;
		var _pruned = 0;
		
		
		// A* Pathfinding from _startState -> _goalState
		while (array_length(_open) > 0)
		{
			var _node = _open[0];
			
			
			// Early termination: if best goal found and next node's fCost is >= best goal fCost, break
		    if (_bestGoalNode != noone && _node.fCost >= _bestFSoFar)
		    {
		        break; // no better solution possible
		    }
			
			array_delete(_open, 0, 1);

			var _state = _node.state;
			var _g = _node.gCost;
			var _stateHash = hashState(_state);
			

			if (_nonDeterministic) _relevantActions = array_shuffle(_relevantActions);

		
			// Filter out useless actions based on the current state
			var _unmetGoalKeys = getUnmetConditions(_goalState, _state); 
			var _finalRelevantActions = trimActionsToUnmet(_relevantActions, _unmetGoalKeys);


			// Score and sort actions 
			var scored = scoreActionsByState(_finalRelevantActions, struct_get_names(_state));
			sortScoredActions(scored);
			_finalRelevantActions = getActionNamesFromScored(scored);
			
			
			// Expand all relavant actions
			for (var i = 0; i < array_length(_finalRelevantActions); i++)
			{
				var _actName = _finalRelevantActions[i];
				var _act = allActions[$ _actName];
				if (_act == undefined) continue;

				
				
				if (!checkKeysMatch(_act.conditions, _state))
				{
					//show_debug_message("Keys no match");
					_pruned++;
					continue;
				}
				
				
				var _simState = simulateReactions(_state, _act.reactions);
				var _nextHash = hashState(_simState)// + "|" + _actName;
				
				
				
				if ancestorHasState(_node, _simState, _actName)
				{
					//show_debug_message("Ancestor with same action path.");
					_pruned++;
					continue;
				}
				
				var _simState = simulateReactions(_state, _act.reactions);

				var _unmetBefore = array_length(getUnmetConditions(_goalState, _state));
				var _unmetAfter = array_length(getUnmetConditions(_goalState, _simState));

				var unmetKeysBefore = getUnmetConditions(_goalState, _state);
				var unmetKeysAfter = getUnmetConditions(_goalState, _simState);

				// Check if any previously unmet goal is now met
				var progressMade = false;
				for (var k = 0; k < array_length(unmetKeysBefore); k++)
				{
				    var key = unmetKeysBefore[k];
				    if (!array_contains(unmetKeysAfter, key))
				    {
				        progressMade = true;
				        break;
				    }
				}

				if (!progressMade && _unmetAfter > _unmetBefore)
				{
				    //show_debug_message("No progress toward goal, prune action");
					_pruned++;
				    continue;
				}



				var _hAfter = goalHeuristic(_simState, _goalState);
				
				// Apply heuristic consistency correction
				var _correctedH = max(_hAfter, _node.hCost - _act.cost);
				
				
				// bucketing(grouping) h-vals
				//var bucket_size = 2.5;
				//_correctedH = floor(_correctedH / bucket_size) * bucket_size;
				
				
				var _hBefore = goalHeuristic(_state, _goalState);
				
				
				// Optional: Diagnostic output
				if (_correctedH != _hAfter)
				{
				    //show_debug_message("Heuristic corrected: " + string(_hAfter) + " -> " + string(_correctedH));
				}
				
				
				if (_correctedH > _hBefore*1.0)
				{
					//show_debug_message($"Worsened heuristic: {_hBefore} -> {_correctedH}, skipping");
					_pruned++;
					continue;
				}
				
				
				//show_debug_message($"Sim State: {_simState}, Goal State: {_goalState}");
				
				
				var _newG = _g + _act.cost;
				var _newF = _newG + _correctedH;
				
				
				var _newNode = new astarNode(_simState,_act,_node,_newG,_correctedH);
				

				if (struct_exists(_visitedNodes, _nextHash))
				{
					//show_debug_message("next hash exists");
					var _existing = _visitedNodes[$ _nextHash];
					var _oldF = _existing.gCost + _existing.hCost;

					// Skip only if the existing node is strictly better
					if (_oldF <= _newF)
					{
						//show_debug_message("Better or equal node already visited, skipping");
						_pruned++;
						continue;
					}
					
					
					// If you're here, the new node is better.
					// But the open list still contains the old worse node,
					// Remove old version from open list
					//show_debug_message("Find & remove old node");
				    for (var j = 0; j < array_length(_open); j++)
					{
				        var existing = _open[j];
						
						var _extHash = hashState(existing.state);
						var _sHash = hashState(_simState);
						
						//show_debug_message($"Ext: ({_extHash}) ~ Next: ({_sHash})");
						
				        if (_extHash == _sHash)
						{
				            array_delete(_open, j, 1);
							//show_debug_message("Old node DELETED.");
				            break;
				        }
				    }
				}

				
				if (state_meets_goal(_simState, _goalState))
				{
					var _f = _newG + _correctedH;

				    if (_f < _bestFSoFar)
				    {
				        _bestFSoFar = _f;
				        _bestGoalNode = _newNode;
				    }

				    continue;
				}
				

				struct_set(_visitedNodes, _nextHash, _newNode);
				array_push(_open, _newNode);

				
				_expanded++;
				//show_debug_message($"[{current_time-_startMS} ms] Expanding ({_expanded}): g={_newG}, h={_correctedH}, f={_newF}");
				
				
			}

			
			// Tie-break on fCost, then prefer lower hCost (closer to goal)
			array_sort(_open, function(a, b)
			{
				if (a.fCost == b.fCost)
				{
					//show_debug_message("Tie-Break F Cost.");
					
					return a.hCost < b.hCost;
				}
				//show_debug_message("NO TIE");
				//return a.fCost == b.fCost ? a.hCost < b.hCost : a.fCost < b.fCost;

				return a.fCost < b.fCost;
			});
		}
		
		
		
		if (_bestGoalNode != noone)
		{
			var _plan = reconstructPlan(_bestGoalNode);
			var _pnames = getPlanActionNames(_plan);
			_finalPlan = _pnames;
			var _pLen = array_length(_finalPlan);
			
		
			
			/*
				Summary of all Node DATA
			
					If Prune Ratio goes up, you’re cutting out more useless nodes early, which is good.
					If Efficiency (expanded/total) increases, you’re expanding a higher portion of relevant nodes, also good.
					If Branching Factor drops, your planner is focusing more tightly on promising paths.
					If Goal Efficiency improves, more of your expansions are actually contributing to the final plan.
			*/
			
			
			var _totalNodes = (_pruned + _expanded);
			var _prunedRatio = (_pruned / _totalNodes);					 //cutting out #% of nodes early.
			var _expansionEfficiency = (_expanded / _totalNodes);		 //confirms about #% of nodes got fully expanded.
			var _branchingFactor = (_expanded / _pLen);					 //for every step in the plan, you explored about # nodes.
			var _goalEfficiency = 1 - ((_expanded - _pLen) / _expanded); //only #% of expanded nodes ended up on the final plan path.

			
			show_debug_message($"Node Data: [Total: {_totalNodes}, Pruned: {_pruned}, Expanded: {_expanded}, Prune Ratio: {_prunedRatio}]");
			show_debug_message($"Node Data: [Efficiency: {_expansionEfficiency}, Branching: {_branchingFactor}, Goal Efficiency: {_goalEfficiency}]");
		}
		
		return _finalPlan;
	}

	
	createPlan = function(_startState, _goalState)
	{
		
		show_debug_message("Create Plan started...");
	    setActionGraph();

		// --- Check Plan Cache ---
		var cache_key = generateCacheKey(_startState, _goalState);
		if (struct_exists(plan_cache, cache_key))
		{
			var cached_plan = struct_get(plan_cache, cache_key);
			planLog.logInfo($"Plan found in cache for state/goal: {cache_key}. Using cached plan.");
			return cached_plan; // Return the cached plan immediately
		}
		
		
		//show_debug_message($"Action Reactions TradeScrapForAmmo Struct: {allActions[$ "TradeScrapForAmmo"].reactions}");
		//show_debug_message($"Action Conditions TradeScrapForAmmo Struct: {allActions[$ "TradeScrapForAmmo"].conditions}");
		
		//show_debug_message($"Action Reactions BuyWeapon Struct: {allActions[$ "BuyWeapon"].reactions}");
		//show_debug_message($"Action Conditions BuyWeapon Struct: {allActions[$ "BuyWeapon"].conditions}");
		
		
		show_debug_message($"Con Graph: {conditionGraph}");
		show_debug_message($"React Graph: {reactionGraph}");
		
		var _names = struct_get_names(conditionGraph);
		
		
		for(var i=0; i<array_length(_names); i++)
		{
			var _conName = _names[i];
			var _conDependencies = conditionGraph[$ _conName];
			
			
			show_debug_message($"Condition {i+1}: {_conName}, {_conDependencies}");
		}
		
		
		
		_names = struct_get_names(reactionGraph);
		for(var i=0; i<array_length(_names); i++)
		{
			var _reactName = _names[i];
			var _reactDependencies = reactionGraph[$ _reactName];
			
			show_debug_message($"Reaction {i+1}: {_reactName}, {_reactDependencies}");
		}
		
		
		
		
		
		var _finalPlan = findPlan(_startState, _goalState);
		//var _finalPlan = [];
		
		
		
		
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


